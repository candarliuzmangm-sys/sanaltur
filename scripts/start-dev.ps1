# Sanaltur gelistirme sunuculari (2 ayri pencere acar)
# Kullanim: .\scripts\start-dev.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

& "$PSScriptRoot\sync-lan-env.ps1"

Write-Host ""
Write-Host "API ve Web ayri PowerShell pencerelerinde baslatiliyor..." -ForegroundColor Green
Write-Host "Kapatmak icin her pencerede Ctrl+C" -ForegroundColor Yellow
Write-Host ""

Start-Process powershell -ArgumentList @(
    "-NoExit", "-Command",
    "Set-Location '$root\apps\api'; Write-Host '=== API (port 3001) ===' -ForegroundColor Cyan; npm run start:dev"
)

Start-Sleep -Seconds 2

Start-Process powershell -ArgumentList @(
    "-NoExit", "-Command",
    "Set-Location '$root\apps\web'; Write-Host '=== Web (port 3000) ===' -ForegroundColor Cyan; npm run dev -H 0.0.0.0"
)

Write-Host "Telefon icin: .\scripts\dev-phone.ps1" -ForegroundColor Cyan
