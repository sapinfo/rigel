# Design — 프로덕션 Docker 배포

> Feature: `프로덕션-docker-배포`
> Plan: `docs/01-plan/features/프로덕션-docker-배포.plan.md`
> Date: 2026-04-14
> Phase: PDCA Design

---

## Executive Summary

| 항목 | 내용 |
|---|---|
| **Supabase 컨테이너** | 공식 supabase/docker 세트 (20+ 서비스, 건드리지 않음) |
| **Rigel 앱 컨테이너** | 1개 (rigel-app, SvelteKit adapter-node) |
| **통신** | Rigel 앱 → `http://kong:8000` (Supabase 네트워크 가입) |
| **Migration 적용** | install.sh가 `docker exec supabase-db psql` 방식으로 실행 |
| **보안 키** | install.sh가 openssl로 자동 생성 + JWT 서명 |

### Value Delivered (4관점)

| 관점 | 내용 |
|---|---|
| **Problem** | Supabase 직접 구성 실패 반복 → 검증 시간 수십 시간 낭비 |
| **Solution** | 공식 supabase/docker 보존 + 앱 분리 + install.sh로 자동화 |
| **Function UX** | `curl \| bash` 한 줄 → Supabase + Rigel 전체 기동 |
| **Core Value** | 파괴적 명령(`prune`) 제거, 이미지 캐시 유지 → 재실행 1분 |

---

## 1. 디렉토리 & 파일 구조

### 1.1 전체 레이아웃

```
rigel/                                  # git 루트
├── supabase-docker/                    # ★ Supabase 공식 셀프호스팅 (수정 금지)
│   ├── docker-compose.yml              # 공식 파일 그대로
│   ├── .env.example                    # 공식 템플릿
│   ├── .env                            # (gitignore) install.sh 생성
│   ├── utils/generate-keys.sh
│   └── volumes/
│       ├── api/kong.yml
│       ├── api/kong-entrypoint.sh
│       ├── db/{jwt,logs,pooler,realtime,roles,webhooks,_supabase}.sql
│       └── logs/vector.yml
│
├── docker-compose.yml                  # ★ Rigel 앱 컨테이너 전용
├── Dockerfile                          # SvelteKit multi-stage build
├── .env                                # (gitignore) install.sh 생성
├── .env.production.example
│
├── install.sh                          # 원클릭 설치 스크립트
├── uninstall.sh                        # (선택) 제거 스크립트
│
├── supabase/                           # Rigel 개발용 (기존)
│   ├── config.toml                     # supabase CLI 설정 (개발용)
│   ├── migrations/                     # 71개 migration (prod도 사용)
│   └── seed.sql                        # Rigel seed
│
└── src/                                # SvelteKit 소스
```

### 1.2 두 docker-compose의 관계

**Supabase (`supabase-docker/docker-compose.yml`)**
- `name: supabase`
- 기본 네트워크: `supabase_default`
- 포트: `8000` (Kong), `5432` (Postgres direct), `6543` (Supavisor)
- 컨테이너: `supabase-db`, `supabase-auth`, `supabase-rest`, `supabase-storage`, `supabase-kong`, `supabase-realtime`, `supabase-studio`, `supabase-analytics`, `supabase-meta`, `supabase-vector`, `supabase-imgproxy`, `supabase-pooler`

**Rigel 앱 (`docker-compose.yml` 루트)**
- `name: rigel`
- Supabase 네트워크에 외부 가입: `networks: { default: { name: supabase_default, external: true } }`
- 포트: `3000` (호스트 → 컨테이너 3000)
- 컨테이너: `rigel-app`

---

## 2. docker-compose.yml (루트, Rigel 앱)

```yaml
name: rigel

services:
  app:
    container_name: rigel-app
    build:
      context: .
      dockerfile: Dockerfile
      args:
        # 브라우저가 사용할 URL — 외부 접근 가능해야 함
        PUBLIC_SUPABASE_URL: ${PUBLIC_SUPABASE_URL:-http://localhost:8000}
        PUBLIC_SUPABASE_ANON_KEY: ${PUBLIC_SUPABASE_ANON_KEY:-}
    restart: unless-stopped
    depends_on: []  # Supabase는 별도 compose에서 관리 (외부 의존성 표시 안 함)
    environment:
      # 서버에서 사용할 URL — Docker 네트워크 내부 호스트명
      PUBLIC_SUPABASE_URL: ${PUBLIC_SUPABASE_URL:-http://localhost:8000}
      PUBLIC_SUPABASE_ANON_KEY: ${PUBLIC_SUPABASE_ANON_KEY}
      # 서버 전용: 컨테이너 내부에서 kong으로 직접 접근
      SUPABASE_INTERNAL_URL: http://kong:8000
      ORIGIN: ${SITE_URL:-http://localhost:3000}
      PORT: ${APP_PORT:-3000}
    ports:
      - "${APP_PORT:-3000}:3000"

networks:
  default:
    name: supabase_default
    external: true
```

