/**
 * Smart Floorplan v2 — Giriş kapısından başlayan zonelu yerleşim.
 *
 * Algoritma:
 *   - Daireyi 3 yatay banda böler: PUBLIC (üst) / CORRIDOR (orta) / PRIVATE (alt)
 *   - Üst bant soldan sağa: ANTRE → SALON → YEMEK → MUTFAK (eve girişinden gözlem)
 *   - Orta bant: koridor + misafir WC
 *   - Alt bant: YATAK ODALARI yan yana, en büyük YATAK yanına BANYO,
 *               sonra ÇALIŞMA / GİYİNME / DİĞER
 *   - Balkon ve garaj: dış cephe (üst veya alt duvara dışa doğru yapışır)
 *   - Giriş kapısı: Antrenin dış kenarında (çift çizgi)
 *   - İç kapılar: oda komşuluğuna göre otomatik (yay sembolü ile)
 */

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
}

export interface SmartFloorplanResult {
  svgContent: string;
  estimatedAreaSqm: number;
  rooms: FloorplanLayoutRoom[];
  width: number;
  height: number;
}

// ----- Scale -----
// 1 metre = 24 SVG birim (eski 20'den biraz büyük, etiketler okunsun)
const M = 24;
const m = (x: number) => Math.round(x * M);

interface Spec {
  /** Tipik genişlik (m) */
  w: number;
  /** Tipik derinlik (m) */
  h: number;
  fill: string;
  stroke: string;
  short: string;
  label: string;
}

const SPECS: Record<string, Spec> = {
  HALLWAY:     { w: 2.5, h: 3.0, fill: '#E5E7EB', stroke: '#475569', short: 'ANT', label: 'Antre' },
  LIVING_ROOM: { w: 5.5, h: 4.5, fill: '#DCFCE7', stroke: '#16A34A', short: 'SLN', label: 'Salon' },
  DINING_ROOM: { w: 3.5, h: 3.0, fill: '#FEF3C7', stroke: '#D97706', short: 'YMK', label: 'Yemek' },
  KITCHEN:     { w: 3.5, h: 3.0, fill: '#FED7AA', stroke: '#EA580C', short: 'MTF', label: 'Mutfak' },
  BEDROOM:     { w: 3.8, h: 3.8, fill: '#DBEAFE', stroke: '#2563EB', short: 'YTK', label: 'Yatak Odası' },
  BATHROOM:    { w: 2.2, h: 2.0, fill: '#E9D5FF', stroke: '#9333EA', short: 'WC',  label: 'Banyo' },
  OFFICE:      { w: 3.0, h: 3.0, fill: '#FEF9C3', stroke: '#CA8A04', short: 'OFS', label: 'Çalışma' },
  CLOSET:      { w: 1.8, h: 1.8, fill: '#FCE7F3', stroke: '#DB2777', short: 'GYN', label: 'Giyinme' },
  LAUNDRY:     { w: 1.8, h: 2.0, fill: '#E0E7FF', stroke: '#4F46E5', short: 'ÇMR', label: 'Çamaşır' },
  BALCONY:     { w: 4.0, h: 1.4, fill: '#D1FAE5', stroke: '#059669', short: 'BLK', label: 'Balkon' },
  GARAGE:      { w: 5.0, h: 5.0, fill: '#E5E7EB', stroke: '#4B5563', short: 'GRJ', label: 'Garaj' },
  OTHER:       { w: 3.0, h: 3.0, fill: '#F3F4F6', stroke: '#6B7280', short: 'ODA', label: 'Oda' },
};

const PUBLIC_ORDER = ['HALLWAY', 'LIVING_ROOM', 'DINING_ROOM', 'KITCHEN'];
const PRIVATE_ORDER = ['BEDROOM', 'BATHROOM', 'OFFICE', 'CLOSET', 'LAUNDRY', 'OTHER'];

interface Cell {
  room: FloorplanInputRoom;
  spec: Spec;
  x: number;
  y: number;
  w: number;
  h: number;
}

