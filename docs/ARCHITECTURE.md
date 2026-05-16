# Sanaltur — Sistem Mimarisi

## Genel bakış

Sanaltur, emlakçıların akıll telefonla çektiği oda fotoğraflarından hafif sanal tur, tahmini kat planı ve paylaşılabilir vitrin sayfası üreten bir platformdur. MVP, Matterport seviyesi 3D rekonstrüksiyon hedeflemez; fotoğraf tabanlı oda geçişleri ve AI destekli sınıflandırma odaklıdır.

**Birincil platform: Flutter mobil uygulama.** Web yalnızca dashboard, public tur görüntüleme ve admin işlemleri içindir. Detay: [MOBILE_ARCHITECTURE.md](MOBILE_ARCHITECTURE.md)

```
┌─────────────┐     ┌─────────────┐
│ Flutter App │     │  Next.js    │
│  (capture)  │     │ (dashboard  │
│             │     │  + viewer)  │
└──────┬──────┘     └──────┬──────┘
       │                   │
       └─────────┬─────────┘
                 │ HTTPS / REST
                 ▼
         ┌───────────────┐
         │   NestJS API   │
         │  Prisma + JWT  │
         └───────┬───────┘
                 │
     ┌───────────┼───────────┐
     ▼           ▼           ▼
┌─────────┐ ┌─────────┐ ┌──────────────┐
│PostgreSQL│ │ Redis   │ │ Cloudflare R2│
│          │ │ BullMQ  │ │ (media)      │
└─────────┘ └────┬────┘ └──────────────┘
                 │
                 ▼
         ┌───────────────┐
         │ Python AI API  │
         │ classify       │
         │ floorplan est. │
         │ room ordering  │
         └───────────────┘
```

## Servis sorumlulukları

| Servis | Sorumluluk |
|--------|------------|
| **Flutter** | Oda yakalama, offline kuyruk, proje yönetimi |
| **NestJS** | Auth, CRUD, medya presign, iş kuyruğu, public slug |
| **AI (FastAPI)** | Oda sınıflandırma, sıralama, kat planı tahmini |
| **Next.js** | Agent dashboard, public 360°/panorama viewer |
| **R2** | Fotoğraf, video, kat planı SVG/PNG |

## Veri modeli (özet)

```
User ──< Property ──< Room ──< Media
                │
                ├── Floorplan (AI generated)
                └── Tour (ordered room graph + public slug)
```

## İş akışı (async)

1. `POST /properties` — proje oluştur
2. `POST /rooms/:id/media/presign` — R2 yükleme URL
3. `POST /rooms/:id/analyze` — BullMQ job → AI classify
4. `POST /properties/:id/generate-floorplan` — AI floorplan job
5. `POST /properties/:id/generate-tour` — room order + graph
6. `GET /public/tours/:slug` — auth gerektirmez

## Modüler yapı (feature-first)

NestJS her domain için ayrı modül:

- `auth` — JWT, refresh token
- `users`
- `properties`
- `rooms`
- `media` — R2 presigned upload
- `floorplans`
- `tours` — public slug, room graph
- `ai-jobs` — BullMQ processor, AI HTTP client

## Güvenlik

- JWT access (15m) + refresh (7d) cookie/header
- R2 presigned URL — kısa TTL (15 dk)
- Public tour — sadece `published` + slug
- Rate limit — Redis tabanlı (gelecek sprint)

## Ölçeklenebilirlik

- Stateless API → yatay ölçekleme
- BullMQ workers → ayrı process/pod
- AI servisi → GPU node pool (gelecek)
- CDN → R2 + Cloudflare edge

## Gelecek (MVP dışı)

- LiDAR / ARKit spatial capture
- Gerçek 3D mesh (NeRF / Gaussian Splatting)
- AI mobilya staging
- Otomatik sosyal medya video
