import { fetchPublicProperty, resolvePublicMediaUrl, roomTypeLabel } from '@/lib/api';

interface Props {
  params: { slug: string };
}

export const dynamic = 'force-dynamic';

export async function generateMetadata({ params }: Props) {
  try {
    const p = await fetchPublicProperty(params.slug);
    return {
      title: `${p.title} — Sanaltur`,
      description: p.description ?? p.address ?? 'Emlak sanal turu',
      openGraph: {
        title: p.title,
        description: p.description ?? p.address ?? '',
        images: p.coverImageUrl ? [{ url: p.coverImageUrl }] : [],
      },
    };
  } catch {
    return { title: 'Mülk bulunamadı' };
  }
}

export default async function PublicPropertyPage({ params }: Props) {
  let property;
  try {
    property = await fetchPublicProperty(params.slug);
  } catch {
    return (
      <main style={{ padding: '4rem 1.5rem', textAlign: 'center' }}>
        <h1>Mülk bulunamadı</h1>
        <p style={{ color: '#666' }}>
          Bu bağlantı geçersiz veya mülk henüz yayında değil.
        </p>
      </main>
    );
  }

  const totalMedia = property.rooms.reduce(
    (sum, r) => sum + r.media.length,
    0,
  );

  return (
    <main
      style={{
        maxWidth: 960,
        margin: '0 auto',
        padding: '2rem 1.5rem 4rem',
        fontFamily: 'system-ui, sans-serif',
      }}
    >
      <header style={{ marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '2rem', margin: 0 }}>{property.title}</h1>
        {property.address && (
          <p style={{ color: '#666', marginTop: 4 }}>{property.address}</p>
        )}
        <p style={{ color: '#888', marginTop: 12, fontSize: 14 }}>
          {property.rooms.length} oda · {totalMedia} fotoğraf
        </p>
        {property.tourSlug && (
          <p style={{ marginTop: 16 }}>
            <a
              href={`/tour/${property.tourSlug}`}
              style={{
                display: 'inline-block',
                padding: '12px 20px',
                background: '#1B4D3E',
                color: '#fff',
                borderRadius: 10,
                fontWeight: 600,
                textDecoration: 'none',
              }}
            >
              360° Sanal turu başlat
            </a>
          </p>
        )}
        {property.description && (
          <p style={{ marginTop: 16, lineHeight: 1.6 }}>{property.description}</p>
        )}
      </header>

      {property.coverImageUrl && (
        <div
          style={{
            position: 'relative',
            width: '100%',
            aspectRatio: '16 / 9',
            borderRadius: 12,
            overflow: 'hidden',
            marginBottom: '2rem',
            background: '#eee',
          }}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={resolvePublicMediaUrl(property.coverImageUrl)}
            alt={property.title}
            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
          />
        </div>
      )}

      {property.rooms.map((room) => (
        <section key={room.id} style={{ marginBottom: '2.5rem' }}>
          <h2 style={{ fontSize: '1.25rem', marginBottom: 4 }}>{room.name}</h2>
          <p style={{ color: '#888', fontSize: 13, marginBottom: 12 }}>
            {roomTypeLabel(room.type)} · {room.media.length} foto
          </p>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))',
              gap: 12,
            }}
          >
            {room.media.map((media) => (
              <a
                key={media.id}
                href={media.url}
                target="_blank"
                rel="noreferrer"
                style={{
                  display: 'block',
                  position: 'relative',
                  aspectRatio: '4 / 3',
                  background: '#eee',
                  borderRadius: 8,
                  overflow: 'hidden',
                }}
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={resolvePublicMediaUrl(media.url)}
                  alt={room.name}
                  loading="lazy"
                  style={{
                    width: '100%',
                    height: '100%',
                    objectFit: 'cover',
                  }}
                />
              </a>
            ))}
          </div>
        </section>
      ))}

      <footer
        style={{
          marginTop: '3rem',
          paddingTop: '1.5rem',
          borderTop: '1px solid #eee',
          color: '#999',
          fontSize: 13,
          textAlign: 'center',
        }}
      >
        Sanaltur ile üretilmiştir
      </footer>
    </main>
  );
}