interface DoorLine {
  x1: number;
  y1: number;
  x2: number;
  y2: number;
  /** Yay yönü: kapı 90° hangi yana açılır */
  arc: 'NE' | 'NW' | 'SE' | 'SW';
}

export function buildSmartFloorplan(
  rooms: FloorplanInputRoom[],
): SmartFloorplanResult {
  if (rooms.length === 0) return emptyResult();

  // Tipi normalize et
  const items = rooms.map((r) => ({
    ...r,
    type: SPECS[r.type] ? r.type : 'OTHER',
  }));

  // Tip bazlı bölge
  const publicItems = items.filter((r) => PUBLIC_ORDER.includes(r.type));
  const privateItems = items.filter((r) =>
    PRIVATE_ORDER.includes(r.type),
  );
  const outerBalcony = items.filter((r) => r.type === 'BALCONY');
  const outerGarage = items.filter((r) => r.type === 'GARAGE');

  // Antre yoksa otomatik bir tane ekle (giriş kapısı için referans)
  const hasHallway = publicItems.some((r) => r.type === 'HALLWAY');
  let synthHallway: FloorplanInputRoom | null = null;
  if (!hasHallway) {
    synthHallway = { id: '__synth_hallway__', type: 'HALLWAY', name: 'Antre' };
    publicItems.unshift(synthHallway);
  }

  // Public bantı yerleştir (soldan sağa: ANTRE → SALON → YEMEK → MUTFAK)
  publicItems.sort(
    (a, b) =>
      PUBLIC_ORDER.indexOf(a.type) - PUBLIC_ORDER.indexOf(b.type),
  );
  const publicCells = packBand(publicItems, 0, 0);

  // Public bant ölçüleri
  const publicWidthM = publicCells.reduce(
    (s, c) => Math.max(s, c.x + c.w),
    0,
  );
  const publicHeightM = publicCells.reduce(
    (s, c) => Math.max(s, c.h),
    0,
  );

  // Private bantı yerleştir (BEDROOM grupları + BATH + OFFICE + CLOSET + LAUNDRY)
  privateItems.sort(
    (a, b) =>
      PRIVATE_ORDER.indexOf(a.type) - PRIVATE_ORDER.indexOf(b.type),
  );

  // Akıllı: her yatak odasından sonra varsa banyo onun yanına gelsin
  const arranged: FloorplanInputRoom[] = [];
  const bathQueue = privateItems
    .filter((r) => r.type === 'BATHROOM')
    .slice();
  const bedrooms = privateItems.filter((r) => r.type === 'BEDROOM');
  const others = privateItems.filter(
    (r) => r.type !== 'BATHROOM' && r.type !== 'BEDROOM',
  );
  for (const bed of bedrooms) {
    arranged.push(bed);
    if (bathQueue.length > 0) arranged.push(bathQueue.shift()!);
  }
  // Kalan banyolar ve diğer odalar
  arranged.push(...bathQueue, ...others);

  // Orta bant yüksekliği (koridor)
  const corridorHM = 1.4;
  const privateY = publicHeightM + corridorHM;

  const privateCells = packBand(arranged, 0, privateY);
  const privateWidthM = privateCells.reduce(
    (s, c) => Math.max(s, c.x + c.w),
    0,
  );
  const privateHeightM = privateCells.reduce(
    (s, c) => Math.max(s, c.y + c.h - privateY),
    0,
  );

  // Genel daire boyutu
  const interiorW = Math.max(publicWidthM, privateWidthM);
  const interiorH = publicHeightM + corridorHM + privateHeightM;

  // Public bantın "salon"u eksik kalan boş alanı doldursun (sağa genişlet)
  expandPublicLiving(publicCells, interiorW);
  // Private bantın son odası da kalan alanı doldursun
  expandPrivateLast(privateCells, interiorW);

  // Tüm hücreleri birleştir
  const allCells: Cell[] = [...publicCells, ...privateCells];

  // Koridor (orta bant)
  const corridor: Cell = {
    room: {
      id: '__corridor__',
      type: 'OTHER',
      name: 'Koridor',
    },
    spec: { ...SPECS.OTHER, label: 'Koridor', short: 'KOR', fill: '#F8FAFC' },
    x: 0,
    y: publicHeightM,
    w: interiorW,
    h: corridorHM,
  };

  // Balkonlar: salonun üst kenarına dışa doğru yapıştır
  const balconyCells: Cell[] = [];
  const livingCell = publicCells.find((c) => c.room.type === 'LIVING_ROOM');
  if (livingCell && outerBalcony.length > 0) {
    let bx = livingCell.x;
    for (const b of outerBalcony) {
      const spec = SPECS[b.type];
      const bw = Math.min(spec.w, livingCell.w);
      balconyCells.push({
        room: b,
        spec,
        x: bx,
        y: -spec.h - 0.05, // dışa
        w: bw,
        h: spec.h,
      });
      bx += bw;
    }
  } else if (outerBalcony.length > 0) {
    // Salon yoksa antre üstüne
    let bx = 0;
    for (const b of outerBalcony) {
      const spec = SPECS[b.type];
      balconyCells.push({
        room: b,
        spec,
        x: bx,
        y: -spec.h - 0.05,
        w: spec.w,
        h: spec.h,
      });
      bx += spec.w;
    }
  }

  // Garaj: alt cepheye dışa doğru
  const garageCells: Cell[] = [];
  let gx = 0;
  for (const g of outerGarage) {
    const spec = SPECS[g.type];
    garageCells.push({
      room: g,
      spec,
      x: gx,
      y: interiorH + 0.05,
      w: spec.w,
      h: spec.h,
    });
    gx += spec.w;
  }

  // Tüm cell'ler render için
  const allForRender = [
    corridor,
    ...allCells,
    ...balconyCells,
    ...garageCells,
  ];

  // Layout output (synth hallway hariç)
  const layoutRooms: FloorplanLayoutRoom[] = allCells
    .concat(balconyCells, garageCells)
    .filter((c) => !c.room.id.startsWith('__'))
    .map((c) => ({
      id: c.room.id,
      name: c.room.name ?? c.spec.label,
      type: c.room.type,
      x: m(c.x),
      y: m(c.y - (balconyCells.length > 0 ? -1.5 : 0)),
      width: m(c.w),
      height: m(c.h),
    }));

  // Toplam iç alan (m²) — balkon ve garaj hariç
  const totalAreaM2 = allCells.reduce(
    (s, c) => s + (c.room.id.startsWith('__') ? 0 : c.w * c.h),
    0,
  );

  // Kapıları hesapla
  const doors = computeDoors(publicCells, privateCells, corridor, balconyCells);

  // Giriş kapısı (Antre dış kenarında, üst duvar)
  const hallway = publicCells.find((c) => c.room.type === 'HALLWAY');
  const entranceDoor = hallway
    ? {
        x1: hallway.x + 0.3,
        y1: 0,
        x2: hallway.x + 0.3 + 0.9,
        y2: 0,
        arc: 'SE' as const,
        entrance: true,
      }
    : null;

  // SVG render
  const svgContent = renderSvg({
    cells: allForRender,
    doors,
    entranceDoor,
    interiorW,
    interiorH,
    balconyCells,
    garageCells,
    totalAreaM2,
  });

  return {
    svgContent,
    estimatedAreaSqm: Math.round(totalAreaM2 * 10) / 10,
    rooms: layoutRooms,
    width: m(interiorW),
    height: m(interiorH),
  };
}

