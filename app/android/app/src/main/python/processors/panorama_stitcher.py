from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np


def stitch_three_images(*, input_paths: list[Path], output_path: Path) -> None:
    if len(input_paths) != 3:
        raise ValueError("Panorama stitching requires exactly 3 images.")

    images = [_read_image(path) for path in input_paths]
    images = _resize_to_common_height(images, target_height=900)
    panorama = _stitch_fixed_twenty_percent_overlap(images)

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


def _stitch_fixed_twenty_percent_overlap(images: list[np.ndarray]) -> np.ndarray:
    if len(images) != 3:
        raise ValueError("Fixed-overlap stitching requires exactly 3 images.")

    overlap_12 = _overlap_width(images[0], images[1])
    overlap_23 = _overlap_width(images[1], images[2])
    y_offsets = [
        0,
        _estimate_vertical_offset(images[0], images[1], overlap_12),
    ]
    y_offsets.append(
        y_offsets[1] + _estimate_vertical_offset(images[1], images[2], overlap_23)
    )

    x_offsets = [
        0,
        images[0].shape[1] - overlap_12,
        images[0].shape[1] + images[1].shape[1] - overlap_12 - overlap_23,
    ]

    min_y = min(y_offsets)
    normalized_y = [offset - min_y for offset in y_offsets]
    output_width = x_offsets[2] + images[2].shape[1]
    output_height = max(
        y_offset + image.shape[0] for image, y_offset in zip(images, normalized_y)
    )

    accumulator = np.zeros((output_height, output_width, 3), dtype=np.float32)
    weights = np.zeros((output_height, output_width), dtype=np.float32)

    overlaps_left = [0, overlap_12, overlap_23]
    overlaps_right = [overlap_12, overlap_23, 0]
    for image, x_offset, y_offset, left_overlap, right_overlap in zip(
        images,
        x_offsets,
        normalized_y,
        overlaps_left,
        overlaps_right,
    ):
        image_weight = _horizontal_blend_weight(
            image.shape[1],
            left_overlap=left_overlap,
            right_overlap=right_overlap,
        )
        height, width = image.shape[:2]
        y_slice = slice(y_offset, y_offset + height)
        x_slice = slice(x_offset, x_offset + width)
        accumulator[y_slice, x_slice] += image.astype(np.float32) * image_weight[None, :, None]
        weights[y_slice, x_slice] += image_weight[None, :]

    panorama = accumulator / np.maximum(weights[:, :, None], 1e-6)
    valid = weights > 0.001
    y_indexes, x_indexes = np.where(valid)
    if len(x_indexes) == 0 or len(y_indexes) == 0:
        raise ValueError("Panorama canvas is empty.")

    cropped = panorama[
        y_indexes.min() : y_indexes.max() + 1,
        x_indexes.min() : x_indexes.max() + 1,
    ]
    return np.clip(cropped, 0, 255).astype(np.uint8)


def _overlap_width(first: np.ndarray, second: np.ndarray) -> int:
    return max(1, int(round(min(first.shape[1], second.shape[1]) * 0.20)))


def _horizontal_blend_weight(
    width: int,
    *,
    left_overlap: int,
    right_overlap: int,
) -> np.ndarray:
    weight = np.ones(width, dtype=np.float32)
    if left_overlap > 0:
        weight[:left_overlap] = np.linspace(0.0, 1.0, left_overlap, dtype=np.float32)
    if right_overlap > 0:
        weight[-right_overlap:] = np.linspace(1.0, 0.0, right_overlap, dtype=np.float32)
    return np.clip(weight, 0.02, 1.0)


def _estimate_vertical_offset(
    left_image: np.ndarray,
    right_image: np.ndarray,
    overlap: int,
) -> int:
    left_strip = left_image[:, -overlap:]
    right_strip = right_image[:, :overlap]
    left_gray = _normalized_gray(left_strip)
    right_gray = _normalized_gray(right_strip)
    height = min(left_gray.shape[0], right_gray.shape[0])
    max_shift = max(2, int(round(height * 0.06)))
    best_shift = 0
    best_error = float("inf")

    for shift in range(-max_shift, max_shift + 1):
        canvas_start = max(0, shift)
        canvas_end = min(height, height + shift)
        if canvas_end - canvas_start < height * 0.72:
            continue
        left_part = left_gray[canvas_start:canvas_end]
        right_part = right_gray[canvas_start - shift : canvas_end - shift]
        error = float(np.mean((left_part - right_part) ** 2))
        if error < best_error:
            best_error = error
            best_shift = shift

    return best_shift


