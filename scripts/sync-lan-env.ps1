# LAN IP ile API / web ortam dosyalarini gunceller (telefon + paylasim linkleri)
# Kullanim: .\scripts\sync-lan-env.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

function Get-LanIp {
    $candidates = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.InterfaceAlias -notmatch 'Loopback|vEthernet|WSL|VirtualBox|VMware|Hyper-V|Docker'
            $_.IPAddress -notmatch '^169\.'
            $_.IPAddress -match '^(192\.168\.|10\.)'
        }

    # Oncelik: Wi-Fi / Ethernet arayuzu, sonra 192.168.x
    $wifi = $candidates | Where-Object { $_.InterfaceAlias -match 'Wi-?Fi|WLAN|Wireless|Ethernet' } |
        Where-Object { $_.IPAddress -match '^192\.168\.' } |
        Select-Object -First 1 -ExpandProperty IPAddress
    if ($wifi) { return $wifi }

    $home = $candidates | Where-Object { $_.IPAddress -match '^192\.168\.' } |
        Select-Object -First 1 -ExpandProperty IPAddress
    if ($home) { return $home }

    $any = $candidates | Select-Object -First 1 -ExpandProperty IPAddress
    if ($any) { return $any }

    return "127.0.0.1"
}

function Set-EnvLine {
    param(
        [string]$FilePath,
        [string]$Key,
        [string]$Value
    )
    $line = "$Key=$Value"
    if (-not (Test-Path $FilePath)) {
        New-Item -ItemType File -Path $FilePath -Force | Out-Null
        Set-Content -Path $FilePath -Value $line -Encoding UTF8
        return
    }
    $content = Get-Content $FilePath -Raw -Encoding UTF8
    $pattern = "(?m)^$([regex]::Escape($Key))=.*$"
    if ($content -match $pattern) {
        $content = [regex]::Replace($content, $pattern, $line)
    } else {
        if ($content.Length -gt 0 -and -not $content.EndsWith("`n")) { $content += "`n" }
        $content += "$line`n"
    }
    Set-Content -Path $FilePath -Value $content.TrimEnd() -Encoding UTF8 -NoNewline
    Add-Content -Path $FilePath -Value "" -Encoding UTF8
}

$lanIp = Get-LanIp
$apiPublic = "http://${lanIp}:3001"
$webPublic = "http://${lanIp}:3000"

$apiEnv = Join-Path $root "apps\api\.env"
$webEnvLocal = Join-Path $root "apps\web\.env.local"

Set-EnvLine -FilePath $apiEnv -Key "API_PUBLIC_URL" -Value $apiPublic
Set-EnvLine -FilePath $apiEnv -Key "PUBLIC_WEB_URL" -Value $webPublic
Set-EnvLine -FilePath $webEnvLocal -Key "NEXT_PUBLIC_API_URL" -Value "$apiPublic/api/v1"

Write-Host "LAN IP: $lanIp" -ForegroundColor Green
Write-Host "  apps/api/.env" -ForegroundColor Cyan
Write-Host "    API_PUBLIC_URL  = $apiPublic"
Write-Host "    PUBLIC_WEB_URL  = $webPublic"
Write-Host "  apps/web/.env.local" -ForegroundColor Cyan
Write-Host "    NEXT_PUBLIC_API_URL = $apiPublic/api/v1"
Write-Host ""
Write-Host "API ve web sunucusunu yeniden baslatin (degisiklik icin)." -ForegroundColor Yellow
