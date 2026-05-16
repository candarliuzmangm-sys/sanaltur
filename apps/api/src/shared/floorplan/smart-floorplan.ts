/** Smart floorplan generator — oda tiplerine göre gerçekçi grid + kapı çizgileri. */

export interface FloorplanInputRoom {
  id: string;
  name?: string;
  type: string;
}

export interface FloorplanLayoutRoom {
  id: string;
  name: string;
  type: string;
  x: number;
  y: number;
  width: number;
  height: number;
  doors?: Array<{ x: number; y: number; w: number; h: number }>;
}

export interface SmartFloorplanResult {
  svgContent: string;
  estimatedAreaSqm: number;
  rooms: FloorplanLayoutRoom[];
  width: number;
  height: number;
}

// Tipik gerçek boyutlar (metre cinsinden). 1 metre = 20 SVG birim ölçeği.
// Sahne 60x40 metre etrafında olacak şekilde merkez odaktan dağılır.
const M_PER_UNIT = 20;
const meters = (m: number) => Math.round(m * M_PER_UNIT);

interface RoomSpec {
  /** Tipik genişlik (m) x derinlik (m) */
  w: number;
  h: number;
  /** Salon merkezde kaldığında yerleştirme önceliği */
  priority: number;
  fill: string;
  stroke: string;
  short: string;
  label: string;
}

const SPECS: Record<string, RoomSpec> = {
  LIVING_ROOM: {
    w: 6,
    h: 4.5,
    priority: 0,
    fill: '#DCFCE7',
    stroke: '#16A34A',
    short: 'SLN',
    label: 'Salon',
  },
  DINING_ROOM: {
    w: 4,
    h: 3.5,
    priority: 5,
    fill: '#FEF3C7',
    stroke: '#D97706',
    short: 'YMK',
    label: 'Yemek',
  },
  KITCHEN: {
    w: 3.5,
    h: 3,
    priority: 1,
    fill: '#FED7AA',
    stroke: '#EA580C',
    short: 'MTF',
    label: 'Mutfak',
  },
  BEDROOM: {
    w: 4,
    h: 3.5,
    priority: 2,
    fill: '#DBEAFE',
    stroke: '#2563EB',
    short: 'YTK',
    label: 'Yatak Odası',
  },
  BATHROOM: {
    w: 2.5,
    h: 2,
    priority: 3,
    fill: '#E9D5FF',
    stroke: '#9333EA',
    short: 'WC',
    label: 'Banyo',
  },
  OFFICE: {
    w: 3,
    h: 3,
    priority: 6,
    fill: '#FEF9C3',
    stroke: '#CA8A04',
    short: 'OFS',
    label: 'Çalışma',
  },
  HALLWAY: {
    w: 5,
    h: 1.5,
    priority: 7,
    fill: '#F3F4F6',
    stroke: '#6B7280',
    short: 'KOR',
    label: 'Antre',
  },
  BALCONY: {
    w: 4,
    h: 1.5,
    priority: 8,
    fill: '#D1FAE5',
    stroke: '#059669',
    short: 'BLK',
    label: 'Balkon',
  },
  CLOSET: {
    w: 2,
    h: 1.5,
    priority: 4,
    fill: '#FCE7F3',
    stroke: '#DB2777',
    short: 'GYN',
    label: 'Giyinme',
  },
  LAUNDRY: {
    w: 2,
    h: 2,
    priority: 9,
    fill: '#E0E7FF',
    stroke: '#4F46E5',
    short: 'ÇMR',
    label: 'Çamaşır',
  },
  GARAGE: {
    w: 5,
    h: 4,
    priority: 10,
    fill: '#E5E7EB',
    stroke: '#4B5563',
    short: 'GRJ',
    label: 'Garaj',
  },
  OTHER: {
    w: 3,
    h: 3,
    priority: 11,
    fill: '#F3F4F6',
    stroke: '#6B7280',
    short: 'ODA',
    label: 'Oda',
  },
};

export function buildSmartFloorplan(
  rooms: FloorplanInputRoom[],
): SmartFloorplanResult {
  if (rooms.length === 0) {
    return emptyResult();
  }

  // 1) Sıralı listeye yerleştir — salon merkezde, diğerleri etrafta.
  const sorted = [...rooms].sort((a, b) => {
    const pa = SPECS[a.type]?.priority ?? 99;
    const pb = SPECS[b.type]?.priority ?? 99;
    return pa - pb;
  });

  const padding = meters(1);
  const placed: FloorplanLayoutRoom[] = [];

  // İlk önce salon, sonra "rows" mantığıyla yan yana ekleyelim.
  // Hedef: bina dikdörtgen, max 4 kolon, satır sığacak kadar.
  const targetMaxRowM = 14; // metre — bir satırda toplam genişlik
  let rowM = 0;
  let rowH = 0;
  let cursorX = padding;
  let cursorY = padding;
  let maxRowWidth = 0;

  for (const room of sorted) {
    const spec = SPECS[room.type] ?? SPECS.OTHER;
    const w = meters(spec.w);
    const h = meters(spec.h);
    if (rowM > 0 && rowM + spec.w > targetMaxRowM) {
      // satırı kapat
      cursorY += rowH;
      cursorX = padding;
      rowM = 0;
      rowH = 0;
    }
    placed.push({
      id: room.id,
      name: room.name ?? spec.label,
      type: room.type,
      x: cursorX,
      y: cursorY,
      width: w,
      height: h,
    });
    cursorX += w;
    rowM += spec.w;
    if (h > rowH) rowH = h;
    if (cursorX > maxRowWidth) maxRowWidth = cursorX;
  }

  const width = maxRowWidth + padding;
  const height = cursorY + rowH + padding;

  // Toplam alan (m²)
  const totalArea = placed.reduce(
    (sum, r) => sum + (r.width / M_PER_UNIT) * (r.height / M_PER_UNIT),
    0,
  );

  // Komşu odalar arasına kapı çizgileri ekle (basit kural: yatay komşu odalar).
  attachDoors(placed);

  const svgContent = renderSvg(placed, width, height);

  return {
    svgContent,
    estimatedAreaSqm: Math.round(totalArea * 10) / 10,
    rooms: placed,
    width,
    height,
  };
}