def _normalized_gray(image: np.ndarray) -> np.ndarray:
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY).astype(np.float32)
    gray = cv2.GaussianBlur(gray, (5, 5), 0)
    gray -= gray.mean()
    std = gray.std()
    if std > 1e-6:
        gray /= std
    return gray


def _estimate_pair_homography(
    source: np.ndarray,
    target: np.ndarray,
    *,
    relation: str,
) -> np.ndarray:
    best_result: tuple[int, np.ndarray] | None = None
    failures = []

    for detector_name in ("brisk", "orb"):
        for region_name, source_rect, target_rect in _overlap_regions(
            source,
            target,
            relation=relation,
        ):
            try:
                source_points, target_points = _match_points(
                    source,
                    target,
                    detector_name=detector_name,
                    source_rect=source_rect,
                    target_rect=target_rect,
                )
                homography, inlier_count = _ransac_homography(
                    source_points,
                    target_points,
                )
                if best_result is None or inlier_count > best_result[0]:
                    best_result = (inlier_count, homography)
            except ValueError as error:
                failures.append(f"{detector_name}/{region_name}: {error}")

    if best_result is None:
        detail = "; ".join(failures[:4])
        raise ValueError(
            "Not enough reliable matches for panorama stitching."
            + (f" Attempts: {detail}" if detail else "")
        )

    return best_result[1]


def _ensure_horizontal_expansion(
    homography: np.ndarray,
    *,
    source: np.ndarray,
    target: np.ndarray,
    relation: str,
) -> np.ndarray:
    if _has_expected_horizontal_layout(
        homography,
        source=source,
        target=target,
        relation=relation,
    ):
        return homography
    return _overlap_translation(source, target, relation=relation)


def _has_expected_horizontal_layout(
    homography: np.ndarray,
    *,
    source: np.ndarray,
    target: np.ndarray,
    relation: str,
) -> bool:
    source_height, source_width = source.shape[:2]
    target_height, target_width = target.shape[:2]
    corners = np.float64(
        [[0, 0], [source_width, 0], [source_width, source_height], [0, source_height]]
    )
    projected = _project_points(corners, homography)
    if not np.isfinite(projected).all():
        return False

    projected_width = projected[:, 0].max() - projected[:, 0].min()
    projected_height = projected[:, 1].max() - projected[:, 1].min()
    if projected_width < source_width * 0.35 or projected_height < target_height * 0.35:
        return False
    if projected_width > source_width * 2.8 or projected_height > target_height * 2.8:
        return False

    projected_center_x = _project_points(
        np.float64([[source_width * 0.5, source_height * 0.5]]),
        homography,
    )[0, 0]
    if relation == "source_right_of_target":
        return projected_center_x > target_width * 0.52
    if relation == "source_left_of_target":
        return projected_center_x < target_width * 0.48
    return True


def _overlap_translation(
    source: np.ndarray,
    target: np.ndarray,
    *,
    relation: str,
) -> np.ndarray:
    _, target_width = target.shape[:2]
    _, source_width = source.shape[:2]
    overlap = min(source_width, target_width) * 0.20
    if relation == "source_right_of_target":
        shift_x = target_width - overlap
    elif relation == "source_left_of_target":
        shift_x = -(source_width - overlap)
    else:
        shift_x = 0.0
    return np.array(
        [[1.0, 0.0, shift_x], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]],
        dtype=np.float64,
    )


def _overlap_regions(
    source: np.ndarray,
    target: np.ndarray,
    *,
    relation: str,
) -> list[tuple[str, tuple[int, int, int, int], tuple[int, int, int, int]]]:
    source_height, source_width = source.shape[:2]
    target_height, target_width = target.shape[:2]
    if relation == "source_left_of_target":
        directional = (
            int(source_width * 0.35),
            0,
            source_width,
            source_height,
        ), (
            0,
            0,
            int(target_width * 0.65),
            target_height,
        )
    elif relation == "source_right_of_target":
        directional = (
            0,
            0,
            int(source_width * 0.65),
            source_height,
        ), (
            int(target_width * 0.35),
            0,
            target_width,
            target_height,
        )
    else:
        directional = (
            0,
            0,
            source_width,
            source_height,
        ), (
            0,
            0,
            target_width,
            target_height,
        )

    full = (
        0,
        0,
        source_width,
        source_height,
    ), (
        0,
        0,
        target_width,
        target_height,
    )
    return [("overlap", directional[0], directional[1]), ("full", full[0], full[1])]


