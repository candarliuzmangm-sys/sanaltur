from app.schemas.description import DescriptionRequest, DescriptionResponse

_TYPE_TR = {
    "LIVING_ROOM": "geniş salon",
    "BEDROOM": "yatak odası",
    "KITCHEN": "modern mutfak",
    "BATHROOM": "banyo",
    "DINING_ROOM": "yemek odası",
    "HALLWAY": "hol",
    "OFFICE": "çalışma odası",
    "BALCONY": "balkon",
    "GARAGE": "garaj",
    "LAUNDRY": "çamaşır odası",
    "CLOSET": "dolap alanı",
    "OTHER": "ek oda",
}


class DescriptionGenerator:
    async def generate(self, body: DescriptionRequest) -> DescriptionResponse:
        room_bits: list[str] = []
        total_media = 0
        for room in body.rooms:
            label = _TYPE_TR.get(room.type, room.type.lower())
            room_bits.append(f"{room.name} ({label}, {room.mediaCount} fotoğraf)")
            total_media += room.mediaCount

        location = f" {body.address} konumunda" if body.address else ""
        rooms_text = (
            ", ".join(room_bits[:6]) if room_bits else "çok odalı düzen"
        )

        description = (
            f"{body.title}{location} — toplam {len(body.rooms)} oda ve "
            f"{total_media} profesyonel çekimle sunulan bu mülk; "
            f"{rooms_text} içerir. "
            f"Sanaltur sanal tur ile odaları gezerek evi uzaktan "
            f"deneyimleyebilirsiniz."
        )

        return DescriptionResponse(description=description)
