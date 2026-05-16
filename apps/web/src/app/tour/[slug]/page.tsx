import type { Metadata } from 'next';

import { fetchPublicTour } from '@/lib/api';
import { TourViewer } from '@/components/tour/TourViewer';

interface Props {
  params: { slug: string };
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  try {
    const tour = await fetchPublicTour(params.slug);
    return {
      title: `${tour.title} | Sanaltur`,
      description: tour.description ?? '360° sanal tur',
      openGraph: {
        title: tour.title,
        description: tour.description ?? '360° sanal tur',
        images: tour.coverImageUrl ? [tour.coverImageUrl] : undefined,
      },
    };
  } catch {
    return { title: 'Sanal tur | Sanaltur' };
  }
}

export default async function PublicTourPage({ params }: Props) {
  const tour = await fetchPublicTour(params.slug);

  return (
    <main>
      <TourViewer tour={tour} />
    </main>
  );
}
