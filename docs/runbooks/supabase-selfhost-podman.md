# Supabase Self-Host 설치/운영 Runbook (Ubuntu + Podman)

> **Supabase production docker** 스택을 Ubuntu 서버에 **rootless Podman**으로 설치·기동·중지·재시작하는 절차. 특정 애플리케이션에 비종속적인 일반 운영 가이드. (2026-04-14 실제 설치 기록 기반)

## 대상 환경

| 항목 | 값 |
|---|---|
| OS | Ubuntu 24.04 LTS (커널 6.8) |
| 계정 | 일반 사용자 (sudo 가능) — 예: `david` (uid 1000) |
| 컨테이너 런타임 | Podman 4.9 (rootless) + podman-compose 1.0.6 |
| Supabase | upstream `supabase/supabase` repo — `docker/` 서브디렉터리 사용 |
| Postgres | 15.8.1 (Supabase 커스텀 이미지) |
| 구성 컨테이너 | 13개 (db, auth, rest, realtime, meta, storage, imgproxy, kong, studio, edge-functions, analytics, vector, pooler) |

## 전제 조건

```bash
# 1. Podman + compose
sudo apt update
sudo apt install -y podman podman-compose

# 2. OpenSSL (기본 설치됨)
openssl version

# 3. Node.js 18+ (add-new-auth-keys.sh 실행용, 1회성)
sudo apt install -y nodejs
node --version    # v18+ 확인
```

> `node`는 비대칭 키 생성에만 쓰이므로 설치 후 제거해도 런타임 영향 없음.

## 설치 경로 정책

- 일반 사용자 홈(`~/supabase`)에 clone. **`/opt` 금지** — docker-compose가 볼륨 상대경로를 쓰기 때문에 소유·권한 문제가 생김.

## 설치 절차

### 1단계: 저장소 clone

```bash
cd ~
git clone --depth 1 https://github.com/supabase/supabase
cd ~/supabase/docker
```

`apps/`, `packages/` 등 다른 디렉터리는 불필요. docker compose는 `docker/` 하위만 사용.

### 2단계: `.env` 템플릿 복사

```bash
cp .env.example .env
wc -l .env      # 344줄이어야 함
```

> 🚨 최소 변수만 있는 `.env`로 시작하면 `DASHBOARD_USERNAME`, `ENABLE_ANONYMOUS_USERS` 등 누락으로 auth/kong이 기동 실패한다. **반드시 `.env.example` 전체 복사**.

### 3단계: 레거시 HS256 키 생성

```bash
sh ./utils/generate-keys.sh --update-env
```

자동 주입 변수 (12개):

| 변수 | 용도 |
|---|---|
| `JWT_SECRET` | HMAC-SHA256 서명 비밀 |
| `ANON_KEY`, `SERVICE_ROLE_KEY` | 레거시 HS256 JWT API 키 |
| `SECRET_KEY_BASE` | Realtime / Supavisor |
| `VAULT_ENC_KEY` | pg_meta vault |
| `PG_META_CRYPTO_KEY` | Studio → postgres-meta |
| `LOGFLARE_PUBLIC_ACCESS_TOKEN`, `LOGFLARE_PRIVATE_ACCESS_TOKEN` | Analytics |
| `S3_PROTOCOL_ACCESS_KEY_ID`, `S3_PROTOCOL_ACCESS_KEY_SECRET` | Storage S3 protocol |
| `MINIO_ROOT_PASSWORD` | MinIO (선택) |
| `POSTGRES_PASSWORD`, `DASHBOARD_PASSWORD` | DB / Studio 접속 |

> ⚠️ `sudo` 붙이지 말 것. `.env` owner가 root로 바뀌면 rootless podman이 읽기 실패.

### 4단계: 비대칭 ES256 키 생성 (신버전 필수)

```bash
sh ./utils/add-new-auth-keys.sh --update-env
```

자동 주입 변수 (6개):

| 변수 | 용도 |
|---|---|
| `JWT_KEYS` | EC P-256 개인키 JWKS (Auth가 서명용) |
| `JWT_JWKS` | EC P-256 공개키 JWKS (PostgREST/Realtime/Storage 검증) |
| `SUPABASE_PUBLISHABLE_KEY` | Opaque API 키 (client-side) |
| `SUPABASE_SECRET_KEY` | Opaque API 키 (server-side) |
| `ANON_KEY_ASYMMETRIC` | 내부용 ES256 JWT anon |
| `SERVICE_ROLE_KEY_ASYMMETRIC` | 내부용 ES256 JWT service_role |

