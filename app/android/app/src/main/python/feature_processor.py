from __future__ import annotations

from pathlib import Path

from processors.image_processor import process_fisheye_image
from processors.panorama_stitcher import stitch_three_images
from processors.video_processor import process_fisheye_video


def process_photo(
    input_path: str,
    output_path: str,
    strength: float,
    center_x: float,
    center_y: float,
    radius: float,
) -> str:
    process_fisheye_image(
        input_path=Path(input_path),
        output_path=Path(output_path),
        strength=float(strength),
        center_x=float(center_x),
        center_y=float(center_y),
        radius=float(radius),
    )
    return output_path


def process_video(
    input_path: str,
    output_path: str,
    strength: float,
    center_x: float,
    center_y: float,
    radius: float,
) -> str:
    process_fisheye_video(
        input_path=Path(input_path),
        output_path=Path(output_path),
        strength=float(strength),
        center_x=float(center_x),
        center_y=float(center_y),
        radius=float(radius),
    )
    return output_path


def process_panorama(input_paths: object, output_path: str) -> str:
    paths = _string_list(input_paths)
    stitch_three_images(
        input_paths=[Path(path) for path in paths],
        output_path=Path(output_path),
    )
    return output_path


def _string_list(value: object) -> list[str]:
    try:
        return [str(item) for item in value]
    except TypeError:
        pass

    if hasattr(value, "size") and hasattr(value, "get"):
        return [str(value.get(index)) for index in range(value.size())]

    if hasattr(value, "toArray"):
        return [str(item) for item in value.toArray()]

    raise TypeError(f"Unsupported path list type: {type(value)!r}")
