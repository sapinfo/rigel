# Rigel ↔ Self-Host Supabase 연동 가이드

> Rigel 앱을 **별도 Ubuntu 서버에 Podman으로 설치한 Supabase** 에 연결하는 방법. Supabase 설치 자체는 [supabase-selfhost-podman.md](./supabase-selfhost-podman.md) 참조.

## 전제

- Supabase self-host 스택이 별도 서버에 이미 기동 중 (13개 컨테이너 healthy)
- Rigel 개발/프로덕션 머신에서 해당 서버로 네트워크 접근 가능 (LAN 또는 VPN)
- Rigel 로컬 개발은 `supabase local` (`http://127.0.0.1:54321`)을 썼으므로 프로덕션/원격용 설정을 별도 관리

## 환경 값 정리

설치 시점(2026-04-14) 실제 값:

| 항목 | 값 |
|---|---|
| 서버 IP (LAN) | `192.168.168.118` |
| 도메인 (apex) | `rigelworks.io` |
| Rigel 앱 URL | `https://app.rigelworks.io` |
| Supabase API URL | `https://api.rigelworks.io` |
| Kong 내부 포트 | `8000` (REST / Auth / Studio / Storage 게이트웨이) |
| Postgres direct | `5432` (LAN 내부만 노출) |
| Supavisor transaction pooler | `6543` (LAN 내부만 노출) |
| `POOLER_TENANT_ID` | `rigel` |
| HTTPS 제공 | Cloudflare Tunnel (무료, 자동 SSL) |
| 공개 포트 | 없음 (Tunnel 아웃바운드만) |

## Rigel `.env` 설정

### 원격 Supabase 사용 (프로덕션/스테이징)

`.env.production` 또는 `.env.remote`:

```bash
# Client-side (PUBLIC_ prefix — SvelteKit + Svelte 5)
PUBLIC_SUPABASE_URL=http://192.168.168.118:8000
PUBLIC_SUPABASE_ANON_KEY=<서버 .env의 ANON_KEY 값>

# Server-side (hooks.server.ts, +page.server.ts 등)
SUPABASE_SERVICE_ROLE_KEY=<서버 .env의 SERVICE_ROLE_KEY 값>
```

### 로컬 Supabase 사용 (개발)

기존 `.env.local` 그대로 유지:

```bash
PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
PUBLIC_SUPABASE_ANON_KEY=<supabase start 출력의 anon key>
SUPABASE_SERVICE_ROLE_KEY=<supabase start 출력의 service_role key>
```

> `.env.local`은 gitignore. `.env.production`도 **절대 commit 금지** — `.gitignore`에 추가 확인.

### 키 값 가져오기 (서버에서)

```bash
ssh david@192.168.168.118
grep -E '^(ANON_KEY|SERVICE_ROLE_KEY)=' ~/supabase/docker/.env
```

## DB 연결 (마이그레이션 / 직접 접속)

Rigel repo에서:

### 옵션 A: Direct Postgres (동일 LAN, 권장 X — 장기 연결시 pooler 선호)

```bash
export DB_URL='postgresql://postgres:<POSTGRES_PASSWORD>@192.168.168.118:5432/postgres'
```

### 옵션 B: Supavisor transaction pooler (권장)

```bash
export DB_URL='postgresql://postgres.rigel:<POSTGRES_PASSWORD>@192.168.168.118:6543/postgres'
```

> 사용자 포맷이 `postgres.<POOLER_TENANT_ID>` 형태. 여기서 `rigel`은 Supabase 서버 `.env`의 `POOLER_TENANT_ID` 값.

### 마이그레이션 적용

```bash
cd /path/to/Rigel

# Supabase CLI (로컬과 다른 project 대상)
npx supabase db push --db-url "$DB_URL"

# 또는 psql로 직접 (미적용된 migration 순차 실행 직접 관리 시)
ls supabase/migrations/*.sql | sort | while read f; do
  echo ">> $f"
  psql "$DB_URL" -f "$f"
done
```

