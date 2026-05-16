# Sanaltur — Mobil-Oncelikli Mimari

## Platform onceligi

| Platform | Rol | Oncelik |
|----------|-----|---------|
| **Flutter (iOS/Android)** | Oda cekimi, offline kuyruk, tur onizleme | Birincil |
| **NestJS API** | Auth, CRUD, presign upload, AI job queue | Cekirdek |
| **Python AI** | Siniflandirma, siralama, kat plani tahmini | Arka plan |
| **Next.js Web** | Public tur, dashboard, admin | Ikincil |

## Flutter klasor yapisi (feature-first + clean architecture)

```
apps/mobile/lib/
├── main.dart / app.dart
├── core/
│   ├── config/       # Env, API URL
│   ├── theme/
│   ├── router/       # GoRouter + auth redirect
│   ├── network/      # Dio + JWT interceptor
│   └── storage/      # Hive upload queue, SharedPreferences tokens
└── features/
    ├── auth/         # Login, register
    ├── home/         # Mulk listesi
    ├── properties/   # CRUD, oda yonetimi, AI aksiyonlar
    ├── capture/      # Kamera + galeri
    ├── upload/       # Offline-first medya kuyrugu
    └── tour/         # Swipe-onizleme (MVP)
```

## Mobil kullanici akisi

```
Giris → Ana Sayfa → Yeni Mulk
  → Oda Ekle (tip sec) → Kamera Cekimi
  → [Offline kuyruk] → Arka planda R2 upload
  → Oda Duzenle (AI tahmini + kullanici tipi)
  → AI: Siniflandir → Kat Plani → Sanal Tur → Yayinla
  → Paylasim linki kopyala
```

## Offline-first upload

1. Fotoğraf cekilir → yerel dosya + Hive `UploadTaskModel`
2. `connectivity_plus` online olunca kuyruk islenir
3. `POST /rooms/:id/media/presign` → R2 PUT → `POST confirm`
4. Basarisiz ise `retry` banner

Performans:

- `flutter_image_compress` — max 2560px, %82 kalite
- Presigned URL — dogrudan R2, API uzerinden dosya akmaz
- Tek seferde bir upload (MVP); paralel upload sonraki sprint

## API endpointleri (mobil)

| Method | Path | Aciklama |
|--------|------|----------|
| POST | `/auth/login` | JWT |
| POST | `/properties` | Mulk olustur |
| POST | `/properties/:id/rooms` | Oda ekle |
| POST | `/rooms/:id/media/presign` | Upload URL |
| POST | `/rooms/:id/media/confirm` | Medya kaydet |
| POST | `/properties/:id/analyze` | AI siniflandir + sira |
| POST | `/properties/:id/generate-floorplan` | Kat plani |
| POST | `/properties/:id/generate-tour` | Tur grafigi |
| POST | `/properties/:id/publish` | Public slug |
| GET | `/public/tours/:slug` | Auth yok |

## Gelistirme

```bash
# Emulator icin API (Android)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3001

# iOS simulator
flutter run --dart-define=API_BASE_URL=http://localhost:3001
```

## Gelecek (MVP disi)

- LiDAR / ARKit spatial capture
- Gercek panorama stitch
- Background isolate upload
- Push notification (AI job tamamlandi)
