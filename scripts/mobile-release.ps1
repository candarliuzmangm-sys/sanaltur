# Production API'ye baglanan mobil APK uretir.
#
# Calistir:
#   .\scripts\mobile-release.ps1

$ErrorActionPreference = "Stop"
$root   = Split-Path $PSScriptRoot -Parent
$apiUrl = "https://api-production-9e0f.up.railway.app"

Push-Location (Join-Path $root "apps\mobile")
try {
    Write-Host "APK build (release) -> $apiUrl" -ForegroundColor Cyan
    flutter build apk --release `
        --dart-define=API_BASE_URL=$apiUrl `
        --dart-define=PUBLIC_WEB_URL=$apiUrl

    $apk = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apk) {
        Write-Host ""
        Write-Host "APK hazir: apps\mobile\$apk" -ForegroundColor Green
        Write-Host "Yuklemek icin: adb install -r apps\mobile\$apk" -ForegroundColor DarkGray
    }
} finally {
    Pop-Location
}