> 원격 서버는 Supabase CLI 관리 바깥이라 `supabase link`는 동작 안 함. `--db-url` 명시 필수.

### seed 적용

```bash
psql "$DB_URL" -f supabase/seed.sql
```

프로젝트 규칙상 테스트 데이터는 `seed.sql` 로만 관리 (MCP 직접 INSERT 금지).

## Storage 버킷 동기화

`approval-attachments` 버킷은 migration(`0001_storage.sql` 또는 동등물)에 생성 구문 존재해야 함. **Supabase MCP로 직접 생성하면 볼륨 리셋 시 유실**.

원격 서버에서 버킷 확인:

```bash
psql "$DB_URL" -c "SELECT id, name, public FROM storage.buckets;"
```

## 네트워크 / 방화벽 (Supabase 서버 쪽)

Supabase 서버(ufw 활성 시):

```bash
ssh david@192.168.168.118
sudo ufw allow 8000/tcp    # Kong 게이트웨이
sudo ufw allow 5432/tcp    # Direct Postgres (LAN만 열기 권장)
sudo ufw allow 6543/tcp    # Supavisor pooler
sudo ufw status
```

외부 인터넷 노출 시:

- 80/443만 열고 `docker-compose.caddy.yml` 또는 `docker-compose.nginx.yml`로 HTTPS 리버스 프록시
- `.env`의 `SITE_URL`, `API_EXTERNAL_URL`, `SUPABASE_PUBLIC_URL`을 도메인으로 변경
- Auth email redirect URL들도 함께 점검

## 연결 검증 (smoke)

Rigel 머신에서:

```bash
# 1. Kong 게이트웨이 ping
curl -I http://192.168.168.118:8000/auth/v1/health

# 2. Anon key로 PostgREST 호출
curl "http://192.168.168.118:8000/rest/v1/" \
  -H "apikey: $PUBLIC_SUPABASE_ANON_KEY"

# 3. Postgres direct
psql "$DB_URL" -c 'SELECT version();'

# 4. Supavisor pooler
psql 'postgresql://postgres.rigel:<pw>@192.168.168.118:6543/postgres' -c 'SELECT now();'
```

Rigel 앱 기동 후:
- `/signup` 페이지에서 신규 계정 생성
- 로그인 성공 → `/t/<slug>/approval/inbox` 접근
- Storage 파일 업로드·다운로드

## 주의 / 주의 사항

### Local Supabase와 다른 점

| 항목 | local (`supabase local`) | remote self-host |
|---|---|---|
| URL | `http://127.0.0.1:54321` | `http://<SERVER_IP>:8000` |
| Studio | `http://127.0.0.1:54323` (포트 별도) | `http://<SERVER_IP>:8000` (Kong 통합) |
| 마이그레이션 | `supabase db reset` | `psql --db-url ...` 수동 적용 |
| seed | `supabase db reset` 자동 실행 | `psql --db-url ... -f seed.sql` 수동 |
| 비밀번호 관리 | `.env.local` | Supabase 서버 `~/supabase/docker/.env` |
| Realtime | 자동 활성화 | `realtime-dev.supabase-realtime` 컨테이너 필요 |

### Rigel 도메인 규칙 (CLAUDE.md 반영)

- RLS: `(SELECT auth.uid())` 래핑 — **원격 Supabase에서도 동일**
- Mutation: `SECURITY DEFINER` RPC 경유
- 결재 문서 seed: `SELECT seed_create_document(...)` 헬퍼 (0070 migration) — 원격 DB에도 헬퍼 함수가 마이그레이션에 포함돼 있어야 함
- `auth.users` 직접 INSERT는 프로덕션에서 비권장. 가능하면 `/signup` endpoint 경유

### `.env.production` 관리

