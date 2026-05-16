from pydantic import BaseModel, Field


class RoomSummary(BaseModel):
    name: str
    type: str
    mediaCount: int = 0


class DescriptionRequest(BaseModel):
    title: str
    address: str | None = None
    rooms: list[RoomSummary] = Field(default_factory=list)


class DescriptionResponse(BaseModel):
    description: str
