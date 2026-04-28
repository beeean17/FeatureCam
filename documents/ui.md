# FeatureCam UI Design

## 목적

이 문서는 FeatureCam Android 앱의 초기 UI 디자인 기준안을 기록한다. 현재 디자인은 어두운 카메라 뷰파인더 위에 최소한의 조작계를 얹는 구조이며, 사진/영상/fisheye/panorama 모드를 빠르게 전환하는 카메라 앱을 목표로 한다.

## 디자인 방향

- 전체 화면 카메라 프리뷰를 첫 화면으로 사용한다.
- UI는 검은색 반투명 바와 blur를 사용해 카메라 프리뷰를 가리지 않는다.
- 강조 색상은 amber/yellow 계열 `#FFB800`을 사용한다.
- 상단에는 설정, 모드 진입, 플래시 상태를 배치한다.
- `MODE` 버튼을 누르면 `PHOTO`, `VIDEO`, `FISHEYE`, `PANORAMA` 모드 바가 슬라이드되어 나온다.
- 하단에는 갤러리 미리보기, 셔터, 카메라 전환을 둔다.
- 셔터는 화면 하단 중앙에 가장 크게 배치한다.

## 주요 UI 구성

### Viewfinder

- 전체 화면 배경은 카메라 프리뷰가 차지한다.
- 디자인 mock에서는 도시 건물 이미지를 placeholder로 사용한다.
- 실제 앱에서는 Flutter camera preview로 대체한다.

### Top App Bar

- 위치: 화면 상단 고정
- 배경: `bg-black/20`, `backdrop-blur-md`
- 왼쪽: 설정 버튼
- 중앙: `MODE`
- 오른쪽: 플래시 버튼

### Modes Bar

- 위치: `MODE` 버튼 아래에 접힌 상태로 대기하고, 버튼을 누르면 아래로 슬라이드된다.
- 항목:
  - `PHOTO`
  - `VIDEO`
  - `FISHEYE`
  - `PANORAMA`
- 선택된 모드는 amber 색상과 하단 underline으로 표시한다.

### Bottom Controls

- 위치: 화면 하단 고정
- 배경: `#0A0A0A/90`, `backdrop-blur-xl`
- 왼쪽: 최근 촬영 이미지 thumbnail
- 중앙: 셔터 버튼
- 오른쪽: 카메라 전환 버튼

## 모드별 확장

### Fisheye Mode

기본 UI 위에 fisheye lens overlay를 추가한다.

- 일반 카메라 프리뷰는 그대로 유지한다.
- 실시간 fisheye 왜곡은 표시하지 않는다.
- 원형 overlay를 표시해 촬영 후 fisheye가 적용될 영역을 보여준다.
- 원은 드래그로 이동하고, 핀치/슬라이더로 크기 조절한다.

### Panorama Mode

기본 UI 위에 panorama guide overlay를 추가한다.

- 1번째 촬영: 일반 프리뷰만 표시한다.
- 2번째 촬영: 이전 사진의 오른쪽 20%를 현재 프리뷰 왼쪽에 반투명하게 표시한다.
- 3번째 촬영: 두 번째 사진의 오른쪽 20%를 같은 방식으로 표시한다.
- 상단 또는 프리뷰 영역에 `PANORAMA 1/3`, `2/3`, `3/3` 진행 상태를 표시한다.

## Apple-style UI Refinement

FeatureCam의 UI는 "카메라 프리뷰가 주인공이고, 조작계는 손끝에 조용히 붙어 있는" 방향으로 정리한다. Apple Camera 앱처럼 화면 전체를 설명하지 않고, 상태 변화와 조작 가능한 요소만 선명하게 드러낸다.

### Layout Rules

- 카메라 프리뷰는 항상 full-bleed로 표시한다.
- 상단/하단 바는 프리뷰 위에 떠 있지만, 카드처럼 보이지 않게 한다.
- 하단 컨트롤 영역은 엄지 조작을 기준으로 배치한다.
- 셔터는 가장 큰 터치 타깃이며 화면 하단 중앙에 고정한다.
- 모드 전환은 셔터 위 또는 상단 아래에 두되, 현재 모드만 강하게 강조한다.
- 설정, 플래시, 카메라 전환은 icon-only 버튼으로 유지한다.
- 버튼은 최소 48px 터치 영역을 가진다.
- 텍스트는 기능 설명보다 상태 표시 중심으로 사용한다.
- 둥근 floating card를 남발하지 않는다. 프리뷰 위 컨트롤은 translucent bar, icon, thin indicator 중심으로 구성한다.

