from pathlib import Path

import cv2

from processors.fisheye import apply_fisheye


def process_fisheye_video(
    *,
    input_path: Path,
    output_path: Path,
    strength: float,
    center_x: float,
    center_y: float,
    radius: float,
) -> None:
    capture = cv2.VideoCapture(str(input_path))
    if not capture.isOpened():
        raise ValueError(f"Could not open video: {input_path}")

    fps = capture.get(cv2.CAP_PROP_FPS) or 30.0
    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    writer = cv2.VideoWriter(
        str(output_path),
        cv2.VideoWriter_fourcc(*"mp4v"),
        fps,
        (width, height),
    )
    if not writer.isOpened():
        capture.release()
        raise ValueError(f"Could not create video writer: {output_path}")

    try:
        while True:
            ok, frame = capture.read()
            if not ok:
                break
            writer.write(
                apply_fisheye(
                    frame,
                    strength=strength,
                    center_x=center_x,
                    center_y=center_y,
                    radius=radius,
                )
            )
    finally:
        capture.release()
        writer.release()
