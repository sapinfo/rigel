#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Rigel 원클릭 설치 스크립트
#
# 사용법:
#   curl -fsSL https://raw.githubusercontent.com/sapinfo/rigel/main/install.sh | bash
#
# 또는 소스를 이미 받은 경우:
#   bash install.sh
# ============================================================

REPO="https://github.com/sapinfo/rigel.git"
INSTALL_DIR="rigel"

echo ""
echo "=========================================="
echo "  Rigel 그룹웨어 설치를 시작합니다"
echo "=========================================="
echo ""

# ─── 1. Docker 또는 Podman 확인 ────────────────────────────

COMPOSE_CMD=""

if command -v docker &>/dev/null; then
  echo "[OK] Docker 발견: $(docker --version)"
  if docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
  elif command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
  else
    echo "[!] docker compose 플러그인이 없습니다."
    echo "    Docker Desktop을 설치하면 자동으로 포함됩니다."
    echo "    https://docs.docker.com/get-docker/"
    exit 1
  fi
elif command -v podman &>/dev/null; then
  echo "[OK] Podman 발견: $(podman --version)"
  if command -v podman-compose &>/dev/null; then
    COMPOSE_CMD="podman-compose"
  else
    echo "[!] podman-compose가 필요합니다."
    echo "    pip install podman-compose"
    exit 1
  fi
else
  echo "[!] Docker 또는 Podman이 설치되어 있지 않습니다."
  echo ""
  echo "  아래 중 하나를 설치해주세요:"
  echo "  - Docker Desktop: https://docs.docker.com/get-docker/"
  echo "  - Podman:         https://podman.io/getting-started/installation"
  echo ""
  exit 1
fi

echo "[OK] Compose 명령어: $COMPOSE_CMD"
echo ""

# ─── 2. 소스 다운로드 ──────────────────────────────────────

if [ -f "docker-compose.yml" ] && [ -d "supabase" ]; then
  echo "[OK] 이미 Rigel 프로젝트 디렉토리에 있습니다."
else
  if [ -d "$INSTALL_DIR" ]; then
    echo "[OK] $INSTALL_DIR 디렉토리가 이미 존재합니다. 업데이트합니다."
    cd "$INSTALL_DIR"
    git pull --quiet
  else
    echo "[..] 소스를 다운로드합니다..."
    if command -v git &>/dev/null; then
      git clone --quiet "$REPO" "$INSTALL_DIR"
      cd "$INSTALL_DIR"
    else
      echo "[!] git이 설치되어 있지 않습니다."
      echo "    https://git-scm.com/downloads 에서 설치해주세요."
      exit 1
    fi
  fi
  echo "[OK] 소스 다운로드 완료"
fi

echo ""

# ─── 3. 환경변수 자동 생성 ─────────────────────────────────

if [ -f ".env" ]; then
  echo "[OK] .env 파일이 이미 존재합니다. 기존 설정을 유지합니다."
else
  echo "[..] 보안 키를 자동 생성합니다..."

  # 랜덤 비밀번호 생성
  POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)
  JWT_SECRET=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 64)

  # Supabase ANON_KEY, SERVICE_KEY 생성 (JWT)
  # Header: {"alg":"HS256","typ":"JWT"}
  JWT_HEADER=$(echo -n '{"alg":"HS256","typ":"JWT"}' | openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n')

  # ANON KEY payload: role=anon
  ANON_PAYLOAD=$(echo -n "{\"role\":\"anon\",\"iss\":\"supabase\",\"iat\":$(date +%s),\"exp\":$(($(date +%s) + 157680000))}" | openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n')
  ANON_SIG=$(echo -n "${JWT_HEADER}.${ANON_PAYLOAD}" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n')
  SUPABASE_ANON_KEY="${JWT_HEADER}.${ANON_PAYLOAD}.${ANON_SIG}"

  # SERVICE KEY payload: role=service_role
  SERVICE_PAYLOAD=$(echo -n "{\"role\":\"service_role\",\"iss\":\"supabase\",\"iat\":$(date +%s),\"exp\":$(($(date +%s) + 157680000))}" | openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n')
  SERVICE_SIG=$(echo -n "${JWT_HEADER}.${SERVICE_PAYLOAD}" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n')
  SUPABASE_SERVICE_KEY="${JWT_HEADER}.${SERVICE_PAYLOAD}.${SERVICE_SIG}"

  # 서버 IP 자동 감지
  SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
  if [ -z "$SERVER_IP" ]; then
    SERVER_IP="localhost"
  fi

  # .env 파일 생성
  cat > .env <<EOF
# ─── Rigel 환경변수 (자동 생성됨) ───
# 생성 시각: $(date)

POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
JWT_SECRET=${JWT_SECRET}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY}
SITE_URL=http://${SERVER_IP}:3000
APP_PORT=3000
API_PORT=8000
POSTGRES_PORT=5432
EOF

  echo "[OK] .env 파일 생성 완료 (보안 키 자동 생성)"
  echo "     서버 주소: http://${SERVER_IP}:3000"
fi

echo ""

# ─── 4. Docker Compose 실행 ────────────────────────────────

echo "[..] 서비스를 시작합니다... (첫 실행 시 이미지 다운로드로 몇 분 걸릴 수 있습니다)"
$COMPOSE_CMD up -d

echo ""

# ─── 5. 완료 ───────────────────────────────────────────────

# .env에서 서버 URL 읽기
SITE_URL=$(grep SITE_URL .env | cut -d= -f2-)

echo "=========================================="
echo "  Rigel 설치가 완료되었습니다!"
echo "=========================================="
echo ""
echo "  접속 주소: ${SITE_URL}"
echo ""
echo "  처음 접속하면 회원가입 → 조직 생성 순서로 진행하세요."
echo ""
echo "  ─── 유용한 명령어 ───"
echo "  중지:     $COMPOSE_CMD down"
echo "  재시작:   $COMPOSE_CMD restart"
echo "  로그:     $COMPOSE_CMD logs -f app"
echo "  업데이트: git pull && $COMPOSE_CMD up -d --build"
echo ""
echo "  문제가 있으면: https://github.com/sapinfo/rigel/issues"
echo "=========================================="
echo ""
