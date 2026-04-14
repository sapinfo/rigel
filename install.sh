#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Rigel 앱 설치 스크립트 (프로덕션)
#
# 사전 요구: Supabase 공식 셀프호스팅이 이미 기동 중이어야 합니다.
#   https://supabase.com/docs/guides/self-hosting/docker
#
#   git clone --depth 1 https://github.com/supabase/supabase
#   cd supabase/docker
#   cp .env.example .env
#   sh ./utils/generate-keys.sh   # ★ 공식 키 자동 생성 유틸
#   docker compose pull
#   docker compose up -d
#
# 이 스크립트는:
#   1. Supabase 기동 상태 확인
#   2. Rigel 소스 준비
#   3. Rigel DB migration + seed 적용 (멱등)
#   4. Rigel 앱 .env 확인
#   5. Rigel 앱 컨테이너 빌드 + 기동
#
# 재실행 안전. 절대 금지: docker system prune, docker volume rm.
# ============================================================

REPO="https://github.com/sapinfo/rigel.git"
INSTALL_DIR="rigel"

log()  { echo "$@"; }
ok()   { echo "[OK] $@"; }
run()  { echo "[..] $@"; }
err()  { echo "[!]  $@" >&2; }
hr()   { echo "=========================================="; }

echo ""
hr
echo "  Rigel App - Installation"
hr
echo ""

# ─── 1. 사전 요구 확인 ─────────────────────────────────────

COMPOSE_CMD=""
CONTAINER_CMD=""
if command -v docker &>/dev/null && docker compose version &>/dev/null; then
  COMPOSE_CMD="docker compose"
  CONTAINER_CMD="docker"
elif command -v podman-compose &>/dev/null; then
  COMPOSE_CMD="podman-compose"
  CONTAINER_CMD="podman"
else
  err "Compose not found. Install Docker or Podman+podman-compose."
  exit 1
fi
ok "Compose: $COMPOSE_CMD (container: $CONTAINER_CMD)"

for cmd in git curl; do
  if ! command -v $cmd &>/dev/null; then
    err "$cmd not found. Please install."
    exit 1
  fi
done
ok "Prerequisites: git, curl"

echo ""

# ─── 2. Supabase 기동 상태 확인 (필수) ────────────────────

run "Checking Supabase (expected: supabase-db container running)..."

if ! $CONTAINER_CMD ps --format '{{.Names}}' | grep -q '^supabase-db$'; then
  err "Supabase is not running."
  err ""
  err "  Install Supabase first (official self-hosting guide):"
  err "    https://supabase.com/docs/guides/self-hosting/docker"
  err ""
  err "  Quick start:"
  err "    git clone --depth 1 https://github.com/supabase/supabase"
  err "    cd supabase/docker"
  err "    cp .env.example .env"
  err "    sh ./utils/generate-keys.sh   # auto-generate secrets"
  err "    docker compose pull"
  err "    docker compose up -d"
  err ""
  err "  ⚠ Install under your home directory (NOT /opt or /usr/local)"
  err "    — root-owned paths break bind-mounted init scripts."
  exit 1
fi

if ! $CONTAINER_CMD exec supabase-db pg_isready -U postgres &>/dev/null; then
  err "supabase-db container exists but not ready. Wait and retry, or check:"
  err "  $CONTAINER_CMD logs supabase-db --tail 50"
  exit 1
fi
ok "Supabase is running"

# Rigel 앱이 join할 Supabase 네트워크 감지
# docker-compose → supabase_default, podman-compose → docker_default (cwd=docker 기준) 등 상이
NETWORK=$($CONTAINER_CMD network ls --format '{{.Name}}' \
  | grep -E '^(supabase_default|docker_default|supabase)$' | head -1 || echo "")
if [ -z "$NETWORK" ]; then
  # fallback: supabase-db가 실제로 연결된 네트워크 찾기
  NETWORK=$($CONTAINER_CMD inspect supabase-db \
    --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}' \
    2>/dev/null | grep -v '^$' | head -1 || echo "")
fi
if [ -z "$NETWORK" ]; then
  err "Supabase container network not found."
  err "Debug: $CONTAINER_CMD network ls"
  exit 1
fi
export SUPABASE_NETWORK="$NETWORK"
ok "Supabase network: $NETWORK"

echo ""

# ─── 3. Rigel 소스 준비 ───────────────────────────────────

if [ -f "docker-compose.yml" ] && [ -d "src" ] && [ -d "supabase/migrations" ]; then
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

# ─── 4. Rigel migration + seed (idempotent) ───────────────

