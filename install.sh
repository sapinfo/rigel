#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Rigel 원클릭 설치 스크립트
#
# 사용법:
#   curl -fsSL https://raw.githubusercontent.com/sapinfo/rigel/main/install.sh | bash
# ============================================================

REPO="https://github.com/sapinfo/rigel.git"
INSTALL_DIR="rigel"

echo ""
echo "=========================================="
echo "  Rigel - Installation Start"
echo "=========================================="
echo ""

# ─── 1. Check prerequisites ───────────────────────────────

# Docker or Podman
COMPOSE_CMD=""
if command -v docker &>/dev/null; then
  echo "[OK] Docker found: $(docker --version)"
  if docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
  elif command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
  fi
elif command -v podman &>/dev/null; then
  echo "[OK] Podman found: $(podman --version)"
  if command -v podman-compose &>/dev/null; then
    COMPOSE_CMD="podman-compose"
  fi
fi

if [ -z "$COMPOSE_CMD" ]; then
  echo "[!] Docker/Podman + Compose not found."
  echo "    https://docs.docker.com/get-docker/"
  exit 1
fi

# Node.js
if ! command -v node &>/dev/null; then
  echo "[!] Node.js not found. Install Node.js 22+."
  echo "    https://nodejs.org/"
  exit 1
fi
echo "[OK] Node.js: $(node --version)"

# Supabase CLI
if ! command -v supabase &>/dev/null; then
  echo "[!] Supabase CLI not found."
  echo "    Mac:   brew install supabase/tap/supabase"
  echo "    Linux: https://supabase.com/docs/guides/cli/getting-started"
  exit 1
fi
echo "[OK] Supabase CLI: $(supabase --version 2>/dev/null || echo 'installed')"

# Git
if ! command -v git &>/dev/null; then
  echo "[!] git not found. https://git-scm.com/downloads"
  exit 1
fi

echo ""

# ─── 2. Download source ───────────────────────────────────

if [ -f "docker-compose.yml" ] && [ -d "supabase" ]; then
  echo "[OK] Already in Rigel project directory."
else
  if [ -d "$INSTALL_DIR" ]; then
    echo "[OK] $INSTALL_DIR directory exists. Updating..."
    cd "$INSTALL_DIR"
    git pull --quiet
  else
    echo "[..] Downloading source..."
    git clone --quiet "$REPO" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
  fi
  echo "[OK] Source download complete"
fi

echo ""

# ─── 3. Start Supabase ─────────────────────────────────────

echo "[..] Starting Supabase (DB, Auth, Storage, API)..."
supabase start 2>&1 | tail -5

echo ""
echo "[..] Initializing database (migrations + seed)..."
supabase db reset 2>&1 | tail -3

echo ""

# ─── 4. Configure environment ──────────────────────────────

# Get Supabase keys from CLI
SUPABASE_URL=$(supabase status --output json 2>/dev/null | grep -o '"API URL":"[^"]*"' | cut -d'"' -f4 || echo "http://localhost:54321")
ANON_KEY=$(supabase status --output json 2>/dev/null | grep -o '"anon key":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -z "$ANON_KEY" ]; then
  # Fallback: parse from supabase status text output
  ANON_KEY=$(supabase status 2>/dev/null | grep "anon key" | awk '{print $NF}' || echo "")
fi

if [ ! -f ".env.local" ] || [ -z "$(grep PUBLIC_SUPABASE_ANON_KEY .env.local 2>/dev/null)" ]; then
  cat > .env.local <<EOF
PUBLIC_SUPABASE_URL=${SUPABASE_URL:-http://localhost:54321}
PUBLIC_SUPABASE_ANON_KEY=${ANON_KEY}
EOF
  echo "[OK] .env.local created"
else
  echo "[OK] .env.local already exists"
fi

# Docker env
if [ ! -f ".env" ]; then
  cat > .env <<EOF
PUBLIC_SUPABASE_URL=${SUPABASE_URL:-http://localhost:54321}
PUBLIC_SUPABASE_ANON_KEY=${ANON_KEY}
SITE_URL=http://localhost:3000
APP_PORT=3000
EOF
  echo "[OK] .env created for Docker"
fi

echo ""

# ─── 5. Install dependencies + Build ──────────────────────

echo "[..] Installing dependencies..."
npm ci --quiet 2>&1 | tail -1

echo "[..] Building production bundle..."
npm run build 2>&1 | tail -1

echo ""

# ─── 6. Start Rigel App ───────────────────────────────────

echo "[..] Starting Rigel app..."
$COMPOSE_CMD up -d --build 2>&1 | tail -3

echo ""

# ─── 7. Done ───────────────────────────────────────────────

SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

echo "=========================================="
echo "  Rigel installation complete!"
echo "=========================================="
echo ""
echo "  URL: http://${SERVER_IP:-localhost}:3000"
echo ""
echo "  Sign up -> Create organization -> Start!"
echo ""
echo "  --- Commands ---"
echo "  Stop app:        $COMPOSE_CMD down"
echo "  Stop Supabase:   supabase stop"
echo "  Restart app:     $COMPOSE_CMD restart"
echo "  Logs:            $COMPOSE_CMD logs -f app"
echo "  Update:          git pull && npm run build && $COMPOSE_CMD up -d --build"
echo "  DB reset:        supabase db reset"
echo ""
echo "  Issues: https://github.com/sapinfo/rigel/issues"
echo "=========================================="
echo ""