/**
 * Soldan sağa packing: her odayı kendi tipik genişliğinde yerleştirir,
 * derinlik (h) bantın maks derinliğine eşitlenir.
 */
function packBand(
  items: FloorplanInputRoom[],
  startX: number,
  startY: number,
): Cell[] {
  const cells: Cell[] = [];
  let cx = startX;
  let maxH = 0;
  for (const r of items) {
    const spec = SPECS[r.type]!;
    const cell: Cell = {
      room: r,
      spec,
      x: cx,
      y: startY,
      w: spec.w,
      h: spec.h,
    };
    cells.push(cell);
    cx += spec.w;
    if (spec.h > maxH) maxH = spec.h;
  }
  for (const c of cells) c.h = maxH;
  return cells;
}

function expandPublicLiving(cells: Cell[], targetW: number) {
  const total = cells.reduce((s, c) => s + c.w, 0);
  if (total >= targetW) return;
  const slack = targetW - total;
  const living = cells.find((c) => c.room.type === 'LIVING_ROOM');
  if (!living) return;
  living.w += slack;
  // Sonraki hücreleri kaydır
  let cx = 0;
  for (const c of cells) {
    c.x = cx;
    cx += c.w;
  }
}

function expandPrivateLast(cells: Cell[], targetW: number) {
  const total = cells.reduce((s, c) => s + c.w, 0);
  if (total >= targetW || cells.length === 0) return;
  const slack = targetW - total;
  // Tercihen son yatak odasını genişlet, yoksa en sonu
  let target =
    [...cells].reverse().find((c) => c.room.type === 'BEDROOM') ??
    cells[cells.length - 1]!;
  target.w += slack;
  let cx = 0;
  for (const c of cells) {
    c.x = cx;
    cx += c.w;
  }
}

