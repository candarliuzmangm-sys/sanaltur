export default function DashboardPage() {
  return (
    <main style={{ maxWidth: 960, margin: '0 auto', padding: '2rem 1.5rem' }}>
      <h1>Dashboard</h1>
      <p style={{ color: '#666', marginTop: '0.5rem' }}>
        Web dashboard MVP — mulk yonetimi mobil uygulama uzerinden yapilir.
        Burada yayinlanan turlari listeleyebilir ve paylasim linklerini
        kopyalayabilirsiniz.
      </p>
      <section
        style={{
          marginTop: '2rem',
          padding: '1.5rem',
          background: '#fff',
          borderRadius: 12,
          border: '1px solid #e5e5e5',
        }}
      >
        <h2 style={{ fontSize: '1rem', marginBottom: '0.5rem' }}>Mobil oncelikli akis</h2>
        <ol style={{ paddingLeft: '1.25rem', color: '#444' }}>
          <li>Flutter uygulamasindan mulk olustur</li>
          <li>Odaları fotografla</li>
          <li>AI siniflandirma ve kat plani uret</li>
          <li>Yayinla ve /tour/[slug] linkini paylas</li>
        </ol>
      </section>
    </main>
  );
}