### Visual Tokens

```txt
Background
  camera preview: full screen
  top scrim: black 20% to transparent
  bottom control surface: black 86% with blur

Accent
  primary amber: #FFB800
  pressed amber: #FFCC4D
  recording red: #FF453A

Text
  primary: white 95%
  secondary: white 62%
  disabled: white 28%

Stroke
  subtle: white 12%
  selected: #FFB800
  shutter: white

Blur
  top bar: 16px
  bottom bar: 24px
  mode chip background: 18px
```

### Typography

- 모드 라벨은 `Space Grotesk` 또는 Flutter 기본 구현에서는 `FontWeight.w700`, 10~12sp, uppercase로 둔다.
- 상태 라벨은 12~13sp, medium weight를 사용한다.
- 긴 설명 문장은 기본 촬영 화면에 두지 않는다.
- Fisheye와 Panorama 안내는 필요한 순간에만 짧게 표시한다.

```txt
Mode label
  size: 11sp
  weight: 700
  letter spacing: 0.08em

Status label
  size: 12sp
  weight: 600

Timer
  size: 13sp
  weight: 700
  tabular numbers: true
```

## Motion System

애니메이션은 빠르고 절제되게 사용한다. 모든 전환은 사용자의 조작이 즉시 반영된다는 느낌을 줘야 한다.

### Global Curves

Flutter 구현 시 기본 curve는 다음처럼 정의한다.

```dart
const cameraEaseOut = Cubic(0.20, 0.00, 0.00, 1.00);
const cameraEaseInOut = Cubic(0.37, 0.00, 0.13, 1.00);
const cameraSpring = Cubic(0.18, 0.89, 0.32, 1.18);
```

### Durations

```txt
Tap feedback: 90ms down, 140ms release
Icon state change: 160ms
Mode switch: 220ms
Overlay fade: 180ms
Bottom controls shift: 260ms
Processing overlay in/out: 240ms
Capture flash: 120ms
Panorama guide slide: 260ms
Fisheye lens drag response: immediate
Fisheye lens settle: 180ms
```

## Component Animation Specs

### Shutter Button

Photo mode:

```txt
Press down
  scale: 1.00 -> 0.92
  inner fill opacity: 1.00 -> 0.82
  duration: 90ms
  curve: easeOut

Release
  scale: 0.92 -> 1.00
  duration: 140ms
  curve: cameraSpring

Capture flash
  white overlay opacity: 0 -> 0.35 -> 0
  duration: 120ms
```

Video mode:

```txt
Idle
  white ring + red inner circle

Start recording
  inner circle morphs into rounded square
  color: white/red -> recording red
  duration: 220ms
  curve: cameraEaseInOut

Stop recording
  rounded square morphs back to circle
  duration: 220ms
```

### Mode Switcher

```txt
On mode change
  selected label color: white 62% -> amber
  previous label color: amber -> white 62%
  underline slides to selected item
  underline width matches selected label width
  duration: 220ms
  curve: cameraEaseInOut
```

The camera preview should not jump during mode changes. Only controls and overlays change.

### Top Controls

```txt
Icon press
  scale: 1.00 -> 0.88 -> 1.00
  background opacity: 0 -> 0.10 -> 0
  duration: 160ms
```

Flash state:

```txt
off: white 70%
on: amber
disabled: white 28%
transition: 160ms color fade
```

### Bottom Bar

```txt
Initial appear
  translateY: 24px -> 0
  opacity: 0 -> 1
  duration: 260ms
  curve: cameraEaseOut

Mode-specific controls change
  old controls fade/translate down 8px
  new controls fade/translate up from 8px
  duration: 200ms
```

## Fisheye UI Motion

Fisheye mode does not show realtime distorted pixels. Instead, it shows an interactive circular lens guide.

### Enter Fisheye Mode

```txt
Lens circle
  scale: 0.92 -> 1.00
  opacity: 0 -> 1
  duration: 220ms
  curve: cameraSpring

Background guide dim
  opacity: 0 -> 0.16
  duration: 180ms
```

### Lens Drag

```txt
During drag
  center follows finger immediately
  ring stroke becomes amber
  center dot opacity: 1

After release
  ring stroke returns to white 72%
  center dot opacity: 0.72
  duration: 180ms
```

### Lens Resize

```txt
Pinch or slider resize
  radius updates continuously
  ring scale follows radius directly
  subtle tick/haptic on min/default/max
```

### Fisheye Instruction

```txt
Text: "Circle area will be processed after capture"
Placement: above bottom controls
Appear: fade + 6px upward motion
Duration: 180ms
Auto hide: after 2.5s, unless user is dragging lens
```

