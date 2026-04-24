# Camera App Architecture

## 목표

FeatureCam은 Android 전용 Flutter 카메라 앱이다. Flutter는 UI와 사용자 흐름을 담당하고, 사진/영상의 실제 fisheye 프로세싱과 panorama stitching은 Python 코드에서 수행한다.

과제 조건상 Python 프로세싱이 핵심 요구사항이므로, 새 구조는 실시간 native shader 앱이 아니라 촬영 후 Python/OpenCV 기반 후처리 앱으로 설계한다.

## 핵심 원칙

- Flutter는 화면, 상태, 카메라 조작, panorama 촬영 가이드, 파일 전달, 결과 표시를 담당한다.
- Python은 이미지/영상 처리 알고리즘과 panorama stitching 알고리즘을 담당한다.
- 카메라 초기화, 프리뷰, 사진 촬영, 영상 녹화는 하나의 `CameraSession`에서 관리한다.
- `photo`와 `video`는 캡처 타입이고, `normal`과 `fisheye`는 효과 타입으로 분리한다.
- fisheye 처리 수식은 사진과 영상에서 같은 파라미터 모델을 공유한다.
- panorama는 왼쪽에서 오른쪽으로 3장의 사진을 직접 촬영하고, Python에서 직접 구현한 stitching pipeline으로 합성한다.
- 타깃 OS는 Android만 고려한다.

## 전체 구조

```txt
Flutter Android App
  - 카메라 프리뷰
  - 사진/영상 촬영
  - normal/fisheye 모드 선택
  - panorama 3장 촬영 가이드
  - Python processing 요청
  - 진행 상태 표시
  - 결과 미리보기/저장

Python Processing Backend
  - OpenCV/NumPy 기반 fisheye 처리
  - 직접 구현한 panorama stitching
  - 이미지 파일 처리
  - 영상 프레임 처리
  - 처리 결과 파일 생성
```

## 권장 디렉터리 구조

```txt
FeatureCam/
  app/
    lib/
      app/
        feature_cam_app.dart

      camera/
        camera_session.dart
        camera_controller_service.dart
        capture_store.dart
        panorama_capture_session.dart

      effects/
        camera_effect.dart
        normal_effect.dart
        fisheye_effect.dart

      processing/
        processing_client.dart
        processing_request.dart
        processing_result.dart

      ui/
        camera_screen.dart
        camera_preview_view.dart
        capture_controls.dart
        fisheye_lens_overlay.dart
        mode_switcher.dart
        panorama_guide_overlay.dart
        panorama_capture_strip.dart
        processing_overlay.dart

  python_backend/
    app.py
    processors/
      fisheye.py
      image_processor.py
      panorama_stitcher.py
      video_processor.py
    storage/
      input/
      output/
    requirements.txt

  documents/
    camera_app_architecture.md
```

## 역할 분리

### Flutter App

Flutter는 프론트엔드 역할에 집중한다.

- 카메라 권한 요청
- 카메라 프리뷰 표시
- 사진 촬영
- 영상 녹화
- panorama용 3장 연속 촬영
- 이전 사진의 오른쪽 20%를 프리뷰 왼쪽에 반투명 overlay로 표시
- 모드 선택 UI
- Python backend 호출
- 처리 중 상태 표시
- 결과 파일 표시 및 저장

### `CameraSession`

앱의 카메라 상태를 대표한다.

- 현재 카메라
- 초기화 상태
- 권한/에러 상태
- 현재 캡처 모드
- 현재 효과
- 녹화 상태
- panorama 촬영 상태
- 처리 상태

### `CameraControllerService`

Flutter camera plugin을 감싸는 카메라 기능의 단일 진입점이다.

- `initialize()`
- `switchCamera()`
- `takePhoto()`
- `startRecording()`
- `stopRecording()`
- `dispose()`

### `PanoramaCaptureSession`

왼쪽에서 오른쪽으로 3장의 이미지를 직접 획득하기 위한 촬영 흐름을 관리한다.

