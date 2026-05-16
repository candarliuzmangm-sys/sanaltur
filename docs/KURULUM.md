# Sanaltur — Kurulum Ozeti

Bu makinede asagidaki yazilimlar kuruldu veya yapilandirildi.

## Kurulu programlar

| Program | Durum | Not |
|---------|--------|-----|
| Node.js 22 | Zaten vardi | API icin |
| Python 3.12 | Kuruldu | AI servisi (3.14 uyumsuz) |
| Docker Desktop 4.73 | Kuruldu | Postgres + Redis |
| Flutter 3.41 (stable) | `C:\flutter` | PATH'e eklendi |
| Git | Zaten vardi | Flutter klonu icin |

## Ilk calistirma

### 1. Docker Desktop

Gorev cubugundan **Docker Desktop** acik olmali (balina ikonu yesil).

### 2. Veritabani

Yeni PowerShell:

```powershell
cd d:\sanaltur
docker compose up -d postgres redis
cd apps\api
npx prisma migrate deploy
```

### 3. Servisler (3 ayri terminal)

```powershell
# API
cd d:\sanaltur\apps\api
npm run start:dev

# AI
cd d:\sanaltur\apps\ai-service
.\.venv\Scripts\uvicorn app.main:app --reload --port 8000

# Mobil — Windows masaustu (en kolay test)
cd d:\sanaltur\apps\mobile
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3001
```

Android emulator icin:

```powershell
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:3001
```

### 4. Yeni terminal acin

Flutter ve Docker PATH degisiklikleri icin **Cursor/terminali kapatip yeniden acin** veya:

```powershell
$env:Path += ";C:\flutter\bin"
```

## Test hesabi

Uygulamada **Kayit ol** ile yeni hesap olusturun.

## Sorun giderme

- **docker: pipe bulunamadi** → Docker Desktop'i acin, 1-2 dk bekleyin
- **flutter taninmiyor** → Terminali yeniden acin veya `C:\flutter\bin` PATH'te mi kontrol edin
- **Gorsel gorunmuyor (Android)** → `apps/api/.env` icinde `API_PUBLIC_URL=http://10.0.2.2:3001`
