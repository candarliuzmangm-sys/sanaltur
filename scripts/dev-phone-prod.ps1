# Telefondaki Flutter app'ini Railway production API'sine baglar (debug + hot reload).
#
# On kosul:
#   - Telefon USB ile bagli
#   - Telefonda USB Hata Ayiklama acik
#   - "Bilgisayara guven" onayi verildi
#
# Calistir:
#   .\scripts\dev-phone-prod.ps1

$ErrorActionPreference = "Stop"
$root   = Split-Path $PSScriptRoot -Parent
$apiUrl = "https://api-production-9e0f.up.railway.app"

Write-Host "ADB cihaz kontrol..." -ForegroundColor Cyan
$adbOut = adb devices | Select-String -Pattern "device$"
if (-not $adbOut) {
    Write-Host ""
    Write-Host "Telefon bulunamadi!" -ForegroundColor Red
    Write-Host "  1. USB kablo bagli olsun" -ForegroundColor Yellow
    Write-Host "  2. Telefonda USB Hata Ayiklama acik olsun" -ForegroundColor Yellow
    Write-Host "  3. Bilgisayara Guven popup'inda Tamam de" -ForegroundColor Yellow
    exit 1
}
Write-Host "Cihaz bulundu: $($adbOut -join ', ')" -ForegroundColor Green

Push-Location (Join-Path $root "apps\mobile")
try {
    Write-Host ""
    Write-Host "API: $apiUrl" -ForegroundColor Cyan
    Write-Host "Baslat (hot reload icin 'r', restart 'R', cikis 'q')" -ForegroundColor DarkGray
    Write-Host ""
    flutter run `
        --dart-define=API_BASE_URL=$apiUrl `
        --dart-define=PUBLIC_WEB_URL=$apiUrl
} finally {
    Pop-Location
}
