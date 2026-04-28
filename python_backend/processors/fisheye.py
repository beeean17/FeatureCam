from __future__ import annotations

import cv2
import numpy as np


def apply_fisheye(
    image: np.ndarray,
    *,
    strength: float,
    center_x: float,
    center_y: float,
    radius: float,
) -> np.ndarray:
    height, width = image.shape[:2]
    center = np.array(
        [
            np.clip(center_x, 0.0, 1.0) * (width - 1),
            np.clip(center_y, 0.0, 1.0) * (height - 1),
        ],
        dtype=np.float32,
    )
    lens_radius = max(8.0, np.clip(radius, 0.05, 1.0) * min(width, height))
    exponent = 1.0 + float(np.clip(strength, 0.1, 2.0))

    grid_x, grid_y = np.meshgrid(
        np.arange(width, dtype=np.float32),
        np.arange(height, dtype=np.float32),
    )
    dx = grid_x - center[0]
    dy = grid_y - center[1]
    distance = np.sqrt(dx * dx + dy * dy)
    normalized_distance = distance / lens_radius

    inside = normalized_distance <= 1.0
    source_distance = np.power(
        np.clip(normalized_distance, 0.0, 1.0),
        exponent,
    ) * lens_radius
    scale = np.divide(
        source_distance,
        distance,
        out=np.zeros_like(distance, dtype=np.float32),
        where=distance > 1e-4,
    )

    map_x = grid_x.copy()
    map_y = grid_y.copy()
    map_x[inside] = center[0] + dx[inside] * scale[inside]
    map_y[inside] = center[1] + dy[inside] * scale[inside]

    remapped = cv2.remap(
        image,
        map_x,
        map_y,
        interpolation=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_REPLICATE,
    )

    shade = np.clip(1.0 - 0.34 * normalized_distance * normalized_distance, 0.52, 1.0)
    shaded = remapped.astype(np.float32)
    shaded[inside] *= shade[inside, None]
    remapped[inside] = np.clip(shaded[inside], 0, 255).astype(np.uint8)
    return remapped