- `.gitignore`에 추가 (`.env*` 패턴이면 자동 포함)
- Supabase 서버 키 회전 시 Rigel 쪽도 함께 갱신
- 서버 `.env` 와 Rigel `.env.production`의 `ANON_KEY` / `SERVICE_ROLE_KEY`는 **항상 동일한 쌍** 유지

## 운영 체크리스트 (Rigel 배포 직전)

- [ ] Supabase 서버 13개 컨테이너 healthy
- [ ] `.env.production`의 `PUBLIC_SUPABASE_URL`이 서버 IP/도메인
- [ ] `PUBLIC_SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` 서버와 동기화
- [ ] `supabase/migrations/` 전체가 원격 DB에 적용됨 (`SELECT version, name FROM supabase_migrations.schema_migrations`)
- [ ] `seed.sql` 적용 완료 (테스트 계정 3개 로그인 가능 확인)
- [ ] `approval-attachments` 버킷 존재
- [ ] Rigel dev 서버(5173)에서 원격 Supabase 호출 smoke 3건 통과
- [ ] ufw 포트 8000/5432/6543 열림 (또는 reverse proxy 443)
- [ ] Auth email redirect URL이 Rigel 호스트 반영

## 재설치 / 업데이트

배포 이후 코드 변경 반영, 설정 재검증, 또는 install.sh 개선 사항 적용 시 두 가지 경로.

### 경로 A: 기존 설치 업데이트 (권장, 빠름)

- **언제**: 단순 코드 변경/버그픽스 반영. `.env`와 DB는 그대로.
- **소요**: 1~2분 (이미지 재빌드만)

```bash
cd ~/rigel
git pull
podman-compose up -d --build
sleep 15
podman ps --format "table {{.Names}}\t{{.Status}}" | grep rigel
```

| 유지 | 재생성 |
|---|---|
| `.env`, DB 데이터, Supabase 설정 | rigel-app 컨테이너·이미지 |

### 경로 B: 완전 초기화 후 재설치

- **언제**: `install.sh` 자체를 end-to-end로 검증, `.env` 완전 재작성, 서버 교체
- **주의**: Rigel DB 데이터는 Supabase 서버에 있어 안전. 사용자 계정·조직·결재 문서 모두 보존

```bash
# 1. 기존 Rigel 컨테이너 중지
cd ~/rigel
podman-compose down

# 2. 소스 + .env 삭제
cd ~
rm -rf rigel

# 3. 재설치
git clone https://github.com/sapinfo/rigel.git
cd rigel
cp .env.production.example .env

# 4. ANON_KEY 자동 주입 (Supabase 서버 .env에서 가져오기)
ANON=$(grep ^ANON_KEY= ~/supabase/docker/.env | cut -d= -f2-)
sed -i "s|^PUBLIC_SUPABASE_ANON_KEY=|PUBLIC_SUPABASE_ANON_KEY=${ANON}|" .env

# 5. 설치 (PUBLIC_SUPABASE_URL/SITE_URL은 install.sh가 서버 IP로 자동 치환)
bash install.sh
```

| 동작 | 설명 |
|---|---|
| `install.sh` migration 적용 | `_rigel_installed` 테이블 체크로 **skip** (이미 적용됨) |
| `install.sh` seed 적용 | skip (migration과 함께) |
| PUBLIC_SUPABASE_URL localhost 치환 | `hostname -I` 기반 자동 (예: `192.168.168.118`) |
| 컨테이너 기동 | `podman-compose up -d --build` |

### 검증 (두 경로 공통)

```bash
# 1. install.sh가 최신인지
grep -c "CONTAINER_CMD\|Auto-replacing" ~/rigel/install.sh
# 4 이상이면 최신 반영됨

# 2. .env 치환 확인
grep -E '^(PUBLIC_SUPABASE_URL|SITE_URL)=' ~/rigel/.env
# 모두 서버 IP 포함해야 정상

# 3. 컨테이너 healthy
podman ps --format "table {{.Names}}\t{{.Status}}" | grep rigel
```

