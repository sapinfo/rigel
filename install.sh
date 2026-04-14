#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Rigel 원클릭 설치 (프로덕션)
#
# 사용법:
#   curl -fsSL https://raw.githubusercontent.com/sapinfo/rigel/main/install.sh | bash
#
# 구조 (Design §1.1):
#   supabase-docker/        Supabase 공식 셀프호스팅 (건드리지 않음)
#   docker-compose.yml      Rigel 앱 컨테이너 전용
#
# 재실행 안전: 이미지 캐시 유지, 데이터 보존, migration 중복 방지.
# 절대 금지: docker system prune, docker volume rm (데이터 파괴).
# ============================================================

REPO="https://github.com/sapinfo/rigel.git"
INSTALL_DIR="rigel"

log()  { echo "$@"; }
ok()   { echo "[OK] $@"; }
run()  { echo "[..] $@"; }
err()  { echo "[!]  $@" >&2; }

hr() { echo "=========================================="; }

echo ""
hr
echo "  Rigel - Installation Start"
hr
echo ""

# ─── 1. 사전 요구 확인 ─────────────────────────────────────

COMPOSE_CMD=""
if command -v docker &>/dev/null && docker compose version &>/dev/null; then
  COMPOSE_CMD="docker compose"
elif command -v podman-compose &>/dev/null; then
  COMPOSE_CMD="podman-compose"
else
  err "Docker Compose not found. Install Docker: https://docs.docker.com/get-docker/"
  exit 1
fi
ok "Compose: $COMPOSE_CMD"

for cmd in git curl openssl; do
  if ! command -v $cmd &>/dev/null; then
    err "$cmd not found. Please install."
    exit 1
  fi
done
ok "Prerequisites: git, curl, openssl"

# 디스크 공간 체크 (최소 10GB)
if command -v df &>/dev/null; then
  AVAIL_KB=$(df / 2>/dev/null | tail -1 | awk '{print $4}')
  AVAIL_GB=$((AVAIL_KB / 1024 / 1024))
  if [ "$AVAIL_GB" -lt 10 ]; then
    err "Disk space: ${AVAIL_GB}GB free (need 10GB+). Aborting."
    exit 1
  fi
  ok "Disk: ${AVAIL_GB}GB free"
fi

echo ""

# ─── 2. 소스 다운로드 ─────────────────────────────────────

if [ -f "docker-compose.yml" ] && [ -d "supabase-docker" ] && [ -d "src" ]; then
  ok "Already in Rigel project directory"
else
  if [ -d "$INSTALL_DIR" ]; then
    cd "$INSTALL_DIR"
    run "Updating source..."
    git pull --quiet
    ok "Source updated"
  else
    run "Downloading source..."
    git clone --quiet "$REPO" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    ok "Source downloaded"
  fi
fi

echo ""

# ─── 3. Supabase .env 생성 (조건부) ───────────────────────

