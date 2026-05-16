from fastapi import APIRouter

from app.schemas.floorplan import FloorplanRequest, FloorplanResponse
from app.services.floorplan_generator import FloorplanGenerator

router = APIRouter()
_generator = FloorplanGenerator()


@router.post("/generate-floorplan", response_model=FloorplanResponse)
async def generate_floorplan(body: FloorplanRequest):
    return await _generator.generate(body.propertyId, body.rooms)
