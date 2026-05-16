'use client';

import React, { useCallback, useMemo, useState } from 'react';
import dynamic from 'next/dynamic';

import { resolvePublicMediaUrl, type PublicTour } from '@/lib/api';
import './tour.css';

const MarzipanoPanorama = dynamic(
  () => import('./MarzipanoPanorama').then((m) => m.MarzipanoPanorama),
  {
    ssr: false,
    loading: () =>
      React.createElement(['d', 'i', 'v'].join('') as 'div', {
        className: 'tour-panorama',
        style: { background: '#111' },
      }),
  },
);

interface Props {
  tour: PublicTour;
}

export function TourViewer({ tour }: Props) {
  const sorted = useMemo(
    () => [...tour.rooms].sort((a, b) => a.order - b.order),
    [tour.rooms],
  );

  const startId =
    tour.startRoomId && sorted.some((r) => r.id === tour.startRoomId)
      ? tour.startRoomId
      : sorted[0]?.id;

  const [currentId, setCurrentId] = useState(startId ?? '');
  const current = sorted.find((r) => r.id === currentId) ?? sorted[0];

  const goToRoom = useCallback((roomId: string) => {
    setCurrentId(roomId);
  }, []);

  const panoramaUrl = current?.panoramaUrl
    ? resolvePublicMediaUrl(current.panoramaUrl)
    : undefined;

  const copyShare = async () => {
    const url = tour.shareUrl ?? window.location.href;
    try {
      await navigator.clipboard.writeText(url);
      alert('Tur linki kopyalandı');
    } catch {
      prompt('Tur linki:', url);
    }
  };

  if (!current) {
    return (
      <div className="tour-shell">
        <div className="tour-empty">Bu turda görüntülenecek oda yok.</div>
      </div>
    );
  }

  return (
    <div className="tour-shell">
      <header className="tour-header">
        <div>
          <h1>{tour.title}</h1>
          {tour.description && <p>{tour.description}</p>}
        </div>
        <div className="tour-header__actions">
          {tour.floorplanUrl && (
            <a
              className="tour-btn"
              href={resolvePublicMediaUrl(tour.floorplanUrl)}
              target="_blank"
              rel="noreferrer"
            >
              Kat planı
            </a>
          )}
          <button type="button" className="tour-btn tour-btn--primary" onClick={copyShare}>
            Paylaş
          </button>
        </div>
      </header>

      <div className="tour-stage">
        {panoramaUrl ? (
          <MarzipanoPanorama
            key={current.id}
            imageUrl={panoramaUrl}
            hotspots={current.hotspots ?? []}
            onHotspotClick={goToRoom}
          />
        ) : (
          <div className="tour-empty">Bu oda için panorama görseli yok.</div>
        )}
      </div>

      <footer className="tour-footer">
        <div className="tour-rooms">
          {sorted.map((room) => (
            <button
              key={room.id}
              type="button"
              className={`tour-room-chip${room.id === current.id ? ' tour-room-chip--active' : ''}`}
              onClick={() => goToRoom(room.id)}
            >
              {room.name}
            </button>
          ))}
        </div>
        <p className="tour-hint">
          Panoramada yeşil noktalara dokunarak odalar arası geçiş yapın · sürükleyerek
          etrafa bakın
        </p>
      </footer>
    </div>
  );
}