> 이 단계를 건너뛰면 GoTrue v2.186 / PostgREST v14.8 / Realtime v2.76이 **JWKS 파싱 실패로 전부 기동 실패**.

### 5단계: `.env` 수동 패치 (4건)

```bash
# 서버의 실제 LAN IP로 치환
SERVER_IP=192.168.X.X
POOLER_ID=myproject     # 프로젝트 식별자 (영숫자, 하이픈)

# 1. Podman rootless 소켓 경로 (uid 기준)
UID_NUM=$(id -u)
sed -i "s|^DOCKER_SOCKET_LOCATION=.*|DOCKER_SOCKET_LOCATION=/run/user/${UID_NUM}/podman/podman.sock|" .env

# 2. Supavisor 테넌트 ID (placeholder → 프로젝트 식별자)
sed -i "s|^POOLER_TENANT_ID=your-tenant-id|POOLER_TENANT_ID=${POOLER_ID}|" .env

# 3. 외부 접근 URL (다른 머신에서 호출하는 경우)
sed -i "s|^SUPABASE_PUBLIC_URL=http://localhost:8000|SUPABASE_PUBLIC_URL=http://${SERVER_IP}:8000|" .env
sed -i "s|^API_EXTERNAL_URL=http://localhost:8000|API_EXTERNAL_URL=http://${SERVER_IP}:8000|" .env
```

확인:
```bash
grep -E '^(DOCKER_SOCKET_LOCATION|POOLER_TENANT_ID|SUPABASE_PUBLIC_URL|API_EXTERNAL_URL)=' .env
```

| 변수 | 이유 |
|---|---|
| `DOCKER_SOCKET_LOCATION` | 기본값 `/var/run/docker.sock`은 Docker 전용. Podman rootless는 `$XDG_RUNTIME_DIR/podman/podman.sock` (uid 1000 → `/run/user/1000/podman/podman.sock`). docker-compose.yml이 이 변수를 vector 컨테이너에 마운트 |
| `POOLER_TENANT_ID` | 그대로 두면 Supavisor 접속 URL에 `your-tenant-id`가 박힘 |
| `SUPABASE_PUBLIC_URL`, `API_EXTERNAL_URL` | `localhost:8000`은 서버 자신에게만 해석. LAN의 다른 호스트에서 접속하려면 서버 IP 필수 |

### 6단계: Podman rootless 소켓 활성화

```bash
systemctl --user enable --now podman.socket
loginctl enable-linger $USER         # 로그아웃·재부팅 후에도 소켓 유지
ls -la /run/user/$(id -u)/podman/podman.sock    # 존재 확인
```

> `enable-linger` 없이는 SSH 세션 종료 시 user systemd가 내려가고 컨테이너도 같이 내려간다.

### 7단계: 컨테이너 기동

```bash
cd ~/supabase/docker
podman-compose up -d
sleep 30
podman ps --format "table {{.Names}}\t{{.Status}}"
```

**정상 상태**: 13개 컨테이너 모두 `Up N seconds (healthy)` 또는 헬스체크가 없는 서비스(`supabase-rest`, `supabase-meta`, `supabase-edge-functions`)는 `Up` 상태.

## Studio 접속 확인

브라우저에서:

```
http://<SERVER_IP>:8000
```

Basic Auth 팝업:

| 필드 | 값 |
|---|---|
| User Name | `.env`의 `DASHBOARD_USERNAME` (기본 `supabase`) |
| Password | `.env`의 `DASHBOARD_PASSWORD` |

> "password will be sent unencrypted" 경고는 HTTP 때문. LAN 내부면 무해. 외부 노출 시 `docker-compose.caddy.yml` 또는 `docker-compose.nginx.yml`로 HTTPS 붙이면 해결.

## 운영

### 기동 / 중지 / 재시작

