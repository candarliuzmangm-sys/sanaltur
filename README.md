# Sanaltur

AI destekli emlak sanal tur platformu — **mobil-oncelikli** MVP.

## Mimari

```
sanaltur/
├── apps/
│   ├── mobile/       # Flutter — BIRINCIL PLATFORM
│   ├── api/          # NestJS + Prisma + BullMQ
│   ├── ai-service/   # Python FastAPI
│   └── web/          # Next.js — dashboard + public tour
├── packages/shared/  # Ortak enum ve tipler
└── docs/
    ├── ARCHITECTURE.md
    └── MOBILE_ARCHITECTURE.md
```

## Hizli baslangic

### 1. Altyapi

```bash
docker compose up -d postgres redis
```

### 2. API

```bash
cd apps/api
cp .env.example .env
npm install
npx prisma migrate dev
npm run start:dev
```

### 3. AI servisi

```bash
cd apps/ai-service
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

### 4. Mobil (ana urun)

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3001
```

### 5. Web

```bash
cd apps/web
cp .env.example .env.local
npm install
npm run dev
```

## MVP E2E akis (ilk calisan dilim)

1. Giris yap
2. Mulk olustur → oda ekle
3. Fotograf cek → yukle
4. AI oda tipini tespit eder
5. Mulk detayinda medya + AI etiketi gorunur

**Detayli kurulum:** [docs/MVP_E2E.md](docs/MVP_E2E.md)

```powershell
.\scripts\setup-mvp.ps1
```

## Dokumantasyon

- [Genel mimari](docs/ARCHITECTURE.md)
- [Mobil mimari](docs/MOBILE_ARCHITECTURE.md)
- [Mobil README](apps/mobile/README.md)
