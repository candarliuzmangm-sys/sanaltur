# Sanaltur Mobile

Birincil platform — emlak sanal tur cekim uygulamasi.

## Kurulum

```bash
flutter pub get
flutter run
```

## Ortam degiskenleri

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:3001 \
  --dart-define=PUBLIC_WEB_URL=http://localhost:3000
```

## Ozellikler (MVP)

- JWT auth
- Mulk ve oda yonetimi
- Kamera + galeri cekimi
- Offline upload kuyrugu (Hive)
- AI islemleri tetikleme
- Tur onizleme ve link paylasimi

Detay: [../../docs/MOBILE_ARCHITECTURE.md](../../docs/MOBILE_ARCHITECTURE.md)
