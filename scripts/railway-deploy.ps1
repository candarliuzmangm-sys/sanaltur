# Sanaltur API -> Railway deploy
#
# 1) railway.com -> Proje -> Settings -> Tokens -> "Project Token" olustur
# 2) PowerShell:
#      cd d:\sanaltur
#      $env:RAILWAY_TOKEN = "proje-token-buraya"
#      .\scripts\railway-deploy.ps1
#
# Token'i bu dosyaya veya git'e YAZMAYIN.

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$tokenCandidates = @(
    (Join-Path $root "railway-token.txt"),
    (Join-Path $root ".railway-token")
)

function Read-TokenFile([string]$path) {
    $t = (Get-Content $path -Raw -ErrorAction SilentlyContinue).Trim()
    if ($t -and $t -notmatch '^(#|BURAYA|REPLACE)') { return $t }
    return $null
}

if (-not $env:RAILWAY_TOKEN) {
    foreach ($f in $tokenCandidates) {
        if (Test-Path $f) {
            $env:RAILWAY_TOKEN = Read-TokenFile $f
            if ($env:RAILWAY_TOKEN) { break }
        }
    }
}
if (-not $env:RAILWAY_API_TOKEN -and $env:RAILWAY_TOKEN) {
    $env:RAILWAY_API_TOKEN = $env:RAILWAY_TOKEN
}
if (-not $env:RAILWAY_TOKEN -and $env:RAILWAY_API_TOKEN) {
    $env:RAILWAY_TOKEN = $env:RAILWAY_API_TOKEN
}

if (-not $env:RAILWAY_TOKEN) {
    Write-Host ""
    Write-Host "Railway token dosyasi bulunamadi." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1) d:\sanaltur\railway-token.txt olusturun (Explorerda gorunur)" -ForegroundColor Cyan
    Write-Host "2) icine SADECE token yapistirin, kaydedin" -ForegroundColor White
    Write-Host "3) .\scripts\railway-deploy.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "Ornek dosya: railway-token.txt.example" -ForegroundColor DarkGray
    Write-Host ""
    exit 1
}

$apiDir = Resolve-Path (Join-Path $PSScriptRoot "..\apps\api")
Set-Location $apiDir

Write-Host "Konum: $apiDir" -ForegroundColor DarkGray
Write-Host 'Railway deploy gonderiliyor...' -ForegroundColor Cyan

npx --yes @railway/cli@latest up --detach 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Deploy basarisiz." -ForegroundColor Red
    Write-Host "- Token 'Project Token' mi? (Account token degil)" -ForegroundColor Yellow
    Write-Host "- Token bu projeye mi ait?" -ForegroundColor Yellow
    Write-Host '- Alternatif: GitHub + Root Directory apps/api' -ForegroundColor Yellow
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Deploy kuyruga alindi." -ForegroundColor Green
Write-Host "Panel: railway.com -> Deployments -> Logs" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sonra Variables (apps/api/.env.railway.example):" -ForegroundColor Yellow
Write-Host "  API_PUBLIC_URL = https://XXX.up.railway.app" -ForegroundColor White
Write-Host "  PUBLIC_WEB_URL = ayni adres" -ForegroundColor White
Write-Host '  DATABASE_URL, REDIS_URL = Postgres/Redis plugin' -ForegroundColor White
Write-Host "  STORAGE_MODE=r2 ve R2 bilgileri" -ForegroundColor White