function attachDoors(rooms: FloorplanLayoutRoom[]) {
  for (let i = 0; i < rooms.length; i++) {
    const a = rooms[i]!;
    for (let j = i + 1; j < rooms.length; j++) {
      const b = rooms[j]!;
      // Aynı y'de ve yatay temas (kapı için)
      const sameRow = Math.abs(a.y - b.y) < 1;
      const touchHoriz =
        sameRow && Math.abs(a.x + a.width - b.x) < 1;
      const touchHorizRev =
        sameRow && Math.abs(b.x + b.width - a.x) < 1;
      if (touchHoriz || touchHorizRev) {
        const doorY = Math.min(a.y + a.height / 2 + 8, a.y + a.height - 14);
        const doorX = touchHoriz ? a.x + a.width - 2 : b.x + b.width - 2;
        const door = { x: doorX, y: doorY - 7, w: 4, h: 14 };
        a.doors = [...(a.doors ?? []), door];
        b.doors = [...(b.doors ?? []), door];
      }
    }
  }
}

function renderSvg(
  rooms: FloorplanLayoutRoom[],
  width: number,
  height: number,
): string {
  const padding = 12;
  const totalW = width + padding * 2;
  const totalH = height + padding * 2;

  const wallStroke = '#0F172A';
  const wallWidth = 3;

  const outerRect =
    `<rect x="${padding}" y="${padding}" width="${width}" height="${height}" ` +
    `fill="#F8FAFC" stroke="${wallStroke}" stroke-width="${wallWidth}" rx="6" />`;

  const roomShapes = rooms
    .map((r) => {
      const spec = SPECS[r.type] ?? SPECS.OTHER;
      const x = r.x + padding;
      const y = r.y + padding;
      const cx = x + r.width / 2;
      const cy = y + r.height / 2;
      const labelMain = escapeXml(r.name);
      const labelSub = `${spec.short}  ·  ${areaLabel(r)}`;
      const fontMain = Math.min(14, Math.max(9, r.width / 9));
      const fontSub = Math.min(10, Math.max(8, fontMain - 3));

      const doors = (r.doors ?? [])
        .map(
          (d) =>
            `<rect x="${d.x + padding}" y="${d.y + padding}" width="${d.w}" height="${d.h}" ` +
            `fill="#F8FAFC" stroke="${spec.stroke}" stroke-width="2" />`,
        )
        .join('');

      return (
        `<g>` +
        `<rect x="${x}" y="${y}" width="${r.width}" height="${r.height}" ` +
        `fill="${spec.fill}" stroke="${spec.stroke}" stroke-width="2" rx="3" />` +
        doors +
        `<text x="${cx}" y="${cy - 4}" text-anchor="middle" dominant-baseline="middle" ` +
        `font-family="Inter, system-ui, sans-serif" font-size="${fontMain}" ` +
        `fill="#0F172A" font-weight="700">${labelMain}</text>` +
        `<text x="${cx}" y="${cy + fontMain - 2}" text-anchor="middle" dominant-baseline="middle" ` +
        `font-family="Inter, system-ui, sans-serif" font-size="${fontSub}" ` +
        `fill="#475569">${labelSub}</text>` +
        `</g>`
      );
    })
    .join('');

  // Köşe/grid pattern (hafif noktalar)
  const dots: string[] = [];
  for (let x = padding; x <= padding + width; x += 20) {
    for (let y = padding; y <= padding + height; y += 20) {
      dots.push(
        `<circle cx="${x}" cy="${y}" r="0.6" fill="#CBD5E1" />`,
      );
    }
  }

  // Üst etiket: m² toplamı
  const totalArea = rooms.reduce(
    (s, r) => s + (r.width / M_PER_UNIT) * (r.height / M_PER_UNIT),
    0,
  );
  const headerY = padding - 2;
  const header =
    `<text x="${padding + 4}" y="${headerY}" font-family="Inter, system-ui, sans-serif" ` +
    `font-size="9" fill="#94A3B8">Kat Planı  ·  ~${Math.round(totalArea)} m²</text>`;

  return (
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${totalW} ${totalH}" ` +
    `width="${totalW}" height="${totalH}">` +
    `<rect width="100%" height="100%" fill="#FFFFFF" />` +
    dots.join('') +
    outerRect +
    roomShapes +
    header +
    `</svg>`
  );
}

function areaLabel(r: FloorplanLayoutRoom): string {
  const m2 = (r.width / M_PER_UNIT) * (r.height / M_PER_UNIT);
  return `${m2.toFixed(1)} m²`;
}

function emptyResult(): SmartFloorplanResult {
  return {
    svgContent:
      `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100" width="200" height="100">` +
      `<rect width="100%" height="100%" fill="#F8FAFC" />` +
      `<text x="100" y="50" text-anchor="middle" font-family="Inter" font-size="12" fill="#64748B">` +
      `Henüz oda yok</text></svg>`,
    estimatedAreaSqm: 0,
    rooms: [],
    width: 200,
    height: 100,
  };
}

function escapeXml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
