# Railway tam otomatik kurulum (GraphQL API)
#
# Kurulum:
# 1) railway.com/account/tokens -> ACCOUNT API TOKEN olustur (Project token DEGIL)
#    Not: Workspace "candarliuzmangm-sys's Projects" secin
# 2) d:\sanaltur\railway-token.txt icine token'i yapistir
# 3) PowerShell:
#      cd d:\sanaltur
#      .\scripts\railway-setup-full.ps1
#
# Yapilanlar:
# - Proje olusturur (yoksa)
# - PostgreSQL ekler
# - Redis ekler
# - GitHub repo'dan API servisi olusturur
# - Variables doldurur (DATABASE_URL, REDIS_URL, JWT_SECRET vb.)
# - Domain uretir
# - Deploy tetikler

param(
    [string]$ProjectName = "sanaltur",
    [string]$GithubRepo = "candarliuzmangm-sys/sanaltur",
    [string]$ServiceName = "api",
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$tokenFile = Join-Path $root "railway-token.txt"

if (-not (Test-Path $tokenFile)) {
    Write-Host "railway-token.txt bulunamadi" -ForegroundColor Red
    exit 1
}

$token = (Get-Content $tokenFile -Raw).Trim()
if (-not $token -or $token -match 'BURAYA') {
    Write-Host "Gecerli token yok" -ForegroundColor Red
    exit 1
}

$endpoint = "https://backboard.railway.com/graphql/v2"
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}