- 현재 촬영 index 관리: 1/3, 2/3, 3/3
- 촬영된 원본 이미지 파일 목록 관리
- 두 번째와 세 번째 촬영 전에 이전 이미지의 오른쪽 20% crop 생성
- crop 이미지를 프리뷰 왼쪽에 높은 투명도로 표시하도록 UI에 전달
- 3장 촬영이 끝나면 `ProcessingClient.processPanorama()`를 호출한다.
- 사용자가 중간에 재촬영하거나 panorama 세션을 초기화할 수 있게 한다.

### `ProcessingClient`

Flutter와 Python backend 사이의 통신을 담당한다.

- 사진 처리 요청
- 영상 처리 요청
- panorama stitching 요청
- 처리 파라미터 전달
- 결과 파일 수신
- 에러 처리

### Python Backend

Python backend는 실제 미디어 프로세싱 엔진이다.

- `fisheye.py`: fisheye 좌표 변환 수식
- `image_processor.py`: 이미지 디코딩, fisheye 적용, 저장
- `panorama_stitcher.py`: 3장 이미지 feature matching, homography 추정, warping, blending
- `video_processor.py`: 영상 프레임별 처리, 재인코딩
- `app.py`: Flutter 앱에서 호출하는 API entrypoint

### `FisheyeLensOverlay`

fisheye 모드에서 카메라 프리뷰 위에 표시되는 조작 가능한 원형 UI다.

- 사용자는 원을 드래그해서 fisheye 중심점을 이동한다.
- 사용자는 핀치 또는 전용 슬라이더로 원의 크기를 조절한다.
- 원은 실제 저장 결과에서 fisheye 효과가 적용될 영역을 의미한다.
- 원 밖 영역은 기본적으로 원본 이미지/영상이 유지된다.
- overlay의 `centerX`, `centerY`, `radius` 값은 Python 프로세싱 요청에 그대로 전달된다.

### `PanoramaGuideOverlay`

panorama 모드에서 사용자가 다음 이미지를 충분히 겹치게 촬영하도록 돕는 UI다.

- 첫 번째 사진 촬영 후, 첫 번째 사진의 오른쪽 20%를 crop한다.
- 두 번째 촬영 화면에서는 이 crop을 카메라 프리뷰의 왼쪽 영역에 반투명하게 표시한다.
- 두 번째 사진 촬영 후, 두 번째 사진의 오른쪽 20%를 crop한다.
- 세 번째 촬영 화면에서도 같은 방식으로 이전 사진의 오른쪽 20%를 왼쪽에 표시한다.
- 사용자는 overlay와 현재 프리뷰가 자연스럽게 겹치도록 카메라를 오른쪽으로 이동한 뒤 촬영한다.
- overlay는 실제 stitching에 필요한 image overlap을 만들기 위한 촬영 가이드이며, 결과 이미지에 직접 합성되지는 않는다.

## 모드 모델

```dart
enum CaptureMode { photo, video }
enum EffectMode { normal, fisheye }
enum CameraWorkflow { singleCapture, panorama }

abstract interface class CameraEffect {
  EffectMode get mode;
}

final class NormalEffect implements CameraEffect {
  const NormalEffect();

  @override
  EffectMode get mode => EffectMode.normal;
}

final class FisheyeEffect implements CameraEffect {
  const FisheyeEffect({
    this.strength = 0.85,
    this.centerX = 0.5,
    this.centerY = 0.5,
    this.radius = 0.5,
  });

  final double strength;
  final double centerX;
  final double centerY;
  final double radius;

  @override
  EffectMode get mode => EffectMode.fisheye;
}
```

`centerX`, `centerY`, `radius`는 프리뷰 크기에 대한 정규화 값이다.

```txt
centerX: 0.0 ~ 1.0
centerY: 0.0 ~ 1.0
radius:  0.1 ~ 1.0
```