if [ ! -f "supabase-docker/.env" ]; then
  run "Generating Supabase secrets..."

  gen_str() { openssl rand -base64 $1 | tr -dc 'a-zA-Z0-9' | head -c $2; }

  POSTGRES_PASSWORD=$(gen_str 32 32)
  JWT_SECRET=$(gen_str 48 64)
  SECRET_KEY_BASE=$(gen_str 48 64)
  VAULT_ENC_KEY=$(gen_str 32 32)
  PG_META_CRYPTO_KEY=$(gen_str 32 32)
  DASHBOARD_PASSWORD=$(gen_str 16 20)
  LOGFLARE_PUB=$(gen_str 32 32)
  LOGFLARE_PRV=$(gen_str 32 32)

  # JWT (HS256) for ANON_KEY, SERVICE_ROLE_KEY
  jwt_b64() { echo -n "$1" | openssl base64 -A | tr '+/' '-_' | tr -d '='; }
  HEADER=$(jwt_b64 '{"alg":"HS256","typ":"JWT"}')
  IAT=$(date +%s); EXP=$((IAT + 157680000))

  ANON_PAYLOAD=$(jwt_b64 "{\"role\":\"anon\",\"iss\":\"supabase\",\"iat\":$IAT,\"exp\":$EXP}")
  ANON_SIG=$(echo -n "$HEADER.$ANON_PAYLOAD" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')
  ANON_KEY="$HEADER.$ANON_PAYLOAD.$ANON_SIG"

  SVC_PAYLOAD=$(jwt_b64 "{\"role\":\"service_role\",\"iss\":\"supabase\",\"iat\":$IAT,\"exp\":$EXP}")
  SVC_SIG=$(echo -n "$HEADER.$SVC_PAYLOAD" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')
  SERVICE_ROLE_KEY="$HEADER.$SVC_PAYLOAD.$SVC_SIG"

  cp supabase-docker/.env.example supabase-docker/.env

  # BSD/GNU sed 호환 (macOS는 -i ''  필요, Linux는 -i 만)
  sedi() {
    if sed --version &>/dev/null; then
      sed -i "$@"
    else
      sed -i '' "$@"
    fi
  }

  sedi "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" supabase-docker/.env
  sedi "s|^JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" supabase-docker/.env
  sedi "s|^ANON_KEY=.*|ANON_KEY=$ANON_KEY|" supabase-docker/.env
  sedi "s|^SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY|" supabase-docker/.env
  sedi "s|^SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$SECRET_KEY_BASE|" supabase-docker/.env
  sedi "s|^VAULT_ENC_KEY=.*|VAULT_ENC_KEY=$VAULT_ENC_KEY|" supabase-docker/.env
  sedi "s|^PG_META_CRYPTO_KEY=.*|PG_META_CRYPTO_KEY=$PG_META_CRYPTO_KEY|" supabase-docker/.env
  sedi "s|^DASHBOARD_PASSWORD=.*|DASHBOARD_PASSWORD=$DASHBOARD_PASSWORD|" supabase-docker/.env
  sedi "s|^LOGFLARE_PUBLIC_ACCESS_TOKEN=.*|LOGFLARE_PUBLIC_ACCESS_TOKEN=$LOGFLARE_PUB|" supabase-docker/.env
  sedi "s|^LOGFLARE_PRIVATE_ACCESS_TOKEN=.*|LOGFLARE_PRIVATE_ACCESS_TOKEN=$LOGFLARE_PRV|" supabase-docker/.env

  ok "supabase-docker/.env created"
else
  ok "supabase-docker/.env already exists"
  ANON_KEY=$(grep "^ANON_KEY=" supabase-docker/.env | cut -d= -f2-)
fi

echo ""

# ─── 4. Supabase 기동 ─────────────────────────────────────

run "Starting Supabase stack (this may take several minutes on first run)..."
cd supabase-docker
$COMPOSE_CMD up -d
cd ..
ok "Supabase started"

echo ""

# ─── 5. DB 기동 대기 ──────────────────────────────────────

run "Waiting for Supabase DB..."
for i in $(seq 1 60); do
  if docker exec supabase-db pg_isready -U postgres &>/dev/null; then
    ok "DB ready after ${i}s"
    break
  fi
  if [ "$i" = "60" ]; then
    err "DB not ready after 60s. Check: docker logs supabase-db"
    exit 1
  fi
  sleep 1
done

echo ""

# ─── 6. Rigel migration + seed (idempotent) ───────────────

MIGRATED=$(docker exec supabase-db psql -U postgres -tA -c "SELECT 1 FROM information_schema.tables WHERE table_name = '_rigel_installed' LIMIT 1" 2>/dev/null || echo "")

if [ -z "$MIGRATED" ]; then
  run "Applying Rigel migrations (71 files)..."
  FAILED=0
  for f in supabase/migrations/*.sql; do
    if [ -f "$f" ]; then
      if docker exec -i supabase-db psql -U postgres -v ON_ERROR_STOP=1 < "$f" > /dev/null 2>&1; then
        :
      else
        err "Migration failed: $(basename $f)"
        FAILED=1
        break
      fi
    fi
  done

  if [ $FAILED -eq 0 ]; then
    if [ -f supabase/seed.sql ]; then
      run "Applying seed data..."
      docker exec -i supabase-db psql -U postgres -v ON_ERROR_STOP=1 < supabase/seed.sql > /dev/null 2>&1 || err "Seed warning (non-fatal)"
    fi
    docker exec supabase-db psql -U postgres -c "CREATE TABLE IF NOT EXISTS _rigel_installed (at timestamptz DEFAULT now())" > /dev/null
    ok "Migrations + seed applied"
  else
    exit 1
  fi
else
  ok "Rigel already installed (migrations skipped)"
fi

echo ""

# ─── 7. Rigel 앱 .env 생성 ────────────────────────────────

if [ ! -f ".env" ]; then
  cat > .env <<EOF
PUBLIC_SUPABASE_URL=http://localhost:8000
PUBLIC_SUPABASE_ANON_KEY=$ANON_KEY
SITE_URL=http://localhost:3000
APP_PORT=3000
EOF
  ok ".env created for Rigel app"
else
  ok ".env already exists"
fi

echo ""

# ─── 8. Rigel 앱 빌드 + 기동 ──────────────────────────────

run "Building and starting Rigel app..."
$COMPOSE_CMD up -d --build
ok "Rigel app started"

echo ""

# ─── Done ─────────────────────────────────────────────────

SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
DASH_PW=$(grep "^DASHBOARD_PASSWORD=" supabase-docker/.env | cut -d= -f2-)

hr
echo "  Installation complete!"
hr
echo ""
echo "  Rigel:            http://${SERVER_IP:-localhost}:3000"
echo "  Supabase Studio:  http://${SERVER_IP:-localhost}:8000"
echo "                    (username: supabase / password: $DASH_PW)"
echo ""
echo "  --- Commands ---"
echo "  Rigel 중지:    $COMPOSE_CMD down"
echo "  Rigel 재시작:  $COMPOSE_CMD restart"
echo "  Rigel 로그:    $COMPOSE_CMD logs -f app"
echo "  Rigel 업데이트: git pull && $COMPOSE_CMD up -d --build"
echo ""
echo "  Supabase 중지: cd supabase-docker && $COMPOSE_CMD down"
echo "  Supabase 로그: cd supabase-docker && $COMPOSE_CMD logs -f"
echo ""
echo "  ⚠  docker system prune 금지 (이미지 캐시 삭제됨)"
echo "  ⚠  docker volume rm 금지 (데이터 삭제됨)"
echo ""
echo "  Issues: https://github.com/sapinfo/rigel/issues"
hr
echo ""
