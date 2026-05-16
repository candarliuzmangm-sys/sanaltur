# Sanaltur MVP setup script (Windows PowerShell)

Write-Host "Starting Postgres + Redis..."
docker compose -f "$PSScriptRoot\..\docker-compose.yml" up -d postgres redis

Write-Host "Installing API dependencies..."
Push-Location "$PSScriptRoot\..\apps\api"
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
npm install
npx prisma migrate deploy
npx prisma generate
Pop-Location

Write-Host "AI service: create venv and install (manual if python missing)"
Push-Location "$PSScriptRoot\..\apps\ai-service"
if (Get-Command python -ErrorAction SilentlyContinue) {
  python -m venv .venv
  .\.venv\Scripts\pip install -r requirements.txt
}
Pop-Location

Write-Host "Flutter: run flutter create if android/ incomplete"
Push-Location "$PSScriptRoot\..\apps\mobile"
if (Get-Command flutter -ErrorAction SilentlyContinue) {
  flutter pub get
  if (-not (Test-Path android\settings.gradle)) {
    flutter create . --org com.sanaltur --project-name sanaltur
  }
} else {
  Write-Host "Flutter not in PATH. Install Flutter SDK then: flutter pub get"
}
Pop-Location

Write-Host ""
Write-Host "Done. Start services in separate terminals:"
Write-Host "  cd apps/api && npm run start:dev"
Write-Host "  cd apps/ai-service && .venv\Scripts\uvicorn app.main:app --reload --port 8000"
Write-Host "  cd apps/mobile && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3001"
