import Link from 'next/link';

export default function HomePage() {
  return (
    <main style={{ maxWidth: 720, margin: '0 auto', padding: '4rem 1.5rem' }}>
      <h1 style={{ fontSize: '2.5rem', marginBottom: '0.5rem' }}>Sanaltur</h1>
      <p style={{ color: '#666', marginBottom: '2rem' }}>
        Emlak sanal tur platformu — mobil uygulama ile çekim, web ile paylaşım.
      </p>
      <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap' }}>
        <Link
          href="/dashboard"
          style={{
            padding: '0.75rem 1.5rem',
            background: 'var(--primary)',
            color: '#fff',
            borderRadius: 8,
            textDecoration: 'none',
          }}
        >
          Dashboard
        </Link>
        <span style={{ color: '#999', alignSelf: 'center' }}>
          Public tur: /tour/[slug]
        </span>
      </div>
    </main>
  );
}