브라우저 `http://<SERVER_IP>:3000/login` → 기존 계정(`m3test1@example.com` / `testpass1234`) 로그인 → `/t/m3test-org/...` 이동 성공이면 완료.

### DB도 완전 초기화하고 싶을 때 (드물게 필요)

> ⚠️ **운영 중엔 금지**. 개발 단계에서만. `_rigel_installed` 삭제 시 `install.sh` 재실행으로 migration + seed가 다시 돌아감 (테이블이 이미 있으면 migration SQL에 따라 부분 실패 가능).

```bash
# _rigel_installed 제거 + 기존 앱 데이터 테이블 drop은 수동
podman exec supabase-db psql -U postgres -c "DROP TABLE _rigel_installed;"
# install.sh 재실행 시 migration 다시 적용 시도
```

**프로덕션에서는 DB 초기화 대신 Supabase 서버의 `supabase-db` 볼륨을 백업 → 복구로 롤백**.

## 트러블슈팅

### T1. 로그인/회원가입 눌러도 랜딩페이지로 튕김 (에러 메시지 없음)

- **원인**: HTTP 환경에서 SvelteKit `cookies.set`의 production 기본 `secure=true` → 브라우저가 Secure 쿠키 드롭 → 세션 유실
- **해결**: `src/hooks.server.ts`에서 `event.url.protocol`로 secure 동적 설정 (v3.1 이후 적용됨, commit `bae3460`)
  ```ts
  const isSecure = event.url.protocol === 'https:';
  event.cookies.set(name, value, { ...options, path: '/', secure: isSecure });
  ```
- **검증**: DevTools > Application > Cookies에 `sb-*-auth-token` 쿠키가 Secure 플래그 없이 저장돼있는지 확인

### T2. PUBLIC_SUPABASE_URL이 localhost로 baked됨

- **증상**: 다른 머신 브라우저에서 접속 시 Auth 요청이 `localhost:8000` (클라이언트 자기 자신)으로 감 → 연결 실패 또는 엉뚱한 서비스에서 403 반환
- **원인**: `PUBLIC_*` 변수는 **SvelteKit 빌드 시점**에 client JS 번들에 baked됨. runtime env 변경만으론 브라우저 번들이 안 바뀜
- **해결**:
  1. `.env`의 `PUBLIC_SUPABASE_URL`을 **서버의 LAN/도메인 IP**로 변경
  2. 컨테이너 **재빌드 필수**: `podman-compose up -d --build`
- **예방**: `install.sh`가 `hostname -I` 감지해 자동 치환 (2026-04-14 이후). 명시적으로 localhost 쓰려면 `.env` 편집 후 스크립트 우회

### T3. 회원가입 시 "Error sending confirmation email"

- **원인**: Supabase 기본 `.env`의 SMTP 설정이 placeholder (`SMTP_HOST=supabase-mail` — 존재하지 않는 컨테이너)
- **해결 (내부 배포)**: Supabase 서버 `.env`에서 `ENABLE_EMAIL_AUTOCONFIRM=true` 후 auth 컨테이너 재생성
  ```bash
  cd ~/supabase/docker
  sed -i 's|^ENABLE_EMAIL_AUTOCONFIRM=false|ENABLE_EMAIL_AUTOCONFIRM=true|' .env
  podman-compose up -d --force-recreate supabase-auth
  ```
- **프로덕션**: 실제 SMTP (Gmail/SES/SendGrid) 정보 입력

### T4. 로그인 후 PostgREST 조회가 401 ("No suitable key or wrong key type")