interface ComputedDoor {
  x1: number;
  y1: number;
  x2: number;
  y2: number;
  arc: 'NE' | 'NW' | 'SE' | 'SW';
  entrance?: boolean;
}

function computeDoors(
  publicCells: Cell[],
  privateCells: Cell[],
  corridor: Cell,
  balconyCells: Cell[],
): ComputedDoor[] {
  const doors: ComputedDoor[] = [];
  const doorWidth = 0.9; // m

  // Public bantta yatay komşular arasında kapı
  for (let i = 0; i < publicCells.length - 1; i++) {
    const a = publicCells[i]!;
    const b = publicCells[i + 1]!;
    // Banyo ve giyinme dışındaki public komşular için kapı
    const wallX = b.x;
    const doorY = a.y + a.h * 0.55;
    doors.push({
      x1: wallX,
      y1: doorY - doorWidth / 2,
      x2: wallX,
      y2: doorY + doorWidth / 2,
      arc: 'NE',
    });
  }

  // Public bant ↔ Koridor (büyük açıklık — salon ile)
  const living = publicCells.find((c) => c.room.type === 'LIVING_ROOM');
  if (living) {
    const wallY = corridor.y;
    const opening = Math.min(2.0, living.w * 0.4);
    const cx = living.x + living.w / 2;
    doors.push({
      x1: cx - opening / 2,
      y1: wallY,
      x2: cx + opening / 2,
      y2: wallY,
      arc: 'SE',
    });
  } else {
    // Antre yoksa public bantın ortasına bir açıklık
    const hallway = publicCells.find((c) => c.room.type === 'HALLWAY');
    if (hallway) {
      doors.push({
        x1: hallway.x + hallway.w * 0.3,
        y1: corridor.y,
        x2: hallway.x + hallway.w * 0.3 + doorWidth,
        y2: corridor.y,
        arc: 'SE',
      });
    }
  }

  // Koridor ↔ Private (her oda için bir kapı)
  for (const p of privateCells) {
    const wallY = p.y; // koridor alt kenarı = p.y
    const cx = p.x + p.w / 2;
    doors.push({
      x1: cx - doorWidth / 2,
      y1: wallY,
      x2: cx + doorWidth / 2,
      y2: wallY,
      arc: 'NW',
    });
  }

  // Private bantta YATAK ↔ BANYO (yan yana ise)
  for (let i = 0; i < privateCells.length - 1; i++) {
    const a = privateCells[i]!;
    const b = privateCells[i + 1]!;
    if (
      (a.room.type === 'BEDROOM' && b.room.type === 'BATHROOM') ||
      (a.room.type === 'BATHROOM' && b.room.type === 'BEDROOM')
    ) {
      const wallX = b.x;
      const doorY = a.y + a.h * 0.55;
      doors.push({
        x1: wallX,
        y1: doorY - doorWidth / 2,
        x2: wallX,
        y2: doorY + doorWidth / 2,
        arc: 'SE',
      });
    }
  }

  // Salon ↔ Balkon (cam kapı, geniş)
  if (living && balconyCells.length > 0) {
    const balcony = balconyCells[0]!;
    const opening = Math.min(2.4, balcony.w * 0.7);
    const cx = balcony.x + balcony.w / 2;
    doors.push({
      x1: cx - opening / 2,
      y1: living.y,
      x2: cx + opening / 2,
      y2: living.y,
      arc: 'NE',
    });
  }

  return doors;
}

