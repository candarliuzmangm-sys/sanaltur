"""
Profesyonel görünümlü 2B kat planı (MVP).
Oda tiplerine göre düzen, etiketler, ıslak hacim renklendirme, basit mobilya ve kapı sembolleri.
"""

from __future__ import annotations

from typing import Any

from app.schemas.floorplan import FloorplanRoomLayout, FloorplanResponse

ROOM_SIZES: dict[str, tuple[float, float]] = {
    "LIVING_ROOM": (5.2, 4.8),
    "BEDROOM": (4.2, 3.8),
    "KITCHEN": (3.8, 3.2),
    "BATHROOM": (2.6, 2.4),
    "DINING_ROOM": (3.6, 3.2),
    "HALLWAY": (3.5, 1.6),
    "OFFICE": (3.2, 3.0),
    "BALCONY": (3.0, 1.4),
    "GARAGE": (5.0, 5.0),
    "LAUNDRY": (2.2, 2.0),
    "CLOSET": (1.6, 1.6),
    "OTHER": (3.0, 3.0),
}

ROOM_LABELS_TR: dict[str, str] = {
    "LIVING_ROOM": "Salon",
    "BEDROOM": "Yatak Odası",
    "KITCHEN": "Mutfak",
    "BATHROOM": "Banyo",
    "DINING_ROOM": "Yemek Odası",
    "HALLWAY": "Hol",
    "OFFICE": "Çalışma",
    "BALCONY": "Balkon",
    "GARAGE": "Garaj",
    "LAUNDRY": "Çamaşır",
    "CLOSET": "Dolap",
    "OTHER": "Oda",
}

WET_TYPES = {"BATHROOM", "LAUNDRY", "WC"}
LIVING_TYPES = {"LIVING_ROOM", "DINING_ROOM", "KITCHEN"}
SLEEP_TYPES = {"BEDROOM", "OFFICE"}

# Düzen önceliği (soldan sağa, yukarıdan aşağı)
TYPE_ORDER = [
    "LIVING_ROOM",
    "KITCHEN",
    "DINING_ROOM",
    "HALLWAY",
    "BEDROOM",
    "OFFICE",
    "BATHROOM",
    "LAUNDRY",
    "CLOSET",
    "BALCONY",
    "GARAGE",
    "OTHER",
]


class _PlacedRoom:
    def __init__(
        self,
        room_id: str,
        label: str,
        room_type: str,
        x: float,
        y: float,
        w: float,
        h: float,
    ):
        self.room_id = room_id
        self.label = label
        self.room_type = room_type
        self.x = x
        self.y = y
        self.w = w
        self.h = h


