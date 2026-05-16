# MVP E2E Akis — Calistirma Kilavuzu

## Akis

1. Mobil uygulama ac
2. Kayit ol / giris yap
3. Mulk olustur
4. Oda ekle (tip sec)
5. Fotograf cek
6. Yerel sikistirma + multipart upload
7. API medya kaydeder + AI siniflandirir
8. Mulk detayinda medya + AI tipi gorunur

## 1. Altyapi

```bash
docker compose up -d postgres redis
```

## 2. API

```bash
cd apps/api
cp .env.example .env
npm install
npx prisma migrate deploy
npx prisma generate
npm run start:dev
```

`.env` onemli degerler:

```
STORAGE_MODE=local
API_PUBLIC_URL=http://10.0.2.2:3001   # Android emulator icin
AI_SERVICE_URL=http://localhost:8000
```

## 3. AI servisi

```bash
cd apps/ai-service
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

## 4. Flutter

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3001
```

iOS simulator: `API_BASE_URL=http://localhost:3001`

Fiziksel cihaz: bilgisayarinizin LAN IP'si, orn. `http://192.168.1.10:3001`

## Test

1. Register: test@agent.com / password123 / Test Agent
2. Yeni Mulk olustur
3. Oda Ekle → Salon
4. Fotograf cek → Yukle
5. Mulk detayina don → AI etiketi + gorsel gorunmeli

## Sorun giderme

| Sorun | Cozum |
|-------|-------|
| Gorsel yuklenmiyor | API calisiyor mu? `API_PUBLIC_URL` emulator IP ile eslesmeli |
| AI tipi yok | AI servisi calisiyor mu? Fallback: kullanici tipi kullanilir |
| 401 hata | Tekrar giris yap |
| Kamera acilmiyor | Galeriden sec veya izinleri kontrol et |