// ====== SVG RENDER ======

interface RenderInput {
  cells: Cell[];
  doors: ComputedDoor[];
  entranceDoor: ComputedDoor | null;
  interiorW: number;
  interiorH: number;
  balconyCells: Cell[];
  garageCells: Cell[];
  totalAreaM2: number;
}

function renderSvg(input: RenderInput): string {
  const { cells, doors, entranceDoor, interiorW, interiorH, balconyCells, garageCells, totalAreaM2 } = input;

  const padding = 24;
  const balconyExtra = balconyCells.length > 0 ? Math.max(...balconyCells.map((c) => -c.y)) + 0.2 : 0;
  const garageExtra = garageCells.length > 0 ? Math.max(...garageCells.map((c) => c.y + c.h - interiorH)) + 0.2 : 0;
  const yOffset = balconyExtra;

  const totalWidthSvg = m(interiorW) + padding * 2;
  const totalHeightSvg = m(interiorH + balconyExtra + garageExtra) + padding * 2;

  // Helpers
  const sx = (xm: number) => Math.round(xm * M) + padding;
  const sy = (ym: number) => Math.round((ym + yOffset) * M) + padding;

  // === GRID PATTERN ===
  const dots: string[] = [];
  for (let x = 0; x <= interiorW; x += 0.5) {
    for (let y = -balconyExtra; y <= interiorH + garageExtra; y += 0.5) {
      dots.push(`<circle cx="${sx(x)}" cy="${sy(y)}" r="0.5" fill="#CBD5E1"/>`);
    }
  }

  // === ROOMS ===
  const wallStroke = '#0F172A';
  const wallW = 3.5;

  const roomEls = cells
    .map((c) => {
      const x = sx(c.x);
      const y = sy(c.y);
      const w = m(c.w);
      const h = m(c.h);
      const isCorridor = c.room.id === '__corridor__';
      const isOuter = c.room.type === 'BALCONY' || c.room.type === 'GARAGE';
      const cx = x + w / 2;
      const cy = y + h / 2;
      const labelMain = escapeXml(c.room.name ?? c.spec.label);
      const area = c.w * c.h;
      const labelSub = `${c.spec.short} · ${area.toFixed(1)} m²`;
      const fontMain = Math.min(
        13,
        Math.max(9, Math.min(w / 8, h / 4)),
      );
      const fontSub = Math.max(8, fontMain - 3);

      // Renkler: koridor ve outer hafif
      const fillOpacity = isCorridor ? 0.6 : isOuter ? 0.85 : 1.0;

      return (
        `<g>` +
        `<rect x="${x}" y="${y}" width="${w}" height="${h}" ` +
        `fill="${c.spec.fill}" fill-opacity="${fillOpacity}" ` +
        `stroke="${isCorridor ? '#94A3B8' : c.spec.stroke}" ` +
        `stroke-width="${isCorridor ? 1 : 1.5}" rx="2"/>` +
        `<text x="${cx}" y="${cy - 3}" text-anchor="middle" dominant-baseline="middle" ` +
        `font-family="Inter, system-ui, sans-serif" font-size="${fontMain}" ` +
        `fill="#0F172A" font-weight="700">${labelMain}</text>` +
        (h > m(1.6)
          ? `<text x="${cx}" y="${cy + fontMain - 1}" text-anchor="middle" dominant-baseline="middle" ` +
            `font-family="Inter, system-ui, sans-serif" font-size="${fontSub}" ` +
            `fill="#475569">${labelSub}</text>`
          : '') +
        `</g>`
      );
    })
    .join('');

  // === DIŞ DUVAR ===
  const outerRect =
    `<rect x="${sx(0)}" y="${sy(0)}" width="${m(interiorW)}" height="${m(interiorH)}" ` +
    `fill="none" stroke="${wallStroke}" stroke-width="${wallW}" rx="3"/>`;

  // === KAPILAR (yay sembolü) ===
  const doorEls = doors.map((d) => renderDoor(d, sx, sy)).join('');

  // === GİRİŞ KAPISI (dış kenarda, çift çizgi + ok) ===
  let entranceEl = '';
  if (entranceDoor) {
    const x1 = sx(entranceDoor.x1);
    const x2 = sx(entranceDoor.x2);
    const y = sy(0);
    const mid = (x1 + x2) / 2;
    entranceEl =
      // Çift duvar boşluğu (kapı yeri)
      `<rect x="${x1 - 2}" y="${y - 4}" width="${x2 - x1 + 4}" height="${wallW + 6}" fill="white"/>` +
      // Kapı çizgisi
      `<line x1="${x1}" y1="${y}" x2="${x1 + (x2 - x1) * 0.9}" y2="${y - (x2 - x1) * 0.9}" ` +
      `stroke="#0F172A" stroke-width="1.8"/>` +
      // Açılış yayı
      `<path d="M${x1},${y} A ${x2 - x1},${x2 - x1} 0 0 1 ${x1 + (x2 - x1) * 0.9},${y - (x2 - x1) * 0.9}" ` +
      `fill="none" stroke="#0F172A" stroke-width="0.8" stroke-dasharray="2,2"/>` +
      // "GİRİŞ" etiketi
      `<text x="${mid}" y="${y - m(0.4)}" text-anchor="middle" font-family="Inter,sans-serif" ` +
      `font-size="9" fill="#0F172A" font-weight="700">GİRİŞ</text>`;
  }

  // === ÖLÇÜ ÇUBUKLARI (üst ve sol) ===
  const measureEl =
    // Üst: toplam genişlik
    `<text x="${sx(interiorW / 2)}" y="${sy(0) - m(balconyExtra) - 8}" text-anchor="middle" ` +
    `font-family="Inter,sans-serif" font-size="10" fill="#475569" font-weight="600">` +
    `${interiorW.toFixed(1)} m</text>` +
    // Sol: yükseklik
    `<text x="${sx(0) - 14}" y="${sy(interiorH / 2)}" text-anchor="middle" dominant-baseline="middle" ` +
    `font-family="Inter,sans-serif" font-size="10" fill="#475569" font-weight="600" ` +
    `transform="rotate(-90 ${sx(0) - 14} ${sy(interiorH / 2)})">` +
    `${interiorH.toFixed(1)} m</text>`;

  // === KUZEY OKU ===
  const compass =
    `<g transform="translate(${totalWidthSvg - 50}, ${padding + 8})">` +
    `<circle cx="0" cy="0" r="16" fill="white" stroke="#0F172A" stroke-width="1"/>` +
    `<path d="M0,-12 L4,4 L0,2 L-4,4 Z" fill="#EF4444" stroke="#0F172A" stroke-width="0.5"/>` +
    `<text x="0" y="-20" text-anchor="middle" font-family="Inter,sans-serif" ` +
    `font-size="9" fill="#0F172A" font-weight="700">K</text>` +
    `</g>`;

  // === BAŞLIK ===
  const header =
    `<text x="${padding}" y="${padding - 8}" font-family="Inter,sans-serif" ` +
    `font-size="11" fill="#0F172A" font-weight="700">Kat Planı</text>` +
    `<text x="${padding + 70}" y="${padding - 8}" font-family="Inter,sans-serif" ` +
    `font-size="11" fill="#64748B">${cells.filter((c) => !c.room.id.startsWith('__')).length} oda · ~${Math.round(totalAreaM2)} m²</text>`;

  return (
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${totalWidthSvg} ${totalHeightSvg}" ` +
    `width="${totalWidthSvg}" height="${totalHeightSvg}">` +
    `<rect width="100%" height="100%" fill="#FFFFFF"/>` +
    dots.join('') +
    roomEls +
    outerRect +
    doorEls +
    entranceEl +
    measureEl +
    compass +
    header +
    `</svg>`
  );
}

