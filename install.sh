#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Rigel 원클릭 설치 스크립트 (프로덕션)
#
# 사용법:
#   curl -fsSL https://raw.githubusercontent.com/sapinfo/rigel/main/install.sh | bash
#
# 구조:
#   - supabase-docker/  Supabase 공식 셀프호스팅 (그대로 사용)
#   - docker-compose.yml  Rigel 앱 컨테이너
#   - 두 docker compose를 순서대로 실행
# ============================================================

REPO="https://github.com/sapinfo/rigel.git"
INSTALL_DIR="rigel"

echo ""
echo "=========================================="
echo "  Rigel - Installation Start"
echo "=========================================="
echo ""

# ─── 1. Prerequisites ─────────────────────────────────────

COMPOSE_CMD=""
if command -v docker &>/dev/null && docker compose version &>/dev/null; then
  COMPOSE_CMD="docker compose"
elif command -v podman-compose &>/dev/null; then
  COMPOSE_CMD="podman-compose"
else
  echo "[!] Docker Compose not found. Install Docker: https://docs.docker.com/get-docker/"
  exit 1
fi
echo "[OK] Compose: $COMPOSE_CMD"

for cmd in git curl openssl; do
  if ! command -v $cmd &>/dev/null; then
    echo "[!] $cmd not found. Please install it."
    exit 1
  fi
done

echo ""

# ─── 2. Download source ───────────────────────────────────

if [ -f "docker-compose.yml" ] && [ -d "supabase-docker" ]; then
  echo "[OK] Already in Rigel project directory."
else
  if [ -d "$INSTALL_DIR" ]; then
    cd "$INSTALL_DIR"
    git pull --quiet
    echo "[OK] Source updated"
  else
    git clone --quiet "$REPO" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    echo "[OK] Source downloaded"
  fi
fi

echo ""

# ─── 3. Generate Supabase keys ────────────────────────────

