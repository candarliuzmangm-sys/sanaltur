from fastapi import APIRouter

from app.schemas.classify import (
    ClassifyRoomRequest,
    ClassifyRoomResponse,
    ClassifyRoomsRequest,
    ClassifyRoomsResponse,
    OrderRoomsRequest,
    OrderRoomsResponse,
)
from app.services.room_classifier import RoomClassifier
from app.services.room_orderer import RoomOrderer

router = APIRouter()
_classifier = RoomClassifier()
_orderer = RoomOrderer()


@router.post("/classify-room", response_model=ClassifyRoomResponse)
async def classify_room(body: ClassifyRoomRequest):
    results = await _classifier.classify(
        [{"id": body.roomId, "imageUrls": body.imageUrls, "userType": body.userType}]
    )
    item = results[0]
    return ClassifyRoomResponse(
        roomId=item["roomId"],
        predictedType=item["predictedType"],
        confidence=item["confidence"],
    )


@router.post("/classify-rooms", response_model=ClassifyRoomsResponse)
async def classify_rooms(body: ClassifyRoomsRequest):
    classifications = await _classifier.classify(body.rooms)
    return ClassifyRoomsResponse(classifications=classifications)


@router.post("/order-rooms", response_model=OrderRoomsResponse)
async def order_rooms(body: OrderRoomsRequest):
    room_ids = _orderer.order(body.rooms)
    return OrderRoomsResponse(roomIds=room_ids)
