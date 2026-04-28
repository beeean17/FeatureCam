from pathlib import Path
from uuid import uuid4

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import FileResponse

from processors.image_processor import process_fisheye_image
from processors.panorama_stitcher import stitch_three_images
from processors.video_processor import process_fisheye_video

app = FastAPI(title="FeatureCam Processing Backend")
STORAGE_ROOT = Path(__file__).resolve().parent / "storage"
INPUT_ROOT = STORAGE_ROOT / "input"
OUTPUT_ROOT = STORAGE_ROOT / "output"


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/process/photo")
async def process_photo(
    image: UploadFile = File(...),
    strength: float = Form(0.85),
    center_x: float = Form(0.5),
    center_y: float = Form(0.5),
    radius: float = Form(0.5),
) -> FileResponse:
    request_id = uuid4().hex
    input_path = INPUT_ROOT / f"{request_id}_input.jpg"
    output_path = OUTPUT_ROOT / f"{request_id}_fisheye.jpg"
    await _save_upload(image, input_path)
    process_fisheye_image(
        input_path=input_path,
        output_path=output_path,
        strength=strength,
        center_x=center_x,
        center_y=center_y,
        radius=radius,
    )
    return FileResponse(output_path, media_type="image/jpeg", filename="fisheye.jpg")


@app.post("/process/video")
async def process_video(
    video: UploadFile = File(...),
    strength: float = Form(0.85),
    center_x: float = Form(0.5),
    center_y: float = Form(0.5),
    radius: float = Form(0.5),
) -> FileResponse:
    request_id = uuid4().hex
    input_path = INPUT_ROOT / f"{request_id}_input.mp4"
    output_path = OUTPUT_ROOT / f"{request_id}_fisheye.mp4"
    await _save_upload(video, input_path)
    process_fisheye_video(
        input_path=input_path,
        output_path=output_path,
        strength=strength,
        center_x=center_x,
        center_y=center_y,
        radius=radius,
    )
    return FileResponse(output_path, media_type="video/mp4", filename="fisheye.mp4")


@app.post("/process/panorama")
async def process_panorama(
    image_1: UploadFile = File(...),
    image_2: UploadFile = File(...),
    image_3: UploadFile = File(...),
) -> FileResponse:
    request_id = uuid4().hex
    input_paths = [
        INPUT_ROOT / f"{request_id}_image_1.jpg",
        INPUT_ROOT / f"{request_id}_image_2.jpg",
        INPUT_ROOT / f"{request_id}_image_3.jpg",
    ]
    output_path = OUTPUT_ROOT / f"{request_id}_panorama.jpg"
    for upload, path in zip([image_1, image_2, image_3], input_paths):
        await _save_upload(upload, path)
    stitch_three_images(input_paths=input_paths, output_path=output_path)
    return FileResponse(output_path, media_type="image/jpeg", filename="panorama.jpg")


async def _save_upload(upload: UploadFile, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    path.write_bytes(await upload.read())
