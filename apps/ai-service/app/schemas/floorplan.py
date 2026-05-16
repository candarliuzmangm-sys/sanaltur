from pydantic import BaseModel, Field


class FloorplanRoomInput(BaseModel):
    id: str
    type: str
    name: str | None = None
    imageUrls: list[str] = Field(default_factory=list)


class FloorplanRequest(BaseModel):
    propertyId: str
    rooms: list[FloorplanRoomInput]


class FloorplanRoomLayout(BaseModel):
    roomId: str
    x: float
    y: float
    width: float
    height: float


class FloorplanResponse(BaseModel):
    svgUrl: str
    svgContent: str
    pngUrl: str | None = None
    estimatedAreaSqm: float | None = None
    rooms: list[FloorplanRoomLayout]
