# Plan — 프로덕션 Docker 배포

> Feature: `프로덕션-docker-배포`
> Date: 2026-04-14
> Phase: PDCA Plan

---

## Executive Summary

| 관점 | 내용 |
|---|---|
| **Problem** | 오픈소스 그룹웨어 사용자가 비개발자도 쉽게 자사 서버에 설치·운영할 수 있어야 함. Supabase CLI 방식은 Windows에서 Docker Desktop 강제, 프로덕션 검증 안 됨 |
| **Solution** | Supabase 공식 셀프호스팅 docker-compose를 **그대로** 사용 + Rigel 앱 컨테이너 **완전 분리**. 두 docker-compose를 install.sh로 순차 실행 |
| **Function UX** | `curl ... \| bash` 한 줄로 전체 스택 기동. Docker만 있으면 OS 무관. Rigel migration은 Supabase DB 기동 후 자동 적용 |
| **Core Value** | 재미 한국기업 IT 담당자가 1시간 내 자사 서버에 설치 완료. Supabase 공식 구성이므로 업그레이드/이슈 대응 가능 |

---

## 1. 배경 & 문제 정의

### 1.1 왜 필요한가

- Rigel은 오픈소스 + 셀프호스팅 모델 (재미 한국기업 타겟)
- **비개발자도 설치 가능해야 함** — 설치 난이도가 진입장벽
- 현재 개발 환경은 `supabase start` (CLI)로 잘 동작하지만, **프로덕션 검증 안 됨**

### 1.2 오늘 실패한 시도들 (회고)

| # | 시도 | 실패 원인 |
|---|---|---|
| 1 | Supabase 서비스를 직접 구성 (gotrue, postgrest, storage, kong 개별) | 버전 호환 지옥, 환경변수 수십 개 충돌, GoTrue DB 비밀번호 미스매치 반복 |
| 2 | `supabase start` (CLI)를 프로덕션으로 | Windows는 Docker Desktop 필수, CLI가 프로덕션용이 아님 |
| 3 | 설치 실패 시마다 `docker system prune -af` | 수 GB 이미지 삭제 후 재다운로드로 시간 낭비 반복 |

### 1.3 핵심 교훈

- **Supabase는 공식 셀프호스팅 docker-compose가 존재** — 이걸 건드리지 않고 그대로 사용
- **앱과 Supabase는 별도 docker-compose** — 섞으면 디버깅 불가능
- **이미지는 캐시 유지** — `prune` 금지, 소스(폴더)만 삭제

---

## 2. 목표

### 2.1 Must-Have

1. **원클릭 설치**: `curl ... | bash` 한 줄로 Supabase + Rigel 앱 완전 기동
2. **공식 Supabase 구성 유지**: `supabase-docker/` 디렉토리는 공식 저장소 그대로
3. **앱 컨테이너 분리**: 루트 `docker-compose.yml`은 Rigel 앱만 (Supabase 서비스 정의 금지)
4. **Rigel migration 자동 적용**: 71개 migration + seed를 Supabase DB에 자동 실행
5. **재실행 안전**: 이미 설치된 경우 이미지/데이터 보존하고 업데이트만

### 2.2 Should-Have

6. 보안 키 자동 생성 (POSTGRES_PASSWORD, JWT_SECRET, ANON_KEY, SERVICE_ROLE_KEY 등)
7. 서버 IP 자동 감지
8. 자주 쓰는 명령어 출력 (중지/재시작/로그/업데이트)

### 2.3 Won't-Have (명시적 제외)

- ❌ Supabase 서비스(gotrue, kong 등)를 루트 docker-compose에 포함 — **섞지 않음**
- ❌ `docker system prune` 같은 파괴적 명령 — **이미지 보존**
- ❌ Windows 네이티브 지원 — Linux/macOS만 (Windows는 WSL2 권장)
- ❌ Supabase CLI 의존 — Docker만으로 동작

---

## 3. 스코프

### 3.1 대상 플랫폼