function Invoke-RailwayGql {
    param([string]$Query, [hashtable]$Variables = @{})
    $body = @{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 20 -Compress
    try {
        $response = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $body
        if ($response.errors) {
            $msg = ($response.errors | ForEach-Object { $_.message }) -join "; "
            throw "GraphQL: $msg"
        }
        return $response.data
    } catch {
        throw $_.Exception.Message
    }
}

Write-Host ""
Write-Host "1) Token dogrulama..." -ForegroundColor Cyan
try {
    $me = Invoke-RailwayGql -Query "query { me { id name email } }"
    Write-Host "   OK: $($me.me.name) <$($me.me.email)>" -ForegroundColor Green
} catch {
    Write-Host "   FAIL: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Token Account API Token mi? Project Token degil!" -ForegroundColor Yellow
    Write-Host "https://railway.com/account/tokens -> Create -> Workspace SECIN" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "2) Workspace ve mevcut projeler..." -ForegroundColor Cyan
$workspaces = Invoke-RailwayGql -Query "query { me { workspaces { id name } projects { edges { node { id name } } } } }"
$workspaceId = $workspaces.me.workspaces[0].id
Write-Host "   Workspace: $($workspaces.me.workspaces[0].name) ($workspaceId)" -ForegroundColor Green

$project = $workspaces.me.projects.edges | Where-Object { $_.node.name -eq $ProjectName } | Select-Object -First 1
if ($project) {
    $projectId = $project.node.id
    Write-Host "   Mevcut proje: $ProjectName ($projectId)" -ForegroundColor Green
} else {
    Write-Host "   Proje olusturuluyor: $ProjectName..." -ForegroundColor Yellow
    $createProject = Invoke-RailwayGql -Query "mutation(`$input: ProjectCreateInput!) { projectCreate(input: `$input) { id name } }" -Variables @{
        input = @{ name = $ProjectName; workspaceId = $workspaceId; defaultEnvironmentName = "production" }
    }
    $projectId = $createProject.projectCreate.id
    Write-Host "   Olusturuldu: $projectId" -ForegroundColor Green
}

Write-Host ""
Write-Host "3) Environment bulma..." -ForegroundColor Cyan
$projectInfo = Invoke-RailwayGql -Query "query(`$id: String!) { project(id: `$id) { environments { edges { node { id name } } } services { edges { node { id name } } } } }" -Variables @{ id = $projectId }
$envId = ($projectInfo.project.environments.edges | Where-Object { $_.node.name -eq "production" } | Select-Object -First 1).node.id
if (-not $envId) { $envId = $projectInfo.project.environments.edges[0].node.id }
Write-Host "   Environment: $envId" -ForegroundColor Green

$existingServices = @{}
foreach ($s in $projectInfo.project.services.edges) {
    $existingServices[$s.node.name] = $s.node.id
}

function Ensure-PluginService {
    param([string]$Name, [string]$Image)
    if ($existingServices.ContainsKey($Name)) {
        Write-Host "   $Name zaten var" -ForegroundColor DarkGray
        return $existingServices[$Name]
    }
    Write-Host "   $Name ekleniyor (image: $Image)..." -ForegroundColor Yellow
    $r = Invoke-RailwayGql -Query "mutation(`$input: ServiceCreateInput!) { serviceCreate(input: `$input) { id name } }" -Variables @{
        input = @{
            projectId = $projectId
            name      = $Name
            source    = @{ image = $Image }
        }
    }
    return $r.serviceCreate.id
}

Write-Host ""
Write-Host "4) PostgreSQL ekleniyor..." -ForegroundColor Cyan
$pgId = Ensure-PluginService -Name "Postgres" -Image "ghcr.io/railwayapp-templates/postgres-ssl:16"

Write-Host ""
Write-Host "5) Redis ekleniyor..." -ForegroundColor Cyan
$redisId = Ensure-PluginService -Name "Redis" -Image "bitnami/redis:7.4.1"

Write-Host ""
Write-Host "6) API servisi (GitHub: $GithubRepo)..." -ForegroundColor Cyan
if ($existingServices.ContainsKey($ServiceName)) {
    $apiId = $existingServices[$ServiceName]
    Write-Host "   $ServiceName zaten var: $apiId" -ForegroundColor DarkGray
} else {
    $createApi = Invoke-RailwayGql -Query "mutation(`$input: ServiceCreateInput!) { serviceCreate(input: `$input) { id name } }" -Variables @{
        input = @{
            projectId = $projectId
            name      = $ServiceName
            branch    = $Branch
            source    = @{ repo = $GithubRepo }
        }
    }
    $apiId = $createApi.serviceCreate.id
    Write-Host "   Olusturuldu: $apiId" -ForegroundColor Green
}

Write-Host ""
Write-Host "7) API servis ayarlari (root: apps/api)..." -ForegroundColor Cyan
try {
    Invoke-RailwayGql -Query "mutation(`$serviceId: String!, `$environmentId: String!, `$input: ServiceInstanceUpdateInput!) { serviceInstanceUpdate(serviceId: `$serviceId, environmentId: `$environmentId, input: `$input) }" -Variables @{
        serviceId     = $apiId
        environmentId = $envId
        input = @{
            rootDirectory = "apps/api"
            healthcheckPath = "/health"
            restartPolicyType = "ON_FAILURE"
        }
    } | Out-Null
    Write-Host "   OK" -ForegroundColor Green
} catch {
    Write-Host "   Uyari: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "8) Variables..." -ForegroundColor Cyan
$jwtSecret = -join ((1..48) | ForEach-Object { '{0:x}' -f (Get-Random -Max 16) })
$variables = @{
    NODE_ENV         = "production"
    JWT_SECRET       = $jwtSecret
    JWT_EXPIRES_IN   = "15m"
    JWT_REFRESH_EXPIRES_IN = "7d"
    DATABASE_URL     = '${{Postgres.DATABASE_URL}}'
    REDIS_URL        = '${{Redis.REDIS_URL}}'
    STORAGE_MODE     = "local"
    AI_SERVICE_URL   = "http://127.0.0.1:8000"
}
Invoke-RailwayGql -Query "mutation(`$input: VariableCollectionUpsertInput!) { variableCollectionUpsert(input: `$input) }" -Variables @{
    input = @{
        projectId     = $projectId
        environmentId = $envId
        serviceId     = $apiId
        variables     = $variables
    }
} | Out-Null
Write-Host "   $($variables.Count) degisken yazildi" -ForegroundColor Green

Write-Host ""
Write-Host "9) Domain uretiliyor..." -ForegroundColor Cyan
$domainResult = $null
try {
    $domainResult = Invoke-RailwayGql -Query "mutation(`$input: ServiceDomainCreateInput!) { serviceDomainCreate(input: `$input) { domain } }" -Variables @{
        input = @{
            serviceId     = $apiId
            environmentId = $envId
            targetPort    = 3001
        }
    }
} catch {
    Write-Host "   Domain zaten olabilir, kontrol ediliyor..." -ForegroundColor DarkGray
}

$domain = $null
if ($domainResult) { $domain = $domainResult.serviceDomainCreate.domain }
if (-not $domain) {
    $domains = Invoke-RailwayGql -Query "query(`$serviceId: String!, `$environmentId: String!) { domains(serviceId: `$serviceId, environmentId: `$environmentId) { serviceDomains { domain } } }" -Variables @{
        serviceId = $apiId; environmentId = $envId
    }
    if ($domains.domains.serviceDomains.Count -gt 0) {
        $domain = $domains.domains.serviceDomains[0].domain
    }
}

if ($domain) {
    Write-Host "   $domain" -ForegroundColor Green
    Write-Host ""
    Write-Host "10) API_PUBLIC_URL ve PUBLIC_WEB_URL yaziliyor..." -ForegroundColor Cyan
    $publicUrl = "https://$domain"
    foreach ($k in @("API_PUBLIC_URL", "PUBLIC_WEB_URL")) {
        Invoke-RailwayGql -Query "mutation(`$input: VariableUpsertInput!) { variableUpsert(input: `$input) }" -Variables @{
            input = @{
                projectId = $projectId; environmentId = $envId; serviceId = $apiId
                name = $k; value = $publicUrl
            }
        } | Out-Null
    }
    Write-Host "   OK" -ForegroundColor Green
} else {
    Write-Host "   Domain alinamadi, paneldan Generate Domain" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "11) Deploy tetikleniyor..." -ForegroundColor Cyan
try {
    Invoke-RailwayGql -Query "mutation(`$serviceId: String!, `$environmentId: String!) { serviceInstanceDeployV2(serviceId: `$serviceId, environmentId: `$environmentId) }" -Variables @{
        serviceId = $apiId; environmentId = $envId
    } | Out-Null
    Write-Host "   Deploy gonderildi" -ForegroundColor Green
} catch {
    Write-Host "   Uyari: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host "  TAMAM" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host "Project: https://railway.com/project/$projectId" -ForegroundColor Cyan
if ($domain) {
    Write-Host "API:     https://$domain/health" -ForegroundColor Cyan
    Write-Host "Tour:    https://$domain/tour/{slug}" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Mobil release build:" -ForegroundColor Yellow
    Write-Host "  --dart-define=API_BASE_URL=https://$domain" -ForegroundColor White
    Write-Host "  --dart-define=PUBLIC_WEB_URL=https://$domain" -ForegroundColor White
}
Write-Host ""
Write-Host "Loglar icin: https://railway.com/project/$projectId" -ForegroundColor DarkGray