**핵심 결정**:
- `depends_on` 비움 (Supabase는 별도 compose에서 이미 관리)
- `network_mode: host` 대신 **supabase_default 네트워크 가입** (Linux 외 OS 호환)
- 브라우저용 `PUBLIC_SUPABASE_URL` = `localhost:8000` (외부)
- 서버용 `SUPABASE_INTERNAL_URL` = `http://kong:8000` (Docker 내부)

---

## 3. Dockerfile (Rigel 앱)

```dockerfile
# ─── Builder ───
FROM node:22-alpine AS builder
WORKDIR /app

# SvelteKit $env/dynamic/public은 런타임이지만, $env/static/public 잔재 대비
ARG PUBLIC_SUPABASE_URL=http://localhost:8000
ARG PUBLIC_SUPABASE_ANON_KEY=placeholder
ENV PUBLIC_SUPABASE_URL=$PUBLIC_SUPABASE_URL
ENV PUBLIC_SUPABASE_ANON_KEY=$PUBLIC_SUPABASE_ANON_KEY

COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# ─── Runner ───
FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/build ./build
COPY --from=builder /app/package*.json ./
# --ignore-scripts: prepare(svelte-kit sync) 스킵 (devDep 없어서 실패)
RUN npm ci --omit=dev --ignore-scripts
EXPOSE 3000
CMD ["node", "build/index.js"]
```

---

## 4. install.sh 상세 설계

### 4.1 전체 흐름 (8단계)

```
┌─────────────────────────────────────────────────────┐
│ 1. 사전 요구 확인                                    │
│    - docker, git, curl, openssl                     │
│    - docker compose 명령어 감지                       │
├─────────────────────────────────────────────────────┤
│ 2. 소스 다운로드                                     │
│    - 신규: git clone                                 │
│    - 기존: git pull (이미지 캐시 유지)                │
├─────────────────────────────────────────────────────┤
│ 3. supabase-docker/.env 생성 (조건부)                │
│    - 이미 있으면 skip (재실행 안전성)                  │
│    - 없으면 openssl로 보안 키 자동 생성                │
├─────────────────────────────────────────────────────┤
│ 4. Supabase 기동                                    │
│    - cd supabase-docker && docker compose up -d     │
│    - 최초: 이미지 다운로드 5~15분                      │
│    - 재실행: 수 초                                    │
├─────────────────────────────────────────────────────┤
│ 5. DB 기동 대기                                      │
│    - supabase-db 컨테이너의 healthcheck 상태 polling │
│    - 최대 60초 대기                                   │
├─────────────────────────────────────────────────────┤
│ 6. Rigel migration + seed 적용                      │
│    - 처음 설치 감지: _rigel_installed 테이블 확인      │
│    - 처음이면: 71개 migration + seed 적용             │
│    - 재실행이면: skip (데이터 보존)                    │
├─────────────────────────────────────────────────────┤
│ 7. 루트 .env 생성 (조건부)                           │
│    - supabase-docker/.env에서 ANON_KEY 복사           │
├─────────────────────────────────────────────────────┤
│ 8. Rigel 앱 빌드 + 기동                              │
│    - cd .. && docker compose up -d --build          │
│    - 접속 URL 출력                                    │
└─────────────────────────────────────────────────────┘
```

### 4.2 보안 키 생성 (3단계)

```bash
# 1. 랜덤 비밀번호
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
JWT_SECRET=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 64)
SECRET_KEY_BASE=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 64)
VAULT_ENC_KEY=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
DASHBOARD_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)

# 2. JWT 기반 API 키 생성 (JWT_SECRET으로 HS256 서명)
jwt_b64() { echo -n "$1" | openssl base64 -A | tr '+/' '-_' | tr -d '='; }
HEADER=$(jwt_b64 '{"alg":"HS256","typ":"JWT"}')
IAT=$(date +%s); EXP=$((IAT + 157680000))

ANON_PAYLOAD=$(jwt_b64 "{\"role\":\"anon\",\"iss\":\"supabase\",\"iat\":$IAT,\"exp\":$EXP}")
ANON_SIG=$(echo -n "$HEADER.$ANON_PAYLOAD" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')
ANON_KEY="$HEADER.$ANON_PAYLOAD.$ANON_SIG"

SVC_PAYLOAD=$(jwt_b64 "{\"role\":\"service_role\",\"iss\":\"supabase\",\"iat\":$IAT,\"exp\":$EXP}")
SVC_SIG=$(echo -n "$HEADER.$SVC_PAYLOAD" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')
SERVICE_ROLE_KEY="$HEADER.$SVC_PAYLOAD.$SVC_SIG"

# 3. .env.example을 복사해서 값만 교체 (sed)
cp supabase-docker/.env.example supabase-docker/.env
sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" supabase-docker/.env
# ... (나머지 키들)
```

