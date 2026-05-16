# Hizli telefon gelistirme — ortam degiskenleri + adb reverse + flutter run
# Kullanim: .\scripts\dev-phone.ps1
# Dart/UI degisikligi sonrasi terminalde sadece: r  (hot reload, ~1 sn)

$ErrorActionPreference = "Stop"

& "$PSScriptRoot\sync-lan-env.ps1"

$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-21.0.11.10-hotspot"
$env:GRADLE_USER_HOME = "C:\gradle-home"
$env:PUB_CACHE = "C:\pub-cache"
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$adb = "$env:ANDROID_HOME\platform-tools\adb.exe"

if (-not (Test-Path $adb)) {
    Write-Host "adb bulunamadi. Android SDK kurulu mu?" -ForegroundColor Red
    exit 1
}

& $adb reverse tcp:3001 tcp:3001 | Out-Null
Write-Host "adb reverse tcp:3001 OK" -ForegroundColor Green

# sync-lan-env.ps1 apps/api/.env ve apps/web/.env.local dosyalarini guncelledi
$publicWeb = (Get-Content "$PSScriptRoot\..\apps\api\.env" | Where-Object { $_ -match '^PUBLIC_WEB_URL=' }) -replace '^PUBLIC_WEB_URL=', ''
if (-not $publicWeb) { $publicWeb = "http://127.0.0.1:3000" }
Write-Host "Flutter PUBLIC_WEB_URL = $publicWeb" -ForegroundColor Cyan

$device = & $adb devices | Select-String "device$" | Where-Object { $_ -notmatch "List" } | ForEach-Object { ($_ -split "\s+")[0] } | Select-Object -First 1
if (-not $device) {
    Write-Host "Telefon bagli degil. USB hata ayiklama acik mi?" -ForegroundColor Red
    exit 1
}
Write-Host "Cihaz: $device" -ForegroundColor Green

Set-Location "$PSScriptRoot\..\apps\mobile"
Write-Host ""
Write-Host "Ilk acilis 3-5 dk surebilir. Sonra kod degisince terminalde:" -ForegroundColor Yellow
Write-Host "  r = hot reload (~1 sn)" -ForegroundColor Cyan
Write-Host "  R = hot restart (~5 sn)" -ForegroundColor Cyan
Write-Host "  q = cikis" -ForegroundColor Cyan
Write-Host ""

# PowerShell '--' ile baslayan argumanlari operator sanir; tirnak icinde verin.
$dartDefines = @(
    "--dart-define=API_BASE_URL=http://127.0.0.1:3001"
    "--dart-define=PUBLIC_WEB_URL=$publicWeb"
)
& flutter run -d $device @dartDefines
