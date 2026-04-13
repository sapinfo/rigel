# ============================================================
# Rigel One-Click Install Script (Windows PowerShell)
#
# Usage:
#   irm https://raw.githubusercontent.com/sapinfo/rigel/main/install.ps1 | iex
#
# Or if you already cloned the source:
#   powershell -ExecutionPolicy Bypass -File install.ps1
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Rigel Groupware - Installation Start" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$REPO = "https://github.com/sapinfo/rigel.git"
$INSTALL_DIR = "rigel"

# --- 1. Check Docker or Podman ---

$COMPOSE_CMD = $null

if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Host "[OK] Docker found" -ForegroundColor Green
    $dockerCompose = docker compose version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $COMPOSE_CMD = "docker compose"
    } elseif (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        $COMPOSE_CMD = "docker-compose"
    } else {
        Write-Host "[!] docker compose plugin not found." -ForegroundColor Red
        Write-Host "    Install Docker Desktop: https://docs.docker.com/get-docker/"
        exit 1
    }
} elseif (Get-Command podman -ErrorAction SilentlyContinue) {
    Write-Host "[OK] Podman found" -ForegroundColor Green
    if (Get-Command podman-compose -ErrorAction SilentlyContinue) {
        $COMPOSE_CMD = "podman-compose"
    } else {
        Write-Host "[!] podman-compose is required." -ForegroundColor Red
        Write-Host "    Run: pip install podman-compose"
        exit 1
    }
} else {
    Write-Host "[!] Docker or Podman is not installed." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Please install one of the following:"
    Write-Host "  - Docker Desktop: https://docs.docker.com/get-docker/"
    Write-Host "  - Podman Desktop: https://podman-desktop.io/"
    Write-Host ""
    exit 1
}

Write-Host "[OK] Compose command: $COMPOSE_CMD" -ForegroundColor Green
Write-Host ""

# --- 2. Download source ---

if ((Test-Path "docker-compose.yml") -and (Test-Path "supabase")) {
    Write-Host "[OK] Already in Rigel project directory." -ForegroundColor Green
} else {
    if (Test-Path $INSTALL_DIR) {
        Write-Host "[OK] $INSTALL_DIR directory exists. Updating..." -ForegroundColor Green
        Set-Location $INSTALL_DIR
        git pull --quiet
    } else {
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Host "[!] git is not installed." -ForegroundColor Red
            Write-Host "    Download from: https://git-scm.com/downloads"
            exit 1
        }
        Write-Host "[..] Downloading source..."
        git clone --quiet $REPO $INSTALL_DIR
        Set-Location $INSTALL_DIR
    }
    Write-Host "[OK] Source download complete" -ForegroundColor Green
}

Write-Host ""

# --- 3. Generate environment variables ---

if (Test-Path ".env") {
    Write-Host "[OK] .env file already exists. Keeping existing settings." -ForegroundColor Green
} else {
    Write-Host "[..] Generating security keys..."

    function New-RandomString($length) {
        $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        -join ((1..$length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    }

    function ConvertTo-Base64Url($text) {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
        $b64 = [Convert]::ToBase64String($bytes)
        $b64 = $b64.TrimEnd('=').Replace('+', '-').Replace('/', '_')
        return $b64
    }

    function New-HmacSha256($message, $secret) {
        $hmac = New-Object System.Security.Cryptography.HMACSHA256
        $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($secret)
        $sig = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($message))
        $b64 = [Convert]::ToBase64String($sig)
        return $b64.TrimEnd('=').Replace('+', '-').Replace('/', '_')
    }

    $POSTGRES_PASSWORD = New-RandomString 32
    $JWT_SECRET = New-RandomString 64

    $header = ConvertTo-Base64Url '{"alg":"HS256","typ":"JWT"}'
    $now = [int][double]::Parse((Get-Date -UFormat %s))
    $exp = $now + 157680000

    $anonPayload = ConvertTo-Base64Url "{`"role`":`"anon`",`"iss`":`"supabase`",`"iat`":$now,`"exp`":$exp}"
    $anonSig = New-HmacSha256 "$header.$anonPayload" $JWT_SECRET
    $SUPABASE_ANON_KEY = "$header.$anonPayload.$anonSig"

    $servicePayload = ConvertTo-Base64Url "{`"role`":`"service_role`",`"iss`":`"supabase`",`"iat`":$now,`"exp`":$exp}"
    $serviceSig = New-HmacSha256 "$header.$servicePayload" $JWT_SECRET
    $SUPABASE_SERVICE_KEY = "$header.$servicePayload.$serviceSig"

    try {
        $SERVER_IP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -ne "127.0.0.1" } | Select-Object -First 1).IPAddress
    } catch {
        $SERVER_IP = "localhost"
    }
    if (-not $SERVER_IP) { $SERVER_IP = "localhost" }

    $envContent = @"
# Rigel Environment Variables (auto-generated)
# Generated: $(Get-Date)

POSTGRES_PASSWORD=$POSTGRES_PASSWORD
JWT_SECRET=$JWT_SECRET
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
SUPABASE_SERVICE_KEY=$SUPABASE_SERVICE_KEY
SITE_URL=http://${SERVER_IP}:3000
APP_PORT=3000
API_PORT=8000
POSTGRES_PORT=5432
"@
    [System.IO.File]::WriteAllText((Join-Path $PWD ".env"), $envContent, [System.Text.Encoding]::UTF8)
    Write-Host "[OK] .env file created (security keys auto-generated)" -ForegroundColor Green
    Write-Host "     Server URL: http://${SERVER_IP}:3000" -ForegroundColor Yellow
}

Write-Host ""

# --- 4. Start Docker Compose ---

Write-Host "[..] Starting services... (first run may take several minutes to download images)"
Invoke-Expression "$COMPOSE_CMD up -d"

Write-Host ""

# --- 5. Done ---

$SITE_URL = (Get-Content .env | Select-String "SITE_URL" | ForEach-Object { $_.ToString().Split("=", 2)[1] })

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Rigel installation complete!" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  URL: $SITE_URL" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Open browser -> Sign up -> Create organization -> Start!"
Write-Host ""
Write-Host "  --- Useful commands ---"
Write-Host "  Stop:     $COMPOSE_CMD down"
Write-Host "  Restart:  $COMPOSE_CMD restart"
Write-Host "  Logs:     $COMPOSE_CMD logs -f app"
Write-Host "  Update:   git pull; $COMPOSE_CMD up -d --build"
Write-Host ""
Write-Host "  Issues: https://github.com/sapinfo/rigel/issues"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