/** Kapı: duvar boşluğu (beyaz rect) + yay (oda içine açılır) */
function renderDoor(
  d: ComputedDoor,
  sx: (m: number) => number,
  sy: (m: number) => number,
): string {
  const isHorizontalWall = d.y1 === d.y2;
  const x1 = sx(d.x1);
  const y1 = sy(d.y1);
  const x2 = sx(d.x2);
  const y2 = sy(d.y2);

  if (isHorizontalWall) {
    // Yatay duvar — kapı boşluğu beyaz rect
    const wallGap =
      `<rect x="${x1}" y="${y1 - 3}" width="${x2 - x1}" height="6" fill="white"/>`;
    // Yay
    const r = x2 - x1;
    const arcDir = d.arc === 'NE' || d.arc === 'NW' ? -1 : 1; // yukarı/aşağı
    const startX = d.arc === 'NE' || d.arc === 'SE' ? x1 : x2;
    const endY = y1 + r * arcDir;
    const sweep = d.arc === 'NE' || d.arc === 'SW' ? 1 : 0;
    const arc =
      `<path d="M${startX},${y1} A ${r},${r} 0 0 ${sweep} ${startX},${endY}" ` +
      `fill="none" stroke="#475569" stroke-width="0.8" stroke-dasharray="2,2"/>` +
      `<line x1="${startX}" y1="${y1}" x2="${startX}" y2="${endY}" stroke="#475569" stroke-width="1"/>`;
    return wallGap + arc;
  } else {
    // Dikey duvar
    const wallGap =
      `<rect x="${x1 - 3}" y="${y1}" width="6" height="${y2 - y1}" fill="white"/>`;
    const r = y2 - y1;
    const arcDir = d.arc === 'NE' || d.arc === 'SE' ? 1 : -1; // sağ/sol
    const startY = d.arc === 'NW' || d.arc === 'NE' ? y1 : y2;
    const endX = x1 + r * arcDir;
    const sweep = d.arc === 'NE' || d.arc === 'SW' ? 1 : 0;
    const arc =
      `<path d="M${x1},${startY} A ${r},${r} 0 0 ${sweep} ${endX},${startY}" ` +
      `fill="none" stroke="#475569" stroke-width="0.8" stroke-dasharray="2,2"/>` +
      `<line x1="${x1}" y1="${startY}" x2="${endX}" y2="${startY}" stroke="#475569" stroke-width="1"/>`;
    return wallGap + arc;
  }
}

function emptyResult(): SmartFloorplanResult {
  return {
    svgContent:
      `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 120" width="240" height="120">` +
      `<rect width="100%" height="100%" fill="#F8FAFC"/>` +
      `<text x="120" y="60" text-anchor="middle" font-family="Inter,sans-serif" font-size="13" fill="#64748B">` +
      `Henüz oda yok</text></svg>`,
    estimatedAreaSqm: 0,
    rooms: [],
    width: 240,
    height: 120,
  };
}

function escapeXml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