Flutter copy can be localized later. In Korean UI:

```txt
촬영 후 원 안쪽이 Fisheye로 처리됩니다
```

## Panorama UI Motion

Panorama mode uses a capture guide instead of realtime processing.

### Enter Panorama Mode

```txt
Progress label
  "PANORAMA 1/3"
  fade in
  duration: 180ms

Thumbnail strip
  translateY: 12px -> 0
  opacity: 0 -> 1
  duration: 220ms
```

### After First Capture

```txt
Shutter press
  normal photo shutter animation

Captured thumbnail
  appears in strip slot 1
  scale: 0.86 -> 1.00
  duration: 180ms

Guide overlay
  previous image right 20% slides in from left
  opacity: 0 -> 0.42
  duration: 260ms
  curve: cameraEaseOut

Progress label
  "PANORAMA 1/3" -> "PANORAMA 2/3"
  crossfade
  duration: 160ms
```

### After Second Capture

```txt
Guide overlay
  old crop fades out
  new crop slides in from left
  opacity target: 0.42
  duration: 260ms

Progress label
  "PANORAMA 2/3" -> "PANORAMA 3/3"
```

### After Third Capture

```txt
Processing overlay
  dim background: opacity 0 -> 0.32
  spinner/progress indicator fade in
  text: "Stitching panorama"
  duration: 240ms

On success
  panorama preview expands from bottom thumbnail area
  opacity: 0 -> 1
  scale: 0.96 -> 1.00
  duration: 260ms
```

Korean processing copy:

```txt
파노라마를 합성하는 중
```

## State-specific UI

### Photo

- Mode label: `PHOTO`
- Shutter: white circular button
- Lens switcher visible
- Fisheye and panorama overlays hidden

### Video

- Mode label: `VIDEO`
- Shutter: red video button
- Recording timer appears in top bar after start
- Gallery and camera switch are disabled while recording

### Fisheye

- Mode label: `FISHEYE`
- Shutter: white circular button for photo, red for video if video capture is enabled
- Lens circle overlay visible
- Radius slider can appear above bottom controls
- Instruction appears briefly when entering mode

### Panorama

- Mode label: `PANORAMA`
- Shutter: white circular button
- Lens switcher hidden
- Panorama progress visible
- Thumbnail strip visible
- Previous image crop overlay visible only for step 2 and step 3

## Implementation Notes for Flutter

- Use `Stack` as the main screen root.
- Camera preview should be the first full-screen child.
- Top controls, mode switcher, overlays, and bottom controls should be separate widgets.
- Prefer `AnimatedSwitcher`, `AnimatedOpacity`, `AnimatedScale`, and `TweenAnimationBuilder` for simple transitions.
- Use `GestureDetector` for fisheye lens drag and pinch.
- Use `RepaintBoundary` around heavy overlay painters.
- Keep overlay painters stateless where possible.
- Use `HapticFeedback.lightImpact()` for shutter, mode switch, panorama step completion, and fisheye radius snap points.

Suggested widget split:

```txt
CameraScreen
  CameraPreviewView
  TopCameraBar
  ModeSwitcher
  FisheyeLensOverlay
  PanoramaGuideOverlay
  PanoramaCaptureStrip
  BottomCaptureBar
  ProcessingOverlay
```

## HTML Prototype

아래 HTML은 초기 UI 디자인 레퍼런스다. Flutter 구현 시에는 구조와 시각적 우선순위를 참고하고, 실제 코드는 Flutter widget과 Material icon/lucide icon 계열로 재구성한다.