### 4.3 DB 기동 대기 (polling)

```bash
wait_for_db() {
  local max=60 i=0
  while [ $i -lt $max ]; do
    if docker exec supabase-db pg_isready -U postgres &>/dev/null; then
      echo "[OK] DB ready"
      return 0
    fi
    sleep 1
    i=$((i+1))
  done
  echo "[!] DB not ready after ${max}s"
  return 1
}
```

### 4.4 Migration 중복 방지 (idempotent)

```bash
# _rigel_installed 마커 테이블 존재 여부로 판단
MIGRATED=$(docker exec supabase-db psql -U postgres -tA -c "SELECT 1 FROM information_schema.tables WHERE table_name = '_rigel_installed' LIMIT 1" 2>/dev/null || echo "")

if [ -z "$MIGRATED" ]; then
  echo "[..] Applying Rigel migrations..."
  for f in supabase/migrations/*.sql; do
    docker exec -i supabase-db psql -U postgres -v ON_ERROR_STOP=1 < "$f" > /dev/null
  done
  docker exec -i supabase-db psql -U postgres < supabase/seed.sql > /dev/null
  docker exec supabase-db psql -U postgres -c "CREATE TABLE _rigel_installed (at timestamptz DEFAULT now())"
  echo "[OK] Migrations + seed applied"
else
  echo "[OK] Rigel already installed (migrations skipped)"
fi
```

**핵심**:
- 재실행 시 migration 반복 실행 안 함 (seed도 동일)
- `_rigel_installed` 테이블이 마커 역할
- `ON_ERROR_STOP=1`로 개별 migration 실패 시 즉시 중단

---

## 5. SvelteKit 환경변수 분리 (개발 vs 프로덕션)

### 5.1 개발 환경 (기존)

| 변수 | 값 | 사용처 |
|---|---|---|
| `PUBLIC_SUPABASE_URL` | `http://127.0.0.1:54321` | 브라우저 + 서버 공통 |
| `PUBLIC_SUPABASE_ANON_KEY` | supabase CLI 생성 키 | 동일 |

### 5.2 프로덕션 환경 (신규)

| 변수 | 값 | 사용처 |
|---|---|---|
| `PUBLIC_SUPABASE_URL` | `http://localhost:8000` | **브라우저** (호스트에서 접근) |
| `PUBLIC_SUPABASE_ANON_KEY` | install.sh 생성 ANON_KEY | 브라우저 + 서버 공통 |
| `SUPABASE_INTERNAL_URL` | `http://kong:8000` | **서버** (Docker 내부 통신) |

### 5.3 코드 변경 필요

`src/hooks.server.ts` — 서버는 `SUPABASE_INTERNAL_URL` 우선 사용:

```ts
import { env } from '$env/dynamic/public';
import { env as privateEnv } from '$env/dynamic/private';

const serverUrl = privateEnv.SUPABASE_INTERNAL_URL || env.PUBLIC_SUPABASE_URL!;
event.locals.supabase = createServerClient(serverUrl, env.PUBLIC_SUPABASE_ANON_KEY!, {...});
```

브라우저 코드(`.svelte`, `client/*`)는 `env.PUBLIC_SUPABASE_URL` (localhost:8000)만 사용.

---

## 6. 네트워크 통신 다이어그램

