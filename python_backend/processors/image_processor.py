from pathlib import Path

import cv2

from processors.fisheye import apply_fisheye


def process_fisheye_image(
    *,
    input_path: Path,
    output_path: Path,
    strength: float,
    center_x: float,
    center_y: float,
    radius: float,
) -> None:
    image = cv2.imread(str(input_path), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError(f"Could not read image: {input_path}")

    output = apply_fisheye(
        image,
        strength=strength,
        center_x=center_x,
        center_y=center_y,
        radius=radius,
    )
    if not cv2.imwrite(str(output_path), output):
        raise ValueError(f"Could not write image: {output_path}")
