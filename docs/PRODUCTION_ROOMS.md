# Property → Room → Photos (Production)

## Mimari

```
Flutter (Riverpod + Repository)
    ↓ HTTPS multipart / JSON
NestJS API (apps/api) — ana üretim API
    ↓ Prisma
PostgreSQL

FastAPI (apps/ai-service) — yalnızca AI (sınıflandırma, kat planı, tur)
```

> **Not:** Oda CRUD ve fotoğraf yükleme **NestJS** üzerindedir. FastAPI AI işleri için kullanılır; aynı PostgreSQL veritabanını paylaşmaz (ayrı servis).

## Veri modeli (PostgreSQL)

| Alan | Room | Media |
|------|------|-------|
| id | UUID | UUID |
| name | ✓ | — |
| roomType | `type` enum | — |
| coverPhoto | `coverPhotoUrl` | ilk foto otomatik |
| createdAt | ✓ | ✓ |
| photos | ilişki `media[]` | url, mimeType |

## API endpoint'leri

Tümü `Authorization: Bearer <token>` gerektirir. Prefix: `/api/v1`

| Method | Path | Açıklama |
|--------|------|----------|
| GET | `/properties/:propertyId/rooms` | Oda listesi + photos |
| GET | `/properties/:propertyId/rooms/:roomId` | Oda detayı |
| POST | `/properties/:propertyId/rooms` | Oda oluştur |
| PATCH | `/properties/:propertyId/rooms/:roomId` | Güncelle (coverPhotoUrl dahil) |
| POST | `/properties/:propertyId/rooms/reorder` | Sıra `{ roomIds: [] }` |
| DELETE | `/properties/:propertyId/rooms/:roomId` | Oda sil |
| POST | `/rooms/:roomId/media/upload` | Multipart `file` |
| DELETE | `/rooms/:roomId/media/:mediaId` | Fotoğraf sil |

Swagger: `http://localhost:3001/docs`

## Migrasyon

```bash
cd apps/api
npx prisma migrate deploy
npx prisma generate
```

## Doğrulama

```powershell
.\scripts\verify-rooms-api.ps1
```

## Flutter

- `features/rooms/data/repositories/room_repository.dart` — API katmanı
- `features/rooms/presentation/pages/room_detail_page.dart` — oda + fotoğraf grid
- Fotoğraf: kamera (`/capture/:roomId`) veya galeri (doğrudan API upload)
- `core/presentation/async_state_view.dart` — loading / error
