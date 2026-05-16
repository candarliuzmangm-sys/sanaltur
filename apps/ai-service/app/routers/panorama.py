"""Panorama stitching endpoint — OpenCV ile birden çok fotodan equirectangular panorama üretir."""

from io import BytesIO
from typing import List

import cv2
import numpy as np
from fastapi import APIRouter, File, HTTPException, UploadFile, status
from fastapi.responses import Response

router = APIRouter()


@router.post(
    "/panorama/stitch",
    summary="Stitch multiple photos into a panorama",
    response_class=Response,
)
async def stitch_panorama(
    files: List[UploadFile] = File(..., description="2-12 photos taken in order, rotating right"),
):
    """OpenCV Stitcher kullanarak birden çok fotoyu birleştirir.

    Dönüş: image/jpeg binary (equirectangular benzeri, geniş açılı panorama).
    Marzipano'da `mediaType=PANORAMA` olarak gösterilir.
    """
    if len(files) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="En az 2 fotoğraf gerekli",
        )
    if len(files) > 12:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="En fazla 12 fotoğraf",
        )

    images = []
    for f in files:
        content = await f.read()
        arr = np.frombuffer(content, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if img is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Geçersiz görüntü: {f.filename}",
            )
        # Downscale çok büyükse (>2000px wide) — stitch hızlanır
        h, w = img.shape[:2]
        if w > 2200:
            scale = 2200.0 / w
            img = cv2.resize(img, (int(w * scale), int(h * scale)))
        images.append(img)

    # Stitcher modu: PANORAMA (otomatik feature matching)
    stitcher = cv2.Stitcher_create(cv2.Stitcher_PANORAMA)
    # Setting feature finder confidence threshold lower for handheld photos
    try:
        stitcher.setPanoConfidenceThresh(0.6)
    except Exception:
        pass

    status_code, pano = stitcher.stitch(images)

    if status_code == cv2.Stitcher_OK and pano is not None:
        # Sonucu cropla (siyah kenarları kaldır)
        pano = _crop_black_borders(pano)

        # JPEG encode
        ok, buf = cv2.imencode(".jpg", pano, [cv2.IMWRITE_JPEG_QUALITY, 88])
        if not ok:
            raise HTTPException(500, "JPEG encode başarısız")
        return Response(
            content=buf.tobytes(),
            media_type="image/jpeg",
            headers={
                "X-Stitch-Status": "ok",
                "X-Pano-Width": str(pano.shape[1]),
                "X-Pano-Height": str(pano.shape[0]),
            },
        )

    # Stitch başarısız — neden bilgisi
    reasons = {
        cv2.Stitcher_ERR_NEED_MORE_IMGS: "Yeterli ortak nokta bulunamadı — daha fazla foto çek, daha fazla bindirin",
        cv2.Stitcher_ERR_HOMOGRAPHY_EST_FAIL: "Eşleştirme başarısız — kamerayı sabit tut, sadece yavaşça sağa dön",
        cv2.Stitcher_ERR_CAMERA_PARAMS_ADJUST_FAIL: "Kamera parametreleri uydurulamadı",
    }
    detail = reasons.get(status_code, f"Stitch hatası ({status_code})")
    raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=detail)


def _crop_black_borders(img: np.ndarray) -> np.ndarray:
    """Stitch sonrası siyah kenarları çıkar."""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    # Mask: parlak piksel
    _, mask = cv2.threshold(gray, 1, 255, cv2.THRESH_BINARY)
    coords = cv2.findNonZero(mask)
    if coords is None:
        return img
    x, y, w, h = cv2.boundingRect(coords)
    return img[y : y + h, x : x + w]
