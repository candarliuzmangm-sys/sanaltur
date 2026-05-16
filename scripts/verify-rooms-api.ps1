# Oda + fotoğraf API smoke test
# Gereksinim: API http://localhost:3001, Postgres + migrate

$ErrorActionPreference = "Stop"
$base = "http://localhost:3001/api/v1"
$email = "test@agent.com"
$password = "password123"

Write-Host "1. Login..." -ForegroundColor Cyan
$login = Invoke-RestMethod -Method Post -Uri "$base/auth/login" `
  -ContentType "application/json" `
  -Body (@{ email = $email; password = $password } | ConvertTo-Json)
$token = $login.accessToken
if (-not $token) { throw "Token alinamadi" }
$headers = @{ Authorization = "Bearer $token" }
Write-Host "   OK" -ForegroundColor Green

Write-Host "2. Mulk olustur..." -ForegroundColor Cyan
$prop = Invoke-RestMethod -Method Post -Uri "$base/properties" `
  -Headers $headers -ContentType "application/json" `
  -Body (@{ title = "API Test $(Get-Date -Format 'HHmmss')" } | ConvertTo-Json)
$propertyId = $prop.id
Write-Host "   propertyId=$propertyId" -ForegroundColor Green

Write-Host "3. Oda olustur..." -ForegroundColor Cyan
$room = Invoke-RestMethod -Method Post -Uri "$base/properties/$propertyId/rooms" `
  -Headers $headers -ContentType "application/json" `
  -Body (@{ name = "Salon"; type = "LIVING_ROOM" } | ConvertTo-Json)
$roomId = $room.id
Write-Host "   roomId=$roomId coverPhoto=$($room.coverPhoto)" -ForegroundColor Green

Write-Host "4. Oda listesi..." -ForegroundColor Cyan
$rooms = Invoke-RestMethod -Method Get -Uri "$base/properties/$propertyId/rooms" `
  -Headers $headers
if ($rooms.Count -lt 1) { throw "Oda listesi bos" }
Write-Host "   $($rooms.Count) oda" -ForegroundColor Green

Write-Host "5. Oda detay..." -ForegroundColor Cyan
$detail = Invoke-RestMethod -Method Get -Uri "$base/properties/$propertyId/rooms/$roomId" `
  -Headers $headers
Write-Host "   photos=$($detail.photos.Count) roomType=$($detail.roomType)" -ForegroundColor Green

Write-Host ""
Write-Host "Tum kontroller gecti. Foto yukleme: POST /rooms/$roomId/media/upload (multipart file)" -ForegroundColor Green