MIGRATED=$($CONTAINER_CMD exec supabase-db psql -U postgres -tA -c "SELECT 1 FROM information_schema.tables WHERE table_name = '_rigel_installed' LIMIT 1" 2>/dev/null || echo "")

if [ -z "$MIGRATED" ]; then
  run "Applying Rigel migrations..."
  FAILED=0
  COUNT=0
  for f in supabase/migrations/*.sql; do
    if [ -f "$f" ]; then
      if $CONTAINER_CMD exec -i supabase-db psql -U postgres -v ON_ERROR_STOP=1 < "$f" > /dev/null 2>&1; then
        COUNT=$((COUNT + 1))
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
      $CONTAINER_CMD exec -i supabase-db psql -U postgres -v ON_ERROR_STOP=1 < supabase/seed.sql > /dev/null 2>&1 \
        || err "Seed warning (non-fatal)"
    fi
    $CONTAINER_CMD exec supabase-db psql -U postgres \
      -c "CREATE TABLE IF NOT EXISTS _rigel_installed (at timestamptz DEFAULT now())" > /dev/null
    ok "Applied $COUNT migrations + seed"
  else
    exit 1
  fi
else
  ok "Rigel already installed (migrations skipped)"
fi

echo ""

# ─── 5. Rigel 앱 .env 확인 ────────────────────────────────

if [ ! -f ".env" ]; then
  err ".env not found."
  err ""
  err "  Create .env from template:"
  err "    cp .env.production.example .env"
  err ""
  err "  Then fill in Supabase connection info from your supabase/docker/.env:"
  err "    PUBLIC_SUPABASE_URL      (e.g. http://localhost:8000)"
  err "    PUBLIC_SUPABASE_ANON_KEY (copy from supabase/docker/.env ANON_KEY)"
  err ""
  err "  Rerun this script after .env is ready."
  exit 1
fi

if ! grep -q "^PUBLIC_SUPABASE_ANON_KEY=.\+" .env; then
  err ".env: PUBLIC_SUPABASE_ANON_KEY is empty."
  err "  Copy ANON_KEY value from your supabase/docker/.env to Rigel .env."
  exit 1
fi

# localhost 기본값 → 서버 IP 자동 치환 (LAN/원격 브라우저 접근 대응)
# PUBLIC_* 변수는 SvelteKit 빌드 시점에 client JS 번들에 baked되므로
# 브라우저에서 해석 가능한 주소여야 함. localhost는 클라이언트 머신의 자기 자신으로 해석됨.
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")
if [ -n "$SERVER_IP" ]; then
  if grep -qE '^PUBLIC_SUPABASE_URL=http://(localhost|127\.0\.0\.1):' .env; then
    run "Auto-replacing PUBLIC_SUPABASE_URL localhost → $SERVER_IP (backup: .env.bak)"
    sed -i.bak -E "s|^PUBLIC_SUPABASE_URL=http://(localhost\|127\.0\.0\.1):|PUBLIC_SUPABASE_URL=http://${SERVER_IP}:|" .env
  fi
  if grep -qE '^SITE_URL=http://(localhost|127\.0\.0\.1):' .env; then
    run "Auto-replacing SITE_URL localhost → $SERVER_IP"
    sed -i.bak -E "s|^SITE_URL=http://(localhost\|127\.0\.0\.1):|SITE_URL=http://${SERVER_IP}:|" .env
  fi
fi

ok ".env configured"

echo ""

# ─── 6. Rigel 앱 빌드 + 기동 ──────────────────────────────

run "Building and starting Rigel app..."
$COMPOSE_CMD up -d --build
ok "Rigel app started"

echo ""

# ─── Done ─────────────────────────────────────────────────

APP_PORT=$(grep "^APP_PORT=" .env 2>/dev/null | cut -d= -f2- || echo "3000")
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

hr
echo "  Installation complete!"
hr
echo ""
echo "  Rigel:            http://${SERVER_IP:-localhost}:${APP_PORT}"
echo ""
echo "  --- Commands ---"
echo "  Rigel 중지:     $COMPOSE_CMD down"
echo "  Rigel 재시작:   $COMPOSE_CMD restart"
echo "  Rigel 로그:     $COMPOSE_CMD logs -f app"
echo "  Rigel 업데이트: git pull && $COMPOSE_CMD up -d --build"
echo ""
echo "  Supabase 관리는 공식 docker compose 디렉토리에서:"
echo "    cd path/to/supabase/docker && docker compose {down|restart|logs}"
echo ""
echo "  ⚠ docker system prune 금지 (이미지 캐시 삭제됨)"
echo "  ⚠ docker volume rm 금지 (데이터 삭제됨)"
echo ""
echo "  Issues: https://github.com/sapinfo/rigel/issues"
hr
echo ""