class FloorplanGenerator:
    async def generate(
        self, property_id: str, rooms: list[Any]
    ) -> FloorplanResponse:
        placed = self._layout_rooms(rooms)
        scale = 42
        layouts = [
            FloorplanRoomLayout(
                roomId=p.room_id,
                x=p.x,
                y=p.y,
                width=p.w,
                height=p.h,
            )
            for p in placed
        ]
        total_area = sum(p.w * p.h for p in placed)
        svg = self._build_svg(placed, scale)

        return FloorplanResponse(
            svgUrl=f"https://media.sanaltur.com/floorplans/{property_id}.svg",
            svgContent=svg,
            estimatedAreaSqm=round(total_area, 1),
            rooms=layouts,
        )

    def _layout_rooms(self, rooms: list[Any]) -> list[_PlacedRoom]:
        parsed: list[tuple[str, str, str]] = []
        for room in rooms:
            room_id = getattr(room, "id", None) or room["id"]
            room_type = getattr(room, "type", None) or room.get("type", "OTHER")
            name = getattr(room, "name", None) or room.get("name") or ""
            label = name.strip() or ROOM_LABELS_TR.get(room_type, "Oda")
            parsed.append((room_id, room_type, label))

        if not parsed:
            return []

        by_type: dict[str, list[tuple[str, str, str]]] = {}
        for item in parsed:
            by_type.setdefault(item[1], []).append(item)

        placed: list[_PlacedRoom] = []
        gap = 0.4
        x0, y0 = 0.5, 0.5

        def place_at(
            room_id: str, room_type: str, label: str, x: float, y: float
        ) -> tuple[float, float]:
            w, h = ROOM_SIZES.get(room_type, (3.0, 3.0))
            placed.append(_PlacedRoom(room_id, label, room_type, x, y, w, h))
            return w, h

        left_x, left_y = x0, y0
        left_w = 0.0
        for t in ("LIVING_ROOM", "KITCHEN", "DINING_ROOM"):
            for room in by_type.pop(t, []):
                w, h = place_at(room[0], room[1], room[2], left_x, left_y)
                left_w = max(left_w, w)
                left_y += h + gap

        right_x = left_x + max(left_w, 4.5) + gap + 1.2
        right_y = y0
        for t in ("BEDROOM", "OFFICE"):
            for room in by_type.pop(t, []):
                w, h = place_at(room[0], room[1], room[2], right_x, right_y)
                right_y += h + gap

        bottom_y = max(left_y, right_y) + 0.2
        bottom_x = x0
        for t in ("BATHROOM", "LAUNDRY", "HALLWAY", "CLOSET"):
            for room in by_type.pop(t, []):
                w, h = place_at(room[0], room[1], room[2], bottom_x, bottom_y)
                bottom_x += w + gap

        rest: list[tuple[str, str, str]] = []
        for group in by_type.values():
            rest.extend(group)
        rest.sort(
            key=lambda r: TYPE_ORDER.index(r[1]) if r[1] in TYPE_ORDER else 99
        )
        for room in rest:
            w, _ = ROOM_SIZES.get(room[1], (3.0, 3.0))
            place_at(room[0], room[1], room[2], bottom_x, bottom_y)
            bottom_x += w + gap

        return placed

    def _room_fill(self, room_type: str) -> str:
        if room_type in WET_TYPES or room_type == "BATHROOM":
            return "#d4e8f5"
        if room_type in LIVING_TYPES:
            return "#f4f1ea"
        if room_type in SLEEP_TYPES:
            return "#ebe8f2"
        return "#eef2ee"

    def _furniture(self, p: _PlacedRoom, x: float, y: float, w: float, h: float) -> str:
        cx, cy = x + w / 2, y + h / 2
        stroke = "#6b7280"
        parts: list[str] = []

        if p.room_type == "BEDROOM":
            bw, bh = w * 0.55, h * 0.38
            parts.append(
                f'<rect x="{cx - bw/2:.1f}" y="{cy - bh/2:.1f}" '
                f'width="{bw:.1f}" height="{bh:.1f}" rx="6" '
                f'fill="#fff" stroke="{stroke}" stroke-width="1.2"/>'
            )
            parts.append(
                f'<rect x="{cx - bw/2 + 8:.1f}" y="{cy - bh/2 - 6:.1f}" '
                f'width="{bw - 16:.1f}" height="8" fill="#fff" stroke="{stroke}" stroke-width="1"/>'
            )
        elif p.room_type == "LIVING_ROOM":
            sw, sh = w * 0.5, h * 0.22
            parts.append(
                f'<rect x="{x + w*0.08:.1f}" y="{y + h*0.55:.1f}" '
                f'width="{sw:.1f}" height="{sh:.1f}" rx="4" '
                f'fill="#fff" stroke="{stroke}" stroke-width="1.2"/>'
            )
            parts.append(
                f'<circle cx="{x + w*0.78:.1f}" cy="{y + h*0.35:.1f}" r="{min(w,h)*0.08:.1f}" '
                f'fill="none" stroke="{stroke}" stroke-width="1.2"/>'
            )
        elif p.room_type == "KITCHEN":
            parts.append(
                f'<rect x="{x + w*0.1:.1f}" y="{y + h*0.15:.1f}" '
                f'width="{w*0.35:.1f}" height="{h*0.7:.1f}" rx="2" '
                f'fill="#fff" stroke="{stroke}" stroke-width="1.2"/>'
            )
            parts.append(
                f'<rect x="{x + w*0.55:.1f}" y="{y + h*0.35:.1f}" '
                f'width="{w*0.32:.1f}" height="{h*0.28:.1f}" rx="3" '
                f'fill="#fff" stroke="{stroke}" stroke-width="1"/>'
            )
        elif p.room_type == "BATHROOM":
            parts.append(
                f'<rect x="{x + w*0.12:.1f}" y="{y + h*0.2:.1f}" '
                f'width="{w*0.35:.1f}" height="{h*0.55:.1f}" rx="8" '
                f'fill="#fff" stroke="{stroke}" stroke-width="1.2"/>'
            )
            parts.append(
                f'<circle cx="{x + w*0.72:.1f}" cy="{y + h*0.28:.1f}" r="{min(w,h)*0.07:.1f}" '
                f'fill="#fff" stroke="{stroke}" stroke-width="1.2"/>'
            )
        elif p.room_type == "DINING_ROOM":
            parts.append(
                f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{w*0.28:.1f}" ry="{h*0.22:.1f}" '
                f'fill="#fff" stroke="{stroke}" stroke-width="1.2"/>'
            )

        return "".join(parts)

    def _door_arc(self, px: float, py: float, pw: float, ph: float, side: str) -> str:
        ds = min(pw, ph) * 0.22
        stroke = "#4a5568"
        if side == "bottom":
            ox, oy = px + pw * 0.4, py + ph
            return (
                f'<path d="M {ox:.1f} {oy:.1f} A {ds:.1f} {ds:.1f} 0 0 1 {ox + ds:.1f} {oy - ds:.1f}" '
                f'fill="none" stroke="{stroke}" stroke-width="1.5"/>'
            )
        ox, oy = px + pw, py + ph * 0.35
        return (
            f'<path d="M {ox:.1f} {oy:.1f} A {ds:.1f} {ds:.1f} 0 0 1 {ox - ds:.1f} {oy + ds:.1f}" '
            f'fill="none" stroke="{stroke}" stroke-width="1.5"/>'
        )

    def _build_svg(self, placed: list[_PlacedRoom], scale: int) -> str:
        if not placed:
            return '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="120"/>'

        pad = 48
        max_x = max((p.x + p.w) * scale for p in placed) + pad * 2
        max_y = max((p.y + p.h) * scale for p in placed) + pad * 2

        inner: list[str] = []
        inner.append(
            f'<rect width="{max_x}" height="{max_y}" fill="#faf9f7"/>'
        )

        # Dış çerçeve
        ox = pad - 8
        oy = pad - 8
        bw = max_x - pad + 4
        bh = max_y - pad + 4
        inner.append(
            f'<rect x="{ox}" y="{oy}" width="{bw - ox}" height="{bh - oy}" '
            f'fill="none" stroke="#3d3d3d" stroke-width="10" rx="2"/>'
        )

        for i, p in enumerate(placed):
            x, y = (p.x * scale) + pad, (p.y * scale) + pad
            w, h = p.w * scale, p.h * scale
            fill = self._room_fill(p.room_type)

            inner.append(
                f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" '
                f'fill="{fill}" stroke="#5c5c5c" stroke-width="3"/>'
            )
            inner.append(self._furniture(p, x, y, w, h))
            inner.append(
                self._door_arc(x, y, w, h, "right" if i % 2 else "bottom")
            )

            # Etiket
            label = p.label[:18]
            tx, ty = x + w / 2, y + h * 0.12
            inner.append(
                f'<text x="{tx:.1f}" y="{ty:.1f}" text-anchor="middle" '
                f'font-family="Segoe UI, Arial, sans-serif" font-size="13" '
                f'font-weight="600" fill="#1a2e28">{self._esc(label)}</text>'
            )
            sub = ROOM_LABELS_TR.get(p.room_type, "")
            if sub and sub.lower() not in label.lower():
                inner.append(
                    f'<text x="{tx:.1f}" y="{ty + 16:.1f}" text-anchor="middle" '
                    f'font-family="Segoe UI, Arial, sans-serif" font-size="10" '
                    f'fill="#6b7280">{self._esc(sub)}</text>'
                )

        inner.append(
            f'<text x="{max_x - pad}" y="{max_y - 12}" text-anchor="end" '
            f'font-size="9" fill="#9ca3af">Sanaltur · tahmini plan</text>'
        )

        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" '
            f'width="{max_x:.0f}" height="{max_y:.0f}" '
            f'viewBox="0 0 {max_x:.0f} {max_y:.0f}">'
            f'{"".join(inner)}</svg>'
        )

    @staticmethod
    def _esc(text: str) -> str:
        return (
            text.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;")
        )
