from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np


def stitch_three_images(*, input_paths: list[Path], output_path: Path) -> None:
    if len(input_paths) != 3:
        raise ValueError("Panorama stitching requires exactly 3 images.")

    images = [_read_image(path) for path in input_paths]
    images = _resize_to_common_height(images, target_height=900)

    left_to_center = _estimate_pair_homography(images[0], images[1])
    right_to_center = _estimate_pair_homography(images[2], images[1])
    panorama = _warp_and_blend(
        images=[images[0], images[1], images[2]],
        transforms=[left_to_center, np.eye(3, dtype=np.float64), right_to_center],
    )

    if not cv2.imwrite(str(output_path), panorama):
        raise ValueError(f"Could not write panorama: {output_path}")


def _read_image(path: Path) -> np.ndarray:
    image = cv2.imread(str(path), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError(f"Could not read image: {path}")
    return image


def _resize_to_common_height(images: list[np.ndarray], *, target_height: int) -> list[np.ndarray]:
    min_height = min(image.shape[0] for image in images)
    height = min(min_height, target_height)
    resized = []
    for image in images:
        scale = height / image.shape[0]
        width = int(round(image.shape[1] * scale))
        resized.append(cv2.resize(image, (width, height), interpolation=cv2.INTER_AREA))
    return resized


def _estimate_pair_homography(source: np.ndarray, target: np.ndarray) -> np.ndarray:
    source_gray = cv2.cvtColor(source, cv2.COLOR_BGR2GRAY)
    target_gray = cv2.cvtColor(target, cv2.COLOR_BGR2GRAY)
    detector = cv2.ORB_create(nfeatures=3000)
    source_keypoints, source_descriptors = detector.detectAndCompute(source_gray, None)
    target_keypoints, target_descriptors = detector.detectAndCompute(target_gray, None)

    if source_descriptors is None or target_descriptors is None:
        raise ValueError("Not enough features for panorama matching.")

    matcher = cv2.BFMatcher(cv2.NORM_HAMMING)
    raw_matches = matcher.knnMatch(source_descriptors, target_descriptors, k=2)
    matches = []
    for pair in raw_matches:
        if len(pair) < 2:
            continue
        best, second = pair
        if best.distance < 0.76 * second.distance:
            matches.append(best)

    if len(matches) < 8:
        raise ValueError("Not enough reliable matches for panorama stitching.")

    source_points = np.float64([source_keypoints[match.queryIdx].pt for match in matches])
    target_points = np.float64([target_keypoints[match.trainIdx].pt for match in matches])
    return _ransac_homography(source_points, target_points)


def _ransac_homography(
    source_points: np.ndarray,
    target_points: np.ndarray,
    *,
    iterations: int = 1200,
    threshold: float = 4.0,
) -> np.ndarray:
    rng = np.random.default_rng(7)
    best_inliers: np.ndarray | None = None
    best_count = 0
    point_count = len(source_points)

    for _ in range(iterations):
        sample_indexes = rng.choice(point_count, size=4, replace=False)
        candidate = _dlt_homography(source_points[sample_indexes], target_points[sample_indexes])
        projected = _project_points(source_points, candidate)
        errors = np.linalg.norm(projected - target_points, axis=1)
        inliers = errors < threshold
        inlier_count = int(inliers.sum())
        if inlier_count > best_count:
            best_count = inlier_count
            best_inliers = inliers

    if best_inliers is None or best_count < 8:
        raise ValueError("Could not estimate a stable panorama homography.")

    return _dlt_homography(source_points[best_inliers], target_points[best_inliers])


def _dlt_homography(source_points: np.ndarray, target_points: np.ndarray) -> np.ndarray:
    if len(source_points) < 4:
        raise ValueError("At least 4 points are required for homography.")

    source_normalized, source_transform = _normalize_points(source_points)
    target_normalized, target_transform = _normalize_points(target_points)
    rows = []
    for (x, y), (u, v) in zip(source_normalized, target_normalized):
        rows.append([-x, -y, -1.0, 0.0, 0.0, 0.0, u * x, u * y, u])
        rows.append([0.0, 0.0, 0.0, -x, -y, -1.0, v * x, v * y, v])
    _, _, vh = np.linalg.svd(np.asarray(rows, dtype=np.float64))
    normalized_h = vh[-1].reshape(3, 3)
    homography = np.linalg.inv(target_transform) @ normalized_h @ source_transform
    return homography / homography[2, 2]


def _normalize_points(points: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    centroid = points.mean(axis=0)
    shifted = points - centroid
    mean_distance = np.mean(np.linalg.norm(shifted, axis=1))
    scale = np.sqrt(2.0) / max(mean_distance, 1e-8)
    transform = np.array(
        [
            [scale, 0.0, -scale * centroid[0]],
            [0.0, scale, -scale * centroid[1]],
            [0.0, 0.0, 1.0],
        ],
        dtype=np.float64,
    )
    normalized = _project_points(points, transform)
    return normalized, transform


def _project_points(points: np.ndarray, homography: np.ndarray) -> np.ndarray:
    homogeneous = np.column_stack([points, np.ones(len(points))])
    projected = (homography @ homogeneous.T).T
    return projected[:, :2] / projected[:, 2:3]


def _warp_and_blend(images: list[np.ndarray], transforms: list[np.ndarray]) -> np.ndarray:
    corners = []
    for image, transform in zip(images, transforms):
        height, width = image.shape[:2]
        image_corners = np.float64(
            [[0, 0], [width, 0], [width, height], [0, height]]
        )
        corners.append(_project_points(image_corners, transform))
    all_corners = np.vstack(corners)
    min_xy = np.floor(all_corners.min(axis=0)).astype(int)
    max_xy = np.ceil(all_corners.max(axis=0)).astype(int)
    translation = np.array(
        [
            [1.0, 0.0, -min_xy[0]],
            [0.0, 1.0, -min_xy[1]],
            [0.0, 0.0, 1.0],
        ],
        dtype=np.float64,
    )
    output_width = int(max_xy[0] - min_xy[0])
    output_height = int(max_xy[1] - min_xy[1])

    accumulator = np.zeros((output_height, output_width, 3), dtype=np.float32)
    weights = np.zeros((output_height, output_width), dtype=np.float32)

    for image, transform in zip(images, transforms):
        full_transform = translation @ transform
        warped = cv2.warpPerspective(image, full_transform, (output_width, output_height))
        mask = cv2.warpPerspective(
            np.ones(image.shape[:2], dtype=np.uint8) * 255,
            full_transform,
            (output_width, output_height),
        )
        feather = cv2.distanceTransform(mask, cv2.DIST_L2, 3)
        if feather.max() > 0:
            feather /= feather.max()
        feather = np.clip(feather, 0.02, 1.0) * (mask > 0)
        accumulator += warped.astype(np.float32) * feather[:, :, None]
        weights += feather

    panorama = accumulator / np.maximum(weights[:, :, None], 1e-6)
    valid = weights > 0.01
    y_indexes, x_indexes = np.where(valid)
    if len(x_indexes) == 0 or len(y_indexes) == 0:
        raise ValueError("Panorama canvas is empty.")
    cropped = panorama[
        y_indexes.min() : y_indexes.max() + 1,
        x_indexes.min() : x_indexes.max() + 1,
    ]
    return np.clip(cropped, 0, 255).astype(np.uint8)