Python 처리 시에는 이 정규화 값을 실제 이미지 또는 영상 프레임 크기에 맞게 변환한다.

panorama는 `CameraWorkflow.panorama`로 진입한다. panorama workflow 안에서는 `CaptureMode.photo`만 사용하고, 정확히 3장의 원본 이미지를 순서대로 수집한다.

## 실행 흐름

### 사진

```txt
User taps shutter
  -> Flutter CameraSession.takePhoto()
  -> 원본 이미지 파일 저장
  -> effect == normal
      -> 원본 파일을 결과로 사용
  -> effect == fisheye
      -> ProcessingClient.processPhoto()
      -> Python image_processor.py
      -> fisheye.py 수식 적용
      -> 처리된 jpg 반환
  -> Flutter 결과 표시/저장
```

### 영상

```txt
User starts recording
  -> Flutter CameraSession.startRecording()
  -> 원본 mp4 녹화

User stops recording
  -> Flutter CameraSession.stopRecording()
  -> effect == normal
      -> 원본 mp4를 결과로 사용
  -> effect == fisheye
      -> ProcessingClient.processVideo()
      -> Python video_processor.py
      -> 프레임별 fisheye.py 수식 적용
      -> 처리된 mp4 반환
  -> Flutter 결과 표시/저장
```

### Panorama

```txt
User selects panorama mode
  -> PanoramaCaptureSession.start()
  -> guide state: 1/3

User captures image 1
  -> 원본 이미지 1 저장
  -> 이미지 1의 오른쪽 20% crop 생성
  -> crop을 다음 촬영 guide overlay로 설정
  -> guide state: 2/3

User captures image 2
  -> 프리뷰 왼쪽에 이미지 1의 오른쪽 20%를 반투명 overlay로 표시
  -> 사용자는 overlay와 현재 프리뷰가 겹치게 카메라를 오른쪽으로 이동
  -> 원본 이미지 2 저장
  -> 이미지 2의 오른쪽 20% crop 생성
  -> crop을 다음 촬영 guide overlay로 설정
  -> guide state: 3/3

User captures image 3
  -> 프리뷰 왼쪽에 이미지 2의 오른쪽 20%를 반투명 overlay로 표시
  -> 원본 이미지 3 저장
  -> ProcessingClient.processPanorama([image1, image2, image3])
  -> Python panorama_stitcher.py
  -> 직접 구현한 stitching pipeline 실행
  -> panorama jpg 반환
  -> Flutter 결과 표시/저장
```

## Python API 방향

초기 구현은 HTTP API가 가장 단순하다.

```txt
POST /process/photo
  input:
    - image file
    - strength
    - center_x
    - center_y
    - radius
  output:
    - processed jpg

POST /process/video
  input:
    - video file
    - strength
    - center_x
    - center_y
    - radius
  output:
    - processed mp4

POST /process/panorama
  input:
    - image_1 file
    - image_2 file
    - image_3 file
  output:
    - panorama jpg
```

Android emulator에서 로컬 Python server에 접근할 때는 `10.0.2.2`를 사용한다.

```txt
http://10.0.2.2:8000/process/photo
http://10.0.2.2:8000/process/video
http://10.0.2.2:8000/process/panorama
```

실기기 테스트에서는 같은 Wi-Fi의 개발 머신 IP를 사용하거나, 나중에 서버 배포 주소로 교체한다.

## Fisheye 처리 방향

Legacy 앱의 fisheye 수식은 출력 좌표 기준으로 중심점에서의 반지름을 구한 뒤, 원본 샘플링 반지름을 `pow(radius, exponent)`로 줄이는 방식이다.

```txt
exponent = 1 + strength
normalized_distance = distance_from_center / lens_radius
source_distance = pow(normalized_distance, exponent) * lens_radius
sample = center + direction * source_distance
```