| OS | 지원 | 비고 |
|---|---|---|
| Ubuntu 24.04+ | **Primary** | 프로덕션 권장 |
| macOS (Docker Desktop) | 지원 | 개발자 테스트용 |
| Windows 11 | 불지원 | WSL2 내부 Ubuntu 사용 권장 |

### 3.2 제외 범위

- Cloudflare Tunnel 설정 (별도 feature)
- HTTPS/도메인 설정 (별도 feature)
- 백업/복구 전략 (별도 feature)

---

## 4. 구조

### 4.1 디렉토리

```
rigel/
├── supabase-docker/          ← Supabase 공식 셀프호스팅 (건드리지 않음)
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── .env                   ← install.sh가 생성 (gitignore)
│   └── volumes/
│       ├── api/kong.yml
│       ├── db/ (*.sql)
│       └── logs/vector.yml
│
├── docker-compose.yml        ← Rigel 앱 컨테이너 전용
├── Dockerfile                ← SvelteKit 빌드 이미지
├── .env                      ← install.sh가 생성 (gitignore)
├── .env.production.example
├── install.sh                ← 두 docker-compose를 순서대로 실행
│
├── supabase/migrations/      ← Rigel 전용 71개 migration (기존)
├── supabase/seed.sql         ← Rigel seed (기존)
│
└── src/...                   ← SvelteKit 앱
```

### 4.2 실행 흐름

```
install.sh
  ├─ 1. 사전 요구 확인 (docker, git, openssl)
  ├─ 2. 소스 다운로드 (git clone)
  ├─ 3. supabase-docker/.env 생성 (보안 키 자동 생성)
  ├─ 4. cd supabase-docker && docker compose up -d  ← Supabase 기동
  ├─ 5. DB 기동 대기 (healthcheck)
  ├─ 6. Rigel migration 71개 + seed 적용 (docker exec psql)
  ├─ 7. .env 생성 (앱용)
  ├─ 8. cd .. && docker compose up -d --build  ← Rigel 앱 기동
  └─ 9. 접속 URL 출력
```

---

## 5. 성공 기준

### 5.1 검증 단계

| # | 검증 | 통과 기준 |
|---|---|---|
| V1 | Ubuntu 24.04 clean VM에서 원클릭 설치 | `installation complete` 출력, 에러 없음 |
| V2 | 전체 컨테이너 기동 | Supabase 10+ 컨테이너 + rigel-app 모두 healthy |
| V3 | 웹 접속 | `http://서버IP:3000` → 200 OK, 랜딩페이지 표시 |
| V4 | 회원가입 → 조직 생성 | 로그인까지 정상 |
| V5 | 재실행 시 데이터 보존 | `docker compose down` → `up -d` 후 데이터 유지 |
| V6 | 이미지 캐시 재사용 | 두 번째 설치 시 이미지 재다운로드 없음 |

### 5.2 성능 기준

- 최초 설치: 10~20분 (이미지 다운로드 포함)
- 재실행: 1분 이내
- RAM: 6GB 미만 (Supabase 스택 + 앱)

---

## 6. 위험 & 완화

| # | 위험 | 영향 | 완화 |
|---|---|---|---|
| R1 | Supabase 공식 구조 변경으로 파일 누락 | 설치 실패 | `supabase-docker/`를 git에 포함 (동기화 안 함) |
| R2 | Rigel migration이 공식 Supabase DB와 충돌 (auth 스키마 등) | 설치 실패 | migration 앞에 `IF NOT EXISTS` 사용, `auth.users` 참조만 함 |
| R3 | VM 디스크 부족 | 설치 실패 | 사전 요구에 "40GB 이상 디스크" 명시 |
| R4 | install.sh가 이미지 캐시 파괴 | 시간 낭비 | `docker system prune` 절대 사용 금지, 소스만 삭제 |
| R5 | 포트 충돌 (8000, 3000, 5432) | 기동 실패 | 설치 전 기존 컨테이너 체크, 명확한 에러 메시지 |

---

## 7. 다음 단계

→ `/pdca design 프로덕션-docker-배포` (설계 문서 작성)