```
┌───────────────────────────────────────────────────────────┐
│ 호스트 머신 (Ubuntu 서버)                                  │
│                                                           │
│ ┌─────────────────────────────────────────────────┐      │
│ │ supabase_default 네트워크                         │      │
│ │                                                  │      │
│ │  ┌─────────────┐   ┌──────────┐   ┌──────────┐ │      │
│ │  │ supabase-db │◄──│  kong    │◄──│ rigel-app│ │      │
│ │  │  (Postgres) │   │ (API gw) │   │ SvelteKit│ │      │
│ │  └─────────────┘   └────┬─────┘   └────┬─────┘ │      │
│ │         ▲               │              │       │      │
│ │         │          :8000│         :3000│       │      │
│ └─────────┼───────────────┼──────────────┼───────┘      │
│     :5432 │          :8000│         :3000│              │
│           ▼               ▼              ▼              │
│         localhost:5432  localhost:8000  localhost:3000  │
│                              ▲              ▲          │
└──────────────────────────────┼──────────────┼──────────┘
                               │              │
                        ┌──────┴──────────────┴─────┐
                        │  사용자 브라우저 (외부)      │
                        │  → localhost:3000 접속       │
                        │  → JS가 localhost:8000 호출  │
                        └──────────────────────────┘
```

---

## 7. 구현 순서

| 단계 | 작업 | 파일 |
|---|---|---|
| 1 | supabase-docker/ 디렉토리 구조 확인 + 공식 파일 일치 여부 | `supabase-docker/*` |
| 2 | 루트 `docker-compose.yml` 작성 (앱 전용, 외부 네트워크) | `docker-compose.yml` |
| 3 | `Dockerfile` 확인 (이미 존재, ARG 설정 유지) | `Dockerfile` |
| 4 | `hooks.server.ts` — `SUPABASE_INTERNAL_URL` 지원 | `src/hooks.server.ts` |
| 5 | `install.sh` 재작성 (8단계 흐름) | `install.sh` |
| 6 | `.env.production.example` 최소화 (키 목록만) | `.env.production.example` |
| 7 | `.gitignore` 업데이트 (`.env`, `supabase-docker/.env`) | `.gitignore` |
| 8 | README 프로덕션 섹션 재작성 | `README.md` |
| 9 | 랜딩페이지 설치 섹션 업데이트 | `src/routes/+page.svelte` |
| 10 | Ubuntu VM에서 검증 (V1~V6) | — |

---

## 8. .gitignore 추가 항목

```
# Production env files (auto-generated)
.env
supabase-docker/.env

# Supabase data (volumes are local)
supabase-docker/volumes/db/data/
supabase-docker/volumes/storage/
supabase-docker/volumes/pooler/
supabase-docker/volumes/functions/
```

---

## 9. 리스크 & 완화 (Plan의 R1~R5 구체화)

| # | 리스크 | 구체적 완화 |
|---|---|---|
| R1 | Supabase 공식 파일 업그레이드 충돌 | README에 "supabase-docker/는 공식 저장소에서 복사한 것" 명시, 버전 태그 주석 |
| R2 | Rigel migration이 공식 auth 스키마와 충돌 | 0001~0071을 하나씩 적용, `ON_ERROR_STOP=1`로 즉시 실패 감지, 실패 시 명확한 메시지 |
| R3 | VM 디스크 부족 | install.sh 시작 시 `df /` 체크, 10GB 미만 시 경고 |
| R4 | 사용자가 `docker system prune` 실행 | install.sh 자체에서는 절대 사용하지 않음. README에서도 `docker compose down` 권장 |
| R5 | 포트 충돌 (3000, 8000, 5432) | install.sh에서 포트 사용 여부 체크 후 명확한 에러 메시지 |

---

## 10. 검증 체크리스트 (V1~V6 상세)

### V1. Clean VM 원클릭 설치
- [ ] Ubuntu 24.04 VM에서 `docker`만 설치된 상태
- [ ] `curl | bash` 실행 → `installation complete` 출력
- [ ] stderr에 FATAL/ERROR 없음

### V2. 컨테이너 상태
- [ ] `docker ps` → `supabase-*` 12개 + `rigel-app` 1개 = 13개
- [ ] 모두 `healthy` 또는 `Up`

### V3. 웹 접속
- [ ] `curl -o /dev/null -w "%{http_code}" http://localhost:3000` → 200
- [ ] 브라우저에서 랜딩페이지 렌더링

### V4. 회원가입 → 조직 생성
- [ ] `/signup` → 이메일/비밀번호 입력 → 성공
- [ ] `/onboarding/create-tenant` → 조직 생성 → 성공
- [ ] 대시보드 진입

### V5. 재실행 시 데이터 보존
- [ ] `cd supabase-docker && docker compose down && docker compose up -d`
- [ ] `docker compose down && docker compose up -d` (루트)
- [ ] 로그인 시 기존 계정 유지

### V6. 이미지 캐시 재사용
- [ ] `rm -rf rigel && curl | bash` (소스만 삭제)
- [ ] 이미지 재다운로드 없이 기동 (1분 이내)
