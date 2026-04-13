# ============================================================
# Rigel One-Click Install Script (Windows PowerShell)
#
# Usage:
#   irm https://raw.githubusercontent.com/sapinfo/rigel/main/install.ps1 | iex
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Rigel - Installation Start" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$REPO = "https://github.com/sapinfo/rigel.git"
$INSTALL_DIR = "rigel"

# --- 1. Check prerequisites ---

$COMPOSE_CMD = $null

if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Host "[OK] Docker found" -ForegroundColor Green
    $dockerCompose = docker compose version 2>&1
    if ($LASTEXITCODE -eq 0) { $COMPOSE_CMD = "docker compose" }
    elseif (Get-Command docker-compose -ErrorAction SilentlyContinue) { $COMPOSE_CMD = "docker-compose" }
} elseif (Get-Command podman -ErrorAction SilentlyContinue) {
    Write-Host "[OK] Podman found" -ForegroundColor Green
    if (Get-Command podman-compose -ErrorAction SilentlyContinue) { $COMPOSE_CMD = "podman-compose" }
}

if (-not $COMPOSE_CMD) {
    Write-Host "[!] Docker/Podman + Compose not found." -ForegroundColor Red
    Write-Host "    https://docs.docker.com/get-docker/"
    exit 1
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "[!] Node.js not found. Install Node.js 22+." -ForegroundColor Red
    Write-Host "    https://nodejs.org/"
    exit 1
}
Write-Host "[OK] Node.js: $(node --version)" -ForegroundColor Green

if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
    Write-Host "[!] Supabase CLI not found." -ForegroundColor Red
    Write-Host "    https://supabase.com/docs/guides/cli/getting-started"
    exit 1
}
Write-Host "[OK] Supabase CLI found" -ForegroundColor Green

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[!] git not found. https://git-scm.com/downloads" -ForegroundColor Red
    exit 1
}

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
        Write-Host "[..] Downloading source..."
        git clone --quiet $REPO $INSTALL_DIR
        Set-Location $INSTALL_DIR
    }
    Write-Host "[OK] Source download complete" -ForegroundColor Green
}

Write-Host ""

# --- 3. Start Supabase ---

Write-Host "[..] Starting Supabase (DB, Auth, Storage, API)..."
supabase start

Write-Host ""
Write-Host "[..] Initializing database (migrations + seed)..."
supabase db reset

Write-Host ""

# --- 4. Configure environment ---

$statusJson = supabase status --output json 2>$null | ConvertFrom-Json
$SUPABASE_URL = if ($statusJson.'API URL') { $statusJson.'API URL' } else { "http://localhost:54321" }
$ANON_KEY = if ($statusJson.'anon key') { $statusJson.'anon key' } else { "" }

if (-not (Test-Path ".env.local")) {
    @"
PUBLIC_SUPABASE_URL=$SUPABASE_URL
PUBLIC_SUPABASE_ANON_KEY=$ANON_KEY
"@ | Out-File -FilePath ".env.local" -Encoding utf8
    Write-Host "[OK] .env.local created" -ForegroundColor Green
}

if (-not (Test-Path ".env")) {
    @"
PUBLIC_SUPABASE_URL=$SUPABASE_URL
PUBLIC_SUPABASE_ANON_KEY=$ANON_KEY
SITE_URL=http://localhost:3000
APP_PORT=3000
"@ | Out-File -FilePath ".env" -Encoding utf8
    Write-Host "[OK] .env created for Docker" -ForegroundColor Green
}

Write-Host ""

# --- 5. Install + Build ---

Write-Host "[..] Installing dependencies..."
npm ci --quiet

Write-Host "[..] Building production bundle..."
npm run build

Write-Host ""

# --- 6. Start Rigel App ---

Write-Host "[..] Starting Rigel app..."
Invoke-Expression "$COMPOSE_CMD up -d --build"

Write-Host ""

# --- 7. Done ---

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Rigel installation complete!" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  URL: http://localhost:3000" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Sign up -> Create organization -> Start!"
Write-Host ""
Write-Host "  --- Commands ---"
Write-Host "  Stop app:        $COMPOSE_CMD down"
Write-Host "  Stop Supabase:   supabase stop"
Write-Host "  Restart app:     $COMPOSE_CMD restart"
Write-Host "  Update:          git pull; npm run build; $COMPOSE_CMD up -d --build"
Write-Host "  DB reset:        supabase db reset"
Write-Host ""
Write-Host "  Issues: https://github.com/sapinfo/rigel/issues"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
