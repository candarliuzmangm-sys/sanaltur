from fastapi import APIRouter

from app.schemas.description import DescriptionRequest, DescriptionResponse
from app.services.description_generator import DescriptionGenerator

router = APIRouter()
_generator = DescriptionGenerator()


@router.post("/generate-description", response_model=DescriptionResponse)
async def generate_description(body: DescriptionRequest):
    return await _generator.generate(body)
