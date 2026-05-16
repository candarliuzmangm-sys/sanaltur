# Sanaltur — Production Deployment

## Canli Servisler

| Servis     | URL                                                |
|------------|----------------------------------------------------|
| API        | https://api-production-9e0f.up.railway.app         |
| Health     | https://api-production-9e0f.up.railway.app/health  |
| Swagger    | https://api-production-9e0f.up.railway.app/docs    |
| Tour viewer| https://api-production-9e0f.up.railway.app/tour/{slug} |
| Railway    | https://railway.com/project/e3225e37-a542-48ef-9e8e-377fd372e421 |

## Railway Kaynaklari

| ID                                                    | Tip         | Not                                  |
|-------------------------------------------------------|-------------|--------------------------------------|
| `e3225e37-a542-48ef-9e8e-377fd372e421`                | Project     | kind-gentleness                      |
| `cf6ca9ee-b42c-42a3-a2d7-1b69f4d55dd7`                | Environment | production                           |
| `0c33fe09-57ca-43ad-9849-509499c93167`                | Service     | api (Docker, root: apps/api)         |
| `65331af9-0262-4ec1-915f-f5deb2fede7f`                | Service     | Postgres (plugin)                    |
| `c7239230-649a-4941-8960-8aaba55963b9`                | Service     | Redis (plugin)                       |

## Mobil Release APK

```powershell
.\scripts\mobile-release.ps1
```

APK `apps\mobile\build\app\outputs\flutter-apk\app-release.apk`'da olusur.

## Yeni Commit Sonrasi Deploy

```powershell
git push                                  # GitHub'a gonder
.\scripts\railway-deploy-latest.ps1       # Railway'i tetikle
```

Script son commit'i Railway'e gonderir ve build durumunu canli izler.

## Ortam Degiskenleri (Railway -> api servisi)

| Ad                       | Deger                          |
|--------------------------|--------------------------------|
| NODE_ENV                 | production                     |
| PORT                     | 3001                           |
| JWT_SECRET               | (random 48 hex)                |
| JWT_EXPIRES_IN           | 15m                            |
| JWT_REFRESH_EXPIRES_IN   | 7d                             |
| DATABASE_URL             | `${{Postgres.DATABASE_URL}}`   |
| REDIS_URL                | `${{Redis.REDIS_URL}}`         |
| STORAGE_MODE             | local                          |
| AI_SERVICE_URL           | http://127.0.0.1:8000          |
| API_PUBLIC_URL           | https://api-production-9e0f.up.railway.app |
| PUBLIC_WEB_URL           | https://api-production-9e0f.up.railway.app |
| CORS_ORIGIN              | https://api-production-9e0f.up.railway.app |

## Notlar

- Public tour viewer api ile ayni domain'de sunulur (`/viewer.html`, `/tour/{slug}`)
- Storage `local` modda — production'da R2'ye gecmek icin `STORAGE_MODE=r2` + R2 keys
- Swagger UI: `/docs`
- Migration `npx prisma migrate deploy` Docker CMD'sinde otomatik kosulur
- Dockerfile `node:20-slim` (Debian) — Prisma OpenSSL 3.x ile uyumlu
