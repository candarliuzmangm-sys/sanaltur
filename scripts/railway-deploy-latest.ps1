# Son commit'i Railway'e deploy eder.
#
# Kullanim:
#   git push                                 # GitHub'a gonder
#   .\scripts\railway-deploy-latest.ps1      # Railway'i tetikle

$ErrorActionPreference = "Stop"
$root          = Split-Path $PSScriptRoot -Parent
$tokenFile     = Join-Path $root "railway-token.txt"
$serviceId     = "0c33fe09-57ca-43ad-9849-509499c93167"
$environmentId = "cf6ca9ee-b42c-42a3-a2d7-1b69f4d55dd7"
$projectId     = "e3225e37-a542-48ef-9e8e-377fd372e421"
$endpoint      = "https://backboard.railway.com/graphql/v2"

$token = (Get-Content $tokenFile -Raw).Trim()
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
$sha = (git -C $root rev-parse HEAD).Trim()

Write-Host "Commit: $sha" -ForegroundColor Cyan

$body = @{
    query     = 'mutation($s: String!, $e: String!, $c: String) { serviceInstanceDeploy(serviceId: $s, environmentId: $e, commitSha: $c, latestCommit: true) }'
    variables = @{ s = $serviceId; e = $environmentId; c = $sha }
} | ConvertTo-Json -Depth 5 -Compress

$r = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $body
if ($r.errors) {
    Write-Host "HATA: $($r.errors | ConvertTo-Json -Depth 5)" -ForegroundColor Red
    exit 1
}
Write-Host "Deploy gonderildi." -ForegroundColor Green

Write-Host "Build izleniyor (her 15s)..." -ForegroundColor DarkGray
$statusBody = @{
    query     = 'query($p: String!, $e: String!, $s: String!) { deployments(first: 1, input: { projectId: $p, environmentId: $e, serviceId: $s }) { edges { node { id status } } } }'
    variables = @{ p = $projectId; e = $environmentId; s = $serviceId }
} | ConvertTo-Json -Depth 5 -Compress

for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 15
    $s = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $statusBody
    $node = $s.data.deployments.edges[0].node
    Write-Host "  [$([int]($i*15))s] $($node.status)"
    if ($node.status -eq "SUCCESS") {
        Write-Host "OK -> https://api-production-9e0f.up.railway.app/health" -ForegroundColor Green
        break
    }
    if ($node.status -in @("FAILED","CRASHED")) {
        Write-Host "FAIL. Loglar icin: https://railway.com/project/$projectId" -ForegroundColor Red
        exit 1
    }
}