```bash
cd ~/supabase/docker

# 전체 기동 (백그라운드)
podman-compose up -d

# 전체 중지 (컨테이너 유지, 데이터 보존)
podman-compose stop

# 중지된 것 다시 시작
podman-compose start

# 전체 재시작
podman-compose restart

# 특정 서비스만
podman-compose restart supabase-auth
podman restart supabase-vector

# 컨테이너 완전 제거 (볼륨·데이터 유지)
podman-compose down
```

### 상태 확인

```bash
# 전체 컨테이너
podman ps --format "table {{.Names}}\t{{.Status}}"

# 특정 서비스 상태 (healthcheck 포함)
podman inspect supabase-db --format '{{.State.Health.Status}}'

# 리소스 사용량
podman stats --no-stream
```

### 로그 확인

```bash
podman logs supabase-db --tail 100
podman logs -f supabase-kong              # follow
podman logs supabase-auth 2>&1 | tail -50
```

### 업그레이드

```bash
cd ~/supabase
git pull
cd docker
podman-compose pull       # 이미지 갱신
podman-compose down       # 볼륨 유지
podman-compose up -d
```

> `.env`는 건드리지 않음. 키·비밀번호 그대로.

### 백업

```bash
# DB 논리 덤프
podman exec supabase-db pg_dumpall -U supabase_admin \
  > backup-$(date +%F-%H%M).sql

# 볼륨 전체 (db + storage + logs + functions)
tar czf supabase-volumes-$(date +%F).tar.gz ~/supabase/docker/volumes
```

### 복구

```bash
# 볼륨 복구 (컨테이너 내린 상태에서)
podman-compose down
tar xzf supabase-volumes-YYYY-MM-DD.tar.gz -C /
podman-compose up -d

# 논리 덤프 복구
cat backup.sql | podman exec -i supabase-db psql -U supabase_admin
```

## 트러블슈팅

### Q1. `supabase-auth` 가 `Failed to load configuration: GOTRUE_EXTERNAL_ANONYMOUS_USERS_ENABLED ... converting '' to type bool` 로 죽음

- 원인: `.env`가 부족. `ENABLE_ANONYMOUS_USERS` 등 누락
- 해결: 2단계 (`.env.example` 전체 복사) 선행

### Q2. `supabase-kong` 이 `basicauth_credentials ... username length must be at least 1` 로 죽음

- 원인: `DASHBOARD_USERNAME` 빈 값
- 해결: `.env`에 `DASHBOARD_USERNAME=supabase` 설정

### Q3. `supabase-db` 가 `initdb: removing contents of data directory` 후 exit(1)

- 원인: 첫 기동 bootstrap 실패. 이전 실패 상태 볼륨 잔존
- 해결: `podman-compose down -v` 후 재기동 **(첫 기동 실패라 유실 데이터 없음)**. 이미 데이터가 적재된 상태에서는 절대 `-v` 쓰지 말 것

### Q4. `supabase-vector` 가 unhealthy + `dns error: Try again`

- 원인: vector가 analytics(logflare)보다 먼저 기동되어 DNS 캐시 꼬임
- 해결:
  ```bash
  podman restart supabase-vector
  ```
  재시작만으로 healthy. 반복되면 `podman restart supabase-analytics supabase-vector` 순차

### Q5. `.env`가 root 소유가 됨 → rootless podman 읽기 실패

- 원인: `sudo sh generate-keys.sh` 로 실행
- 해결:
  ```bash
  sudo chown $USER:$USER .env
  chmod 640 .env
  ```
  이후 `utils/*.sh`는 `sudo` 없이 실행

### Q6. Studio에서 SQL 실행 시 JWT 서명 불일치

- 원인: 4단계(비대칭 키) 생략
- 해결: `sh ./utils/add-new-auth-keys.sh --update-env` 후 `podman-compose down && up -d`

### Q7. 외부 호스트에서 Studio 접속 불가

- 원인: ufw 차단 또는 `API_EXTERNAL_URL`이 `localhost`인 상태
- 해결:
  ```bash
  sudo ufw allow 8000/tcp
  grep API_EXTERNAL_URL .env    # localhost 아님 확인
  ```

### Q9. PostgREST 호출 전부 401 Unauthorized, 에러 메시지 "No suitable key or wrong key type"

