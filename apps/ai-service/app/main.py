from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import classify, description, floorplan, health, panorama

app = FastAPI(
    title="Sanaltur AI Service",
    description="Room classification, ordering, and floorplan estimation",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(classify.router, prefix="/ai", tags=["ai"])
app.include_router(floorplan.router, prefix="/ai", tags=["ai"])
app.include_router(description.router, prefix="/ai", tags=["ai"])
app.include_router(panorama.router, prefix="/ai", tags=["ai"])