- 서버 측 원인. Supabase 서버 runbook의 Q9 참조: [supabase-selfhost-podman.md#Q9](./supabase-selfhost-podman.md)
- Rigel 쪽은 정상. Supabase 서버 `docker-compose.yml`의 `PGRST_JWT_SECRET` 설정이 podman-compose 호환이어야 함

### T5. rigel-app DNS 에러 `getaddrinfo EAI_AGAIN kong`

- **원인**: Podman aardvark DNS 초기 상태 꼬임. 첫 기동 직후에만 발생
- **해결**: `podman restart rigel-app` (DNS 상태 리셋)
- **예방**: depends_on에 `supabase-kong` healthcheck 조건 추가 고려 (docker-compose.yml, podman-compose 미지원 시 sleep 삽입)

## HTTPS / 도메인 붙이기 (Cloudflare Tunnel)

`http://<서버IP>:3000` 배포가 안정됐으면 도메인 + HTTPS로 승격. 동적 IP/NAT 환경에서 포트포워딩 없이 가능.

### 핵심 변경 사항

1. **Supabase `.env`** 3개 URL을 도메인으로:
   ```bash
   cd ~/supabase/docker
   sed -i 's|^SITE_URL=.*|SITE_URL=https://app.rigelworks.io|' .env
   sed -i 's|^API_EXTERNAL_URL=.*|API_EXTERNAL_URL=https://api.rigelworks.io|' .env
   sed -i 's|^SUPABASE_PUBLIC_URL=.*|SUPABASE_PUBLIC_URL=https://api.rigelworks.io|' .env
   # auth + kong은 컨테이너 rm 후 재생성 (--force-recreate가 podman-compose에선 불안정)
   podman rm -f --depend supabase-kong
   podman-compose up -d
   ```

2. **Rigel `.env`** 2개 URL을 도메인으로 + **재빌드 필수** (PUBLIC_* baked):
   ```bash
   cd ~/rigel
   sed -i 's|^PUBLIC_SUPABASE_URL=.*|PUBLIC_SUPABASE_URL=https://api.rigelworks.io|' .env
   sed -i 's|^SITE_URL=.*|SITE_URL=https://app.rigelworks.io|' .env
   podman-compose down && podman-compose up -d --build
   ```

3. **Cloudflare Tunnel** 구성 — 상세 절차는 [cloudflare-tunnel-https.md](./cloudflare-tunnel-https.md) 참조.
   `ingress` 에 `app.rigelworks.io` → `localhost:3000`, `api.rigelworks.io` → `localhost:8000` 두 라우트만 추가하면 됨.

### 검증

```bash
curl -sI https://app.rigelworks.io | head -3
# HTTP/2 200

curl -sI https://api.rigelworks.io/auth/v1/health | head -3
# HTTP/2 401  (Kong이 apikey 없는 호출 차단 — 정상)
```

브라우저 `https://app.rigelworks.io/login` → 기존 테스트 계정 로그인 → 대시보드.

### 주의

- **api 공개의 실질 보호**: CF WAF + Kong apikey + Postgres RLS 3중. `ANON_KEY`는 **로그인 안 한 손님**만 쓸 수 있는 키라 공개해도 안전 (브라우저에 이미 전달됨)
- **Studio는 공개 권장 안 함**: `Basic Auth`만 있어 LAN 또는 CF Access 뒤로
- **signup 남용 우려**: CF Turnstile 추가하거나 `DISABLE_SIGNUP=true` 로 초대제 운영

## 관련 문서

- [supabase-selfhost-podman.md](./supabase-selfhost-podman.md) — Supabase 서버 자체 설치/운영
- [cloudflare-tunnel-https.md](./cloudflare-tunnel-https.md) — Cloudflare Tunnel HTTPS 배포 상세 절차
- [../archive/2026-04/프로덕션-docker-배포/](../archive/2026-04/프로덕션-docker-배포/) — 이전 Rigel app + Supabase 배포 이력 (rev 2 구조)
- `CLAUDE.md` — Rigel 프로젝트 규칙 (RLS, Mutation, Migration)
