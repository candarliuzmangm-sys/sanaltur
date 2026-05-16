# GitHub'a ilk push
# Kullanim:
#   .\scripts\github-push.ps1 -RepoUrl "https://github.com/KULLANICI/sanaltur.git"

param(
    [Parameter(Mandatory = $true)]
    [string]$RepoUrl
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Test-Path .git)) {
    Write-Host "Git repo yok. Once commit gerekli." -ForegroundColor Red
    exit 1
}

git branch -M main 2>$null

$remote = git remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0) {
    git remote add origin $RepoUrl
} else {
    git remote set-url origin $RepoUrl
}

Write-Host "Push: $RepoUrl" -ForegroundColor Cyan
git push -u origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "GitHub tamam. Simdi Railway:" -ForegroundColor Green
    Write-Host "  New Project -> Deploy from GitHub repo -> sanaltur" -ForegroundColor White
    Write-Host "  API servisi -> Settings -> Root Directory: apps/api" -ForegroundColor White
    Write-Host "  + PostgreSQL, + Redis, Variables bagla" -ForegroundColor White
}