`0 < normalized_distance < 1` 구간에서 `source_distance`가 더 작아지므로, 출력 가장자리 픽셀이 원본의 더 중심부를 샘플링한다. 이로 인해 중심부가 확대되고 가장자리가 압축되어 fisheye처럼 보인다.

fisheye 효과는 `FisheyeLensOverlay`가 표시한 원 내부에만 적용한다. 원 밖 영역은 원본 픽셀을 유지한다.

Python 구현에서는 OpenCV remap을 사용해 픽셀별 루프를 피하는 방향이 좋다.

```txt
1. 출력 이미지 좌표 grid 생성
2. center 기준 거리 계산
3. lens radius 기준 정규화 거리 계산
4. map_x, map_y 생성
5. cv2.remap()으로 샘플링
6. vignette가 필요하면 mask 적용
```

## 실시간 프리뷰 전략

Python 후처리는 실시간 프리뷰와 잘 맞지 않는다. 따라서 fisheye 효과가 실시간으로 적용된 프리뷰는 초기 버전에서 제공하지 않는다.

- 프리뷰는 일반 카메라 프리뷰를 보여준다.
- fisheye 모드에서는 프리뷰 위에 조작 가능한 원형 lens overlay를 표시한다.
- 원은 "촬영 후 이 영역이 fisheye처럼 처리된다"는 의미를 가진다.
- 사용자는 원을 움직여 fisheye 중심점을 정한다.
- 사용자는 원을 확대/축소해 fisheye 적용 범위를 정한다.
- 실제 fisheye 결과는 촬영 후 Python 처리 결과로 확인한다.
- 저장 결과의 기준은 Python 처리 결과로 둔다.

## Fisheye Lens Overlay UX

fisheye 모드에서 화면에는 반투명 원형 가이드가 표시된다.

```txt
normal mode
  - 일반 카메라 프리뷰만 표시

fisheye mode
  - 일반 카메라 프리뷰 표시
  - 원형 lens overlay 표시
  - 안내 문구 표시: 촬영 후 원 안쪽이 fisheye로 처리됨
```

조작 방식은 다음을 기본으로 한다.

- 원 내부 드래그: 중심 이동
- 두 손가락 핀치: 원 크기 조절
- 하단 슬라이더: 원 크기 미세 조절
- 더블 탭: 중심과 크기를 기본값으로 초기화

overlay 상태는 `FisheyeEffect`로 저장한다.

```txt
FisheyeEffect(
  strength: 0.85,
  centerX: 0.5,
  centerY: 0.5,
  radius: 0.5,
)
```

촬영 시점의 overlay 값을 함께 저장하거나 Python 요청에 포함한다. 이렇게 하면 사용자가 본 원형 가이드와 실제 처리 결과가 같은 기준을 공유한다.

## Panorama 촬영 UX

panorama 모드는 3장의 사진을 왼쪽에서 오른쪽 방향으로 촬영한다.

```txt
1번째 촬영
  - 일반 프리뷰만 표시
  - 촬영 후 이미지 1 저장

2번째 촬영
  - 이미지 1의 오른쪽 20%를 프리뷰 왼쪽에 반투명 overlay로 표시
  - 사용자는 overlay와 현재 화면이 겹치도록 오른쪽으로 이동
  - 촬영 후 이미지 2 저장

3번째 촬영
  - 이미지 2의 오른쪽 20%를 프리뷰 왼쪽에 반투명 overlay로 표시
  - 사용자는 overlay와 현재 화면이 겹치도록 오른쪽으로 이동
  - 촬영 후 이미지 3 저장
```

UI 구성 요소:

- 상단 상태 표시: `PANORAMA 1/3`, `PANORAMA 2/3`, `PANORAMA 3/3`
- 왼쪽 overlay 영역: 이전 사진의 오른쪽 20%
- 하단 썸네일 strip: 촬영된 3장 진행 상태
- 재촬영 버튼: 현재 단계 또는 전체 panorama 초기화
- 처리 중 overlay: 3장 촬영 후 stitching 진행 표시

overlay 표시 규칙:

- crop 기준은 이전 원본 이미지의 오른쪽 20%다.
- crop은 현재 프리뷰의 왼쪽 20% 영역에 맞춰 표시한다.
- 투명도는 사용자가 현재 프리뷰와 겹침을 볼 수 있도록 낮은 alpha로 둔다.
- overlay는 촬영 가이드일 뿐이며 Python backend에는 원본 3장을 전달한다.

## Panorama Stitching 요구사항

과제 감점 방지를 위해 다음 사항은 반드시 지킨다.

- 최소 3장의 이미지를 앱에서 직접 획득한다.
- 이미지 간 overlap이 생기도록 UI에서 guide overlay를 제공한다.
- 기본 구현은 정확히 3장의 왼쪽에서 오른쪽 방향 이미지 셋을 대상으로 한다.
- planar view stitching을 전제로 하며, 깊이 변화가 큰 장면은 피하도록 안내한다.
- Python에서 자동 정합하여 하나의 큰 이미지를 생성한다.
- `cv2.Stitcher`, `cv::Stitcher`, `createStitcher`, high-level panorama API는 사용하지 않는다.
- 단순히 high-level API를 호출해서 결과를 얻는 구현은 금지한다.

권장 직접 구현 pipeline:

```txt
1. 입력 이미지 3장 로드
2. 필요하면 동일 높이로 resize
3. feature 검출 및 descriptor 계산
   - 예: ORB 또는 SIFT
4. 인접 이미지 쌍 매칭
   - image1 <-> image2
   - image2 <-> image3
5. ratio test 또는 cross-check로 bad match 제거
6. DLT로 homography 계산
7. RANSAC을 직접 구현해 outlier 제거
8. image1, image3을 image2 기준 좌표계로 warping
9. output canvas 크기 계산
10. 세 이미지를 같은 canvas에 배치
11. overlap 영역 feather blending
12. 유효 픽셀 bounding box로 crop
13. panorama jpg 저장
```

직접 구현 범위:

- 매칭 결과 필터링 로직
- DLT 기반 homography 계산
- RANSAC 반복 및 inlier 선택
- canvas 좌표 계산
- overlap blending

사용 가능한 low-level 도구:

- `cv2.imread`, `cv2.imwrite`
- `cv2.cvtColor`
- `cv2.ORB_create` 또는 `cv2.SIFT_create`
- `cv2.BFMatcher` 또는 FLANN matcher
- `cv2.warpPerspective`
- NumPy 행렬 연산

주의할 도구:

- `cv2.findHomography`는 homography와 RANSAC을 한 번에 숨기므로, 과제에서 "직접 구현"을 강하게 요구하면 사용하지 않는다.
- `cv2.Stitcher` 계열은 사용하지 않는다.
- 자동 panorama 라이브러리는 사용하지 않는다.

## Legacy에서 가져올 점

- `photo`와 `video`, `normal`과 `fisheye`를 분리한 상태 모델
- fisheye의 `strength`, `center` 파라미터
- Android MediaStore 저장 아이디어
- 사진과 영상 저장 파일명 규칙

## Legacy에서 버릴 점

- `main.dart`에 UI, 카메라 제어, 저장, fisheye 처리 코드가 모두 섞인 구조
- Flutter ring scale 기반 fisheye 미리보기
- Android CameraX + OpenGL fisheye 동영상 backend
- iOS/macOS/web/windows 관련 구조
- Dart CPU 기반 이미지 fisheye 처리

## 최종 방향

```txt
Flutter Android App
  -> CameraSession
      -> CameraControllerService
      -> CaptureStore
      -> ProcessingClient
          -> Python Backend
              -> OpenCV/NumPy Fisheye Processor
              -> Direct Panorama Stitcher
```

이 구조는 Android 전용이라는 조건과 Python 프로세싱 과제 조건을 모두 만족하면서, Flutter 코드는 UI와 앱 상태에 집중하게 만든다.
