"""
MVP room classifier — heuristic + optional vision model hook.
Production: swap _predict_type with fine-tuned PyTorch model.
"""

import random
from typing import Any

# Logical room type priority when user hint exists
USER_TYPE_WEIGHT = 0.85

ROOM_KEYWORDS: dict[str, list[str]] = {
    "KITCHEN": ["kitchen", "mutfak", "stove", "oven", "sink"],
    "BATHROOM": ["bathroom", "banyo", "toilet", "shower", "tub"],
    "BEDROOM": ["bedroom", "yatak", "bed", "wardrobe"],
    "LIVING_ROOM": ["living", "salon", "sofa", "couch", "tv"],
    "DINING_ROOM": ["dining", "yemek", "table"],
    "OFFICE": ["office", "ofis", "desk", "computer"],
    "HALLWAY": ["hallway", "koridor", "corridor"],
    "BALCONY": ["balcony", "balkon"],
    "GARAGE": ["garage", "garaj"],
    "LAUNDRY": ["laundry", "çamaşır", "washer"],
    "CLOSET": ["closet", "dolap"],
}


class RoomClassifier:
    async def classify(self, rooms: list[Any]) -> list[dict]:
        results = []
        for room in rooms:
            user_type = getattr(room, "userType", None) or room.get("userType")
            image_urls = getattr(room, "imageUrls", None) or room.get("imageUrls", [])
            room_id = getattr(room, "id", None) or room["id"]

            predicted, confidence = self._predict_type(user_type, image_urls)
            results.append(
                {
                    "roomId": room_id,
                    "predictedType": predicted,
                    "confidence": confidence,
                }
            )
        return results

    def _predict_type(
        self, user_type: str | None, image_urls: list[str]
    ) -> tuple[str, float]:
        if user_type:
            return user_type, USER_TYPE_WEIGHT + random.uniform(0, 0.1)

        # MVP fallback: distribute common residential types
        fallback_types = [
            "LIVING_ROOM",
            "BEDROOM",
            "KITCHEN",
            "BATHROOM",
            "HALLWAY",
        ]
        predicted = random.choice(fallback_types)
        return predicted, round(random.uniform(0.55, 0.75), 2)
