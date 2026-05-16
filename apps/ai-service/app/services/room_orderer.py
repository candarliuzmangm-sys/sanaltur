"""
Smart room ordering for virtual walkthrough — entry → living → private → utility.
"""

from typing import Any

ORDER_PRIORITY: dict[str, int] = {
    "HALLWAY": 0,
    "LIVING_ROOM": 1,
    "DINING_ROOM": 2,
    "KITCHEN": 3,
    "OFFICE": 4,
    "BEDROOM": 5,
    "BATHROOM": 6,
    "BALCONY": 7,
    "LAUNDRY": 8,
    "CLOSET": 9,
    "GARAGE": 10,
    "OTHER": 99,
}


class RoomOrderer:
    def order(self, rooms: list[Any]) -> list[str]:
        def sort_key(room: Any) -> tuple[int, str]:
            room_type = getattr(room, "type", None) or room.get("type", "OTHER")
            room_id = getattr(room, "id", None) or room["id"]
            return (ORDER_PRIORITY.get(room_type, 99), room_id)

        sorted_rooms = sorted(rooms, key=sort_key)
        return [
            getattr(r, "id", None) or r["id"] for r in sorted_rooms
        ]