- 원인: `supabase/docker/docker-compose.yml`의
  ```yaml
  PGRST_JWT_SECRET: ${JWT_JWKS:-${JWT_SECRET}}
  ```
  중첩 default 문법을 **podman-compose가 제대로 파싱 못함** → JWKS JSON 뒤에 `}` 하나가 더 붙어 PostgREST가 JWKS 파싱 실패 → 모든 JWT 401
- 증상:
  - Studio의 SQL Editor는 동작 (PostgREST 안 거침)
  - Rigel 앱 로그인 후 조회/RPC에서 401
  - `podman inspect supabase-rest` 의 `PGRST_JWT_SECRET` 값이 `]}}` 로 끝남 (정상은 `]}`)
- 해결:
  ```bash
  sed -i 's|PGRST_JWT_SECRET: \${JWT_JWKS:-\${JWT_SECRET}}|PGRST_JWT_SECRET: ${JWT_JWKS}|' \
    ~/supabase/docker/docker-compose.yml
  podman-compose up -d --force-recreate supabase-rest
  ```
- 확인:
  ```bash
  podman inspect supabase-rest --format '{{range .Config.Env}}{{println .}}{{end}}' \
    | grep '^PGRST_JWT_SECRET=' | tail -c 20
  # ...]} 로 끝나야 정상
  ```

### Q10. 재부팅 후 컨테이너 자동 기동 안 됨

- 원인: `podman.socket`이 user systemd에 등록되지 않았거나 linger 미설정
- 해결:
  ```bash
  systemctl --user enable --now podman.socket
  loginctl enable-linger $USER
  # 컨테이너 자동 기동은 별도로 generate systemd 필요
  ```
  각 컨테이너에 `--restart=always` 가 붙어있는지 확인 (compose는 기본값 `no`)

## 파괴적 명령 금지 규칙

운영 중인 스택에서는 다음 명령을 **절대** 쓰지 말 것:

- ❌ `podman system prune` — 이미지 캐시 날림
- ❌ `podman volume rm` — 데이터 유실
- ❌ `podman-compose down -v` — 모든 볼륨 삭제
- ✅ 예외: **첫 기동 실패 상태에서만** `down -v`로 bootstrap 꼬임 해결 (데이터가 아직 없음)

## 설치 완료 체크리스트

- [ ] `.env` 344줄
- [ ] HS256 키 12개 + ES256 키 6개 = 18개 모두 값 존재 (`grep -E '^(JWT_SECRET|JWT_KEYS|JWT_JWKS|ANON_KEY|SERVICE_ROLE_KEY|SUPABASE_PUBLISHABLE_KEY|SUPABASE_SECRET_KEY|ANON_KEY_ASYMMETRIC|SERVICE_ROLE_KEY_ASYMMETRIC|SECRET_KEY_BASE|VAULT_ENC_KEY|PG_META_CRYPTO_KEY|LOGFLARE_PUBLIC_ACCESS_TOKEN|LOGFLARE_PRIVATE_ACCESS_TOKEN|S3_PROTOCOL_ACCESS_KEY_ID|S3_PROTOCOL_ACCESS_KEY_SECRET|POSTGRES_PASSWORD|DASHBOARD_PASSWORD)=' .env | wc -l` → 18)
- [ ] `DOCKER_SOCKET_LOCATION=/run/user/<uid>/podman/podman.sock`
- [ ] `POOLER_TENANT_ID`가 placeholder 아님
- [ ] `docker-compose.yml`의 `PGRST_JWT_SECRET`이 `${JWT_JWKS}` 단독 (podman 사용 시 — Q9 참조)
- [ ] `SUPABASE_PUBLIC_URL` / `API_EXTERNAL_URL`이 서버 IP (LAN 접근 시)
- [ ] `systemctl --user is-active podman.socket` → `active`
- [ ] `loginctl show-user $USER | grep Linger` → `Linger=yes`
- [ ] `podman ps` → 13개 컨테이너 Up (healthcheck 있는 10개는 healthy)
- [ ] Studio 로그인 성공 (`http://<SERVER_IP>:8000`)

## 참고

- Supabase 공식 self-hosting: https://supabase.com/docs/guides/self-hosting/docker
- Podman rootless 소켓: `man podman-system-service`
- HTTPS 리버스 프록시: `docker-compose.caddy.yml`, `docker-compose.nginx.yml`
