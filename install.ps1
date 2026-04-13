# ============================================================
# Rigel 원클릭 설치 스크립트 (Windows PowerShell)
#
# 사용법 (PowerShell에서 실행):
#   irm https://raw.githubusercontent.com/sapinfo/rigel/main/install.ps1 | iex
#
# 또는 소스를 이미 받은 경우:
#   powershell -ExecutionPolicy Bypass -File install.ps1
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Rigel 그룹웨어 설치를 시작합니다" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$REPO = "https://github.com/sapinfo/rigel.git"
$INSTALL_DIR = "rigel"

# ─── 1. Docker 또는 Podman 확인 ────────────────────────────

$COMPOSE_CMD = $null

if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Host "[OK] Docker 발견" -ForegroundColor Green
    $dockerCompose = docker compose version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $COMPOSE_CMD = "docker compose"
    } elseif (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        $COMPOSE_CMD = "docker-compose"
    } else {
        Write-Host "[!] docker compose 플러그인이 없습니다." -ForegroundColor Red
        Write-Host "    Docker Desktop을 설치하세요: https://docs.docker.com/get-docker/"
        exit 1
    }
} elseif (Get-Command podman -ErrorAction SilentlyContinue) {
    Write-Host "[OK] Podman 발견" -ForegroundColor Green
    if (Get-Command podman-compose -ErrorAction SilentlyContinue) {
        $COMPOSE_CMD = "podman-compose"
    } else {
        Write-Host "[!] podman-compose가 필요합니다." -ForegroundColor Red
        Write-Host "    pip install podman-compose"
        exit 1
    }
} else {
    Write-Host "[!] Docker 또는 Podman이 설치되어 있지 않습니다." -ForegroundColor Red
    Write-Host ""
    Write-Host "  아래 중 하나를 설치해주세요:"
    Write-Host "  - Docker Desktop: https://docs.docker.com/get-docker/"
    Write-Host "  - Podman Desktop: https://podman-desktop.io/"
    Write-Host ""
    exit 1
}

Write-Host "[OK] Compose 명령어: $COMPOSE_CMD" -ForegroundColor Green
Write-Host ""

# ─── 2. 소스 다운로드 ──────────────────────────────────────

if ((Test-Path "docker-compose.yml") -and (Test-Path "supabase")) {
    Write-Host "[OK] 이미 Rigel 프로젝트 디렉토리에 있습니다." -ForegroundColor Green
} else {
    if (Test-Path $INSTALL_DIR) {
        Write-Host "[OK] $INSTALL_DIR 디렉토리가 이미 존재합니다. 업데이트합니다." -ForegroundColor Green
        Set-Location $INSTALL_DIR
        git pull --quiet
    } else {
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Host "[!] git이 설치되어 있지 않습니다." -ForegroundColor Red
            Write-Host "    https://git-scm.com/downloads 에서 설치해주세요."
            exit 1
        }
        Write-Host "[..] 소스를 다운로드합니다..."
        git clone --quiet $REPO $INSTALL_DIR
        Set-Location $INSTALL_DIR
    }
    Write-Host "[OK] 소스 다운로드 완료" -ForegroundColor Green
}

Write-Host ""

# ─── 3. 환경변수 자동 생성 ─────────────────────────────────

if (Test-Path ".env") {
    Write-Host "[OK] .env 파일이 이미 존재합니다. 기존 설정을 유지합니다." -ForegroundColor Green
} else {
    Write-Host "[..] 보안 키를 자동 생성합니다..."

    # 랜덤 문자열 생성 함수
    function New-RandomString($length) {
        $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        -join ((1..$length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    }

    # Base64 URL-safe 인코딩
    function ConvertTo-Base64Url($text) {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
        $b64 = [Convert]::ToBase64String($bytes)
        $b64 = $b64.TrimEnd('=').Replace('+', '-').Replace('/', '_')
        return $b64
    }

    # HMAC-SHA256 서명
    function New-HmacSha256($message, $secret) {
        $hmac = New-Object System.Security.Cryptography.HMACSHA256
        $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($secret)
        $sig = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($message))
        $b64 = [Convert]::ToBase64String($sig)
        return $b64.TrimEnd('=').Replace('+', '-').Replace('/', '_')
    }

    $POSTGRES_PASSWORD = New-RandomString 32
    $JWT_SECRET = New-RandomString 64

    # JWT 생성
    $header = ConvertTo-Base64Url '{"alg":"HS256","typ":"JWT"}'
    $now = [int][double]::Parse((Get-Date -UFormat %s))
    $exp = $now + 157680000  # 5년

    # ANON KEY
    $anonPayload = ConvertTo-Base64Url "{`"role`":`"anon`",`"iss`":`"supabase`",`"iat`":$now,`"exp`":$exp}"
    $anonSig = New-HmacSha256 "$header.$anonPayload" $JWT_SECRET
    $SUPABASE_ANON_KEY = "$header.$anonPayload.$anonSig"

    # SERVICE KEY
    $servicePayload = ConvertTo-Base64Url "{`"role`":`"service_role`",`"iss`":`"supabase`",`"iat`":$now,`"exp`":$exp}"
    $serviceSig = New-HmacSha256 "$header.$servicePayload" $JWT_SECRET
    $SUPABASE_SERVICE_KEY = "$header.$servicePayload.$serviceSig"

    # 서버 IP 자동 감지
    try {
        $SERVER_IP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -ne "127.0.0.1" } | Select-Object -First 1).IPAddress
    } catch {
        $SERVER_IP = "localhost"
    }
    if (-not $SERVER_IP) { $SERVER_IP = "localhost" }

    # .env 파일 생성
    $envContent = @"
# --- Rigel 환경변수 (자동 생성됨) ---
# 생성 시각: $(Get-Date)

POSTGRES_PASSWORD=$POSTGRES_PASSWORD
JWT_SECRET=$JWT_SECRET
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
SUPABASE_SERVICE_KEY=$SUPABASE_SERVICE_KEY
SITE_URL=http://${SERVER_IP}:3000
APP_PORT=3000
API_PORT=8000
POSTGRES_PORT=5432
"@
    $envContent | Out-File -FilePath ".env" -Encoding utf8
    Write-Host "[OK] .env 파일 생성 완료 (보안 키 자동 생성)" -ForegroundColor Green
    Write-Host "     서버 주소: http://${SERVER_IP}:3000" -ForegroundColor Yellow
}

Write-Host ""

# ─── 4. Docker Compose 실행 ────────────────────────────────

Write-Host "[..] 서비스를 시작합니다... (첫 실행 시 이미지 다운로드로 몇 분 걸릴 수 있습니다)"
Invoke-Expression "$COMPOSE_CMD up -d"

Write-Host ""

# ─── 5. 완료 ───────────────────────────────────────────────

$SITE_URL = (Get-Content .env | Select-String "SITE_URL" | ForEach-Object { $_.ToString().Split("=", 2)[1] })

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Rigel 설치가 완료되었습니다!" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  접속 주소: $SITE_URL" -ForegroundColor Yellow
Write-Host ""
Write-Host "  처음 접속하면 회원가입 → 조직 생성 순서로 진행하세요."
Write-Host ""
Write-Host "  --- 유용한 명령어 ---"
Write-Host "  중지:     $COMPOSE_CMD down"
Write-Host "  재시작:   $COMPOSE_CMD restart"
Write-Host "  로그:     $COMPOSE_CMD logs -f app"
Write-Host "  업데이트: git pull; $COMPOSE_CMD up -d --build"
Write-Host ""
Write-Host "  문제가 있으면: https://github.com/sapinfo/rigel/issues"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
