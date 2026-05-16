import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Sanaltur',
  description: 'AI-powered real estate virtual tours',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="tr">
      <body>{children}</body>
    </html>
  );
}