```html
<!DOCTYPE html>

<html class="dark" lang="en"><head>
<meta charset="utf-8"/>
<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
<title>Camera Interface</title>
<script src="https://cdn.tailwindcss.com?plugins=forms,container-queries"></script>
<link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;600;700&amp;family=Inter:wght@400;500;600&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&amp;display=swap" rel="stylesheet"/>
<script id="tailwind-config">
        tailwind.config = {
            darkMode: "class",
            theme: {
                extend: {
                    "colors": {
                        "tertiary": "#e3e0df",
                        "on-primary-container": "#6b4c00",
                        "surface-bright": "#3a3939",
                        "on-tertiary-fixed": "#1b1c1c",
                        "primary-fixed-dim": "#ffba20",
                        "secondary-fixed-dim": "#c6c6c7",
                        "inverse-surface": "#e5e2e1",
                        "on-secondary-fixed-variant": "#454747",
                        "on-secondary-fixed": "#1a1c1c",
                        "outline": "#9e8f78",
                        "surface-container-lowest": "#0e0e0e",
                        "tertiary-fixed-dim": "#c8c6c5",
                        "tertiary-fixed": "#e5e2e1",
                        "inverse-on-surface": "#313030",
                        "background": "#131313",
                        "secondary-fixed": "#e2e2e2",
                        "on-error": "#690005",
                        "inverse-primary": "#7c5800",
                        "surface-dim": "#131313",
                        "on-primary": "#412d00",
                        "surface-container-highest": "#353534",
                        "on-tertiary-container": "#525151",
                        "primary-container": "#ffb800",
                        "on-background": "#e5e2e1",
                        "surface-container-low": "#1c1b1b",
                        "surface-container": "#201f1f",
                        "error-container": "#93000a",
                        "tertiary-container": "#c6c4c4",
                        "on-secondary-container": "#b4b5b5",
                        "secondary": "#c6c6c7",
                        "error": "#ffb4ab",
                        "outline-variant": "#514532",
                        "primary-fixed": "#ffdea8",
                        "on-surface": "#e5e2e1",
                        "on-surface-variant": "#d5c4ab",
                        "surface": "#131313",
                        "on-error-container": "#ffdad6",
                        "on-tertiary-fixed-variant": "#474746",
                        "on-secondary": "#2f3131",
                        "secondary-container": "#454747",
                        "surface-variant": "#353534",
                        "on-tertiary": "#303030",
                        "surface-container-high": "#2a2a2a",
                        "on-primary-fixed": "#271900",
                        "primary": "#ffdca1",
                        "surface-tint": "#ffba20",
                        "on-primary-fixed-variant": "#5e4200"
                    },
                    "borderRadius": {
                        "DEFAULT": "0.25rem",
                        "lg": "0.5rem",
                        "xl": "0.75rem",
                        "full": "9999px"
                    },
                    "spacing": {
                        "touch-target": "3rem",
                        "safe-margin": "1.5rem",
                        "one-hand-zone": "12rem",
                        "unit": "4px",
                        "gutter": "1rem"
                    },
                    "fontFamily": {
                        "label-caps": ["Space Grotesk"],
                        "headline-lg": ["Space Grotesk"],
                        "body-md": ["Inter"],
                        "mode-selector": ["Space Grotesk"],
                        "data-mono": ["Space Grotesk"]
                    },
                    "fontSize": {
                        "label-caps": ["11px", { "lineHeight": "12px", "letterSpacing": "0.08em", "fontWeight": "500" }],
                        "headline-lg": ["24px", { "lineHeight": "32px", "letterSpacing": "-0.02em", "fontWeight": "600" }],
                        "body-md": ["16px", { "lineHeight": "24px", "letterSpacing": "0em", "fontWeight": "400" }],
                        "mode-selector": ["14px", { "lineHeight": "16px", "letterSpacing": "0.1em", "fontWeight": "700" }],
                        "data-mono": ["13px", { "lineHeight": "14px", "letterSpacing": "0.02em", "fontWeight": "400" }]
                    }
                }
            }
        }
    </script>
<style>
        .material-symbols-outlined {
            font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;
        }
        .material-symbols-outlined[data-weight="fill"] {
            font-variation-settings: 'FILL' 1, 'wght' 400, 'GRAD' 0, 'opsz' 24;
        }
    </style>
<style>
    body {
      min-height: max(884px, 100dvh);
    }
  </style>
</head>
<body class="bg-background text-on-background h-screen w-screen overflow-hidden flex flex-col font-body-md text-body-md relative">
<!-- Viewfinder Background -->
<div class="absolute inset-0 z-0 bg-cover bg-center" data-alt="Modern urban landscape with tall glass skyscrapers reaching into a clear blue sky, dynamic perspective from street level looking up, high contrast and sharp details" style="background-image: url('https://lh3.googleusercontent.com/aida-public/AB6AXuAhkNbJYfiq-7-eHiv9Wkf0PVTU8Tlytw3CbNtGCoxuPoRAuy6ZsNP94ASO4lP9FVLGkm7bOcTipb2tzYuMGyepFUY8vnWzswoJt3j5aMLqDytNpbVjk7d4pucdkSNBd_L1K1FkLxaCN_2SnHjPVNzentZJZKSPzuZ9UcWPm-7b-DjHcbvFN9hK2qHjPdzXjB99fg-2H0yjpSM9-aOt4OGnY6lV6gAskvyLpzsESDXQgCyUHBEdT2zmJOunNpQ-YPqpoh-zzTKYCS0');"></div>
<!-- TopAppBar -->
<header class="fixed top-0 left-0 w-full z-50 flex justify-between items-center px-6 py-4 bg-black/20 backdrop-blur-md transition-opacity duration-200 active:opacity-60 border-none">
<button class="w-touch-target h-touch-target flex items-center justify-center text-white hover:bg-white/10 rounded-full transition-colors">
<span class="material-symbols-outlined text-2xl" data-icon="settings">settings</span>
</button>
<button class="font-label-caps text-white hover:text-[#FFB800] transition-colors uppercase tracking-widest">
MODE
</button>
<button class="w-touch-target h-touch-target flex items-center justify-center text-amber-500 hover:bg-white/10 rounded-full transition-colors">
<span class="material-symbols-outlined text-2xl" data-icon="flash_on" data-weight="fill">flash_on</span>
</button>
</header>
<!-- Modes Bar -->
<div class="absolute top-[80px] left-0 w-full z-40 flex justify-center items-center gap-6 px-4">
<a class="flex flex-col items-center justify-center text-[#FFB800] border-b-2 border-[#FFB800] pb-1 active:scale-95 transition-transform duration-150 group" href="#">
<span class="font-['Space_Grotesk'] text-[10px] font-bold tracking-tighter">PHOTO</span>
</a>
<a class="flex flex-col items-center justify-center text-gray-400 pb-1 hover:text-white active:scale-95 transition-transform duration-150 group" href="#">
<span class="font-['Space_Grotesk'] text-[10px] font-bold tracking-tighter group-hover:text-white transition-colors">VIDEO</span>
</a>
<a class="flex flex-col items-center justify-center text-gray-400 pb-1 hover:text-white active:scale-95 transition-transform duration-150 group" href="#">
<span class="font-['Space_Grotesk'] text-[10px] font-bold tracking-tighter group-hover:text-white transition-colors">FISHEYE</span>
</a>
<a class="flex flex-col items-center justify-center text-gray-400 pb-1 hover:text-white active:scale-95 transition-transform duration-150 group" href="#">
<span class="font-['Space_Grotesk'] text-[10px] font-bold tracking-tighter group-hover:text-white transition-colors">PANORAMA</span>
</a>
</div>
<!-- BottomNavBar -->
<nav class="fixed bottom-0 left-0 w-full z-50 flex justify-between items-center px-8 pb-10 pt-6 bg-[#0A0A0A]/90 backdrop-blur-xl border-t border-[#222222] rounded-t-3xl">
<!-- Secondary Action Left (Gallery Preview) -->
<button class="w-14 h-14 rounded-full bg-[#1A1A1A]/80 backdrop-blur-md border border-[#222222] overflow-hidden flex items-center justify-center transition-transform active:scale-95">
<img alt="Thumbnail" class="w-full h-full object-cover" data-alt="Small thumbnail preview of a previously taken photo showing abstract architecture lines" src="https://lh3.googleusercontent.com/aida-public/AB6AXuBkFGBNPNVTOCQLxzOyQb7Sfm1tAQ2PQTEIAcHmpRbt40szFmXv1Z1s4pWW1V1LB8bp0MojXX1cYz1fJ1eCC-DGvud2QWOWzjnsS32AjXON09vXPFe0rbwoyk93uibdj4bG0TnlyzBZMJ7uFzg0tBvPVcNNFzZnNuuCMFQBFMeQf6bVmIBHVAenvCK0vBSyPZ6UZckH3JZ4tk55wE4zJqdsw1_Wy4NWRsg1feAxnDZDlWtkkBHgQCZg35oPN0jpTICfShQytWpXbEE"/>
</button>
<!-- Shutter Button (Center) -->
<button class="w-24 h-24 rounded-full border-[3px] border-white flex items-center justify-center p-1 relative group active:scale-95 transition-transform duration-150">
<div class="w-full h-full rounded-full bg-white group-active:bg-amber-500 transition-colors duration-150 shadow-inner"></div>
<!-- Yellow accent ring -->
<div class="absolute inset-[-6px] rounded-full border border-amber-500/50 opacity-0 group-active:opacity-100 transition-opacity duration-150"></div>
</button>
<!-- Secondary Action Right (Camera Flip) -->
<button class="w-14 h-14 rounded-full bg-[#1A1A1A]/80 backdrop-blur-md border border-[#222222] flex items-center justify-center text-white transition-transform active:scale-95 hover:bg-[#353534]/80">
<span class="material-symbols-outlined text-3xl" data-icon="cameraswitch">cameraswitch</span>
</button>
</nav>
</body></html>
```