if [ ! -f "supabase-docker/.env" ]; then
  echo "[..] Generating Supabase secrets..."

  POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
  JWT_SECRET=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 64)
  SECRET_KEY_BASE=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 64)
  VAULT_ENC_KEY=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
  PG_META_CRYPTO_KEY=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
  DASHBOARD_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)
  LOGFLARE_PUB=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
  LOGFLARE_PRV=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)

  # Generate JWT-based ANON_KEY and SERVICE_ROLE_KEY using JWT_SECRET
  jwt_b64() { echo -n "$1" | openssl base64 -A | tr '+/' '-_' | tr -d '='; }
  HEADER=$(jwt_b64 '{"alg":"HS256","typ":"JWT"}')
  IAT=$(date +%s)
  EXP=$((IAT + 157680000))  # 5 years

  ANON_PAYLOAD=$(jwt_b64 "{\"role\":\"anon\",\"iss\":\"supabase\",\"iat\":$IAT,\"exp\":$EXP}")
  ANON_SIG=$(echo -n "$HEADER.$ANON_PAYLOAD" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')
  ANON_KEY="$HEADER.$ANON_PAYLOAD.$ANON_SIG"

  SVC_PAYLOAD=$(jwt_b64 "{\"role\":\"service_role\",\"iss\":\"supabase\",\"iat\":$IAT,\"exp\":$EXP}")
  SVC_SIG=$(echo -n "$HEADER.$SVC_PAYLOAD" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')
  SERVICE_ROLE_KEY="$HEADER.$SVC_PAYLOAD.$SVC_SIG"

  # Copy .env.example and patch values
  cp supabase-docker/.env.example supabase-docker/.env
  sed -i.bak "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" supabase-docker/.env
  sed -i.bak "s|^JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" supabase-docker/.env
  sed -i.bak "s|^ANON_KEY=.*|ANON_KEY=$ANON_KEY|" supabase-docker/.env
  sed -i.bak "s|^SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY|" supabase-docker/.env
  sed -i.bak "s|^SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$SECRET_KEY_BASE|" supabase-docker/.env
  sed -i.bak "s|^VAULT_ENC_KEY=.*|VAULT_ENC_KEY=$VAULT_ENC_KEY|" supabase-docker/.env
  sed -i.bak "s|^PG_META_CRYPTO_KEY=.*|PG_META_CRYPTO_KEY=$PG_META_CRYPTO_KEY|" supabase-docker/.env
  sed -i.bak "s|^DASHBOARD_PASSWORD=.*|DASHBOARD_PASSWORD=$DASHBOARD_PASSWORD|" supabase-docker/.env
  sed -i.bak "s|^LOGFLARE_PUBLIC_ACCESS_TOKEN=.*|LOGFLARE_PUBLIC_ACCESS_TOKEN=$LOGFLARE_PUB|" supabase-docker/.env
  sed -i.bak "s|^LOGFLARE_PRIVATE_ACCESS_TOKEN=.*|LOGFLARE_PRIVATE_ACCESS_TOKEN=$LOGFLARE_PRV|" supabase-docker/.env
  rm -f supabase-docker/.env.bak

  echo "[OK] supabase-docker/.env created"
else
  echo "[OK] supabase-docker/.env already exists"
  ANON_KEY=$(grep "^ANON_KEY=" supabase-docker/.env | cut -d= -f2-)
fi

echo ""

# ─── 4. Start Supabase ────────────────────────────────────

echo "[..] Starting Supabase stack..."
cd supabase-docker
$COMPOSE_CMD up -d 2>&1 | tail -3

echo ""
echo "[..] Waiting for Supabase DB to be ready (30s)..."
sleep 30

# ─── 5. Apply Rigel migrations + seed ─────────────────────

echo "[..] Applying Rigel migrations and seed..."
cd ..

POSTGRES_PW=$(grep "^POSTGRES_PASSWORD=" supabase-docker/.env | cut -d= -f2-)

# Find Supabase DB container
DB_CONTAINER=$($COMPOSE_CMD -f supabase-docker/docker-compose.yml ps -q db 2>/dev/null || docker ps --filter "name=supabase-db" --format "{{.Names}}" | head -1)

if [ -z "$DB_CONTAINER" ]; then
  echo "[!] Could not find Supabase DB container"
  exit 1
fi

echo "[OK] DB container: $DB_CONTAINER"

# Apply migrations in order
for f in supabase/migrations/*.sql; do
  if [ -f "$f" ]; then
    echo "  - $(basename $f)"
    docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$f" > /dev/null 2>&1 || echo "    (failed — may already exist)"
  fi
done

# Apply seed
if [ -f supabase/seed.sql ]; then
  echo "  - seed.sql"
  docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres < supabase/seed.sql > /dev/null 2>&1 || echo "    (failed — may already exist)"
fi

echo ""

# ─── 6. Configure Rigel app env ───────────────────────────

if [ ! -f ".env" ]; then
  cat > .env <<EOF
PUBLIC_SUPABASE_URL=http://localhost:8000
PUBLIC_SUPABASE_ANON_KEY=$ANON_KEY
SITE_URL=http://localhost:3000
APP_PORT=3000
EOF
  echo "[OK] .env created for Rigel app"
fi

echo ""

# ─── 7. Build and start Rigel app ─────────────────────────

echo "[..] Building and starting Rigel app..."
$COMPOSE_CMD up -d --build 2>&1 | tail -3

echo ""

# ─── 8. Done ───────────────────────────────────────────────

SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

echo "=========================================="
echo "  Rigel installation complete!"
echo "=========================================="
echo ""
echo "  Rigel App:       http://${SERVER_IP:-localhost}:3000"
echo "  Supabase Studio: http://${SERVER_IP:-localhost}:8000"
echo ""
echo "  Supabase dashboard login:"
echo "    username: supabase"
echo "    password: (see supabase-docker/.env → DASHBOARD_PASSWORD)"
echo ""
echo "  --- Commands ---"
echo "  Rigel app:"
echo "    Stop:      $COMPOSE_CMD down"
echo "    Logs:      $COMPOSE_CMD logs -f app"
echo "  Supabase:"
echo "    Stop:      cd supabase-docker && $COMPOSE_CMD down"
echo "    Logs:      cd supabase-docker && $COMPOSE_CMD logs -f"
echo ""
echo "  Issues: https://github.com/sapinfo/rigel/issues"
echo "=========================================="
echo ""
