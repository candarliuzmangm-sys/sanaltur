from pydantic import BaseModel, Field


class RoomInput(BaseModel):
    id: str
    imageUrls: list[str] = Field(default_factory=list)
    userType: str | None = None


class ClassifyRoomsRequest(BaseModel):
    propertyId: str
    rooms: list[RoomInput]


class ClassificationResult(BaseModel):
    roomId: str
    predictedType: str
    confidence: float


class ClassifyRoomsResponse(BaseModel):
    classifications: list[ClassificationResult]


class ClassifyRoomRequest(BaseModel):
    roomId: str
    imageUrls: list[str] = Field(default_factory=list)
    userType: str | None = None


class ClassifyRoomResponse(BaseModel):
    roomId: str
    predictedType: str
    confidence: float


class OrderRoomInput(BaseModel):
    id: str
    type: str


class OrderRoomsRequest(BaseModel):
    propertyId: str
    rooms: list[OrderRoomInput]


class OrderRoomsResponse(BaseModel):
    roomIds: list[str]