def _match_points(
    source: np.ndarray,
    target: np.ndarray,
    *,
    detector_name: str,
    source_rect: tuple[int, int, int, int],
    target_rect: tuple[int, int, int, int],
) -> tuple[np.ndarray, np.ndarray]:
    source_keypoints, source_descriptors = _detect_features(
        source,
        detector_name=detector_name,
        rect=source_rect,
    )
    target_keypoints, target_descriptors = _detect_features(
        target,
        detector_name=detector_name,
        rect=target_rect,
    )

    if source_descriptors is None or target_descriptors is None:
        raise ValueError("not enough descriptors")
    if len(source_keypoints) < 4 or len(target_keypoints) < 4:
        raise ValueError("not enough keypoints")

    matches = _combined_hamming_matches(source_descriptors, target_descriptors)
    if len(matches) < 4:
        raise ValueError(f"only {len(matches)} descriptor matches")

    source_points = np.float64([source_keypoints[match.queryIdx].pt for match in matches])
    target_points = np.float64([target_keypoints[match.trainIdx].pt for match in matches])
    return source_points, target_points


def _detect_features(
    image: np.ndarray,
    *,
    detector_name: str,
    rect: tuple[int, int, int, int],
) -> tuple[list[cv2.KeyPoint], np.ndarray | None]:
    left, top, right, bottom = rect
    crop = image[top:bottom, left:right]
    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
    gray = cv2.equalizeHist(gray)
    if detector_name == "brisk":
        detector = cv2.BRISK_create(thresh=24, octaves=3)
    else:
        detector = cv2.ORB_create(nfeatures=5000, fastThreshold=8)
    keypoints, descriptors = detector.detectAndCompute(gray, None)
    shifted = [
        cv2.KeyPoint(
            keypoint.pt[0] + left,
            keypoint.pt[1] + top,
            keypoint.size,
            keypoint.angle,
            keypoint.response,
            keypoint.octave,
            keypoint.class_id,
        )
        for keypoint in keypoints
    ]
    return shifted, descriptors


def _combined_hamming_matches(
    source_descriptors: np.ndarray,
    target_descriptors: np.ndarray,
) -> list[cv2.DMatch]:
    selected: dict[tuple[int, int], cv2.DMatch] = {}

    cross_checker = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)
    for match in cross_checker.match(source_descriptors, target_descriptors):
        selected[(match.queryIdx, match.trainIdx)] = match

    matcher = cv2.BFMatcher(cv2.NORM_HAMMING)
    for pair in matcher.knnMatch(source_descriptors, target_descriptors, k=2):
        if len(pair) < 2:
            continue
        best, second = pair
        if best.distance <= 0.88 * second.distance:
            key = (best.queryIdx, best.trainIdx)
            previous = selected.get(key)
            if previous is None or best.distance < previous.distance:
                selected[key] = best

    matches = sorted(selected.values(), key=lambda match: match.distance)
    return matches[:450]


def _ransac_homography(
    source_points: np.ndarray,
    target_points: np.ndarray,
    *,
    iterations: int = 2500,
    threshold: float = 7.0,
) -> tuple[np.ndarray, int]:
    rng = np.random.default_rng(7)
    best_inliers: np.ndarray | None = None
    best_count = 0
    point_count = len(source_points)
    if point_count < 4:
        raise ValueError("at least 4 matches are required")

    for _ in range(iterations):
        sample_indexes = rng.choice(point_count, size=4, replace=False)
        try:
            candidate = _dlt_homography(source_points[sample_indexes], target_points[sample_indexes])
        except ValueError:
            continue
        projected = _project_points(source_points, candidate)
        errors = np.linalg.norm(projected - target_points, axis=1)
        inliers = errors < threshold
        inlier_count = int(inliers.sum())
        if inlier_count > best_count:
            best_count = inlier_count
            best_inliers = inliers

    if best_inliers is None or best_count < 6:
        raise ValueError(f"unstable homography, best inliers={best_count}")

    return _dlt_homography(source_points[best_inliers], target_points[best_inliers]), best_count


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
    if abs(homography[2, 2]) < 1e-10:
        raise ValueError("degenerate homography")
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
