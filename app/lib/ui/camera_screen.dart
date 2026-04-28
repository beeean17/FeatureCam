import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../camera/camera_controller_service.dart';
import '../camera/camera_modes.dart';
import '../camera/capture_store.dart';
import '../processing/processing_client.dart';
import 'bottom_capture_bar.dart';
import 'camera_motion.dart';
import 'camera_preview_view.dart';
import 'camera_theme.dart';
import 'feature_cam_gallery_screen.dart';
import 'fisheye_lens_overlay.dart';
import 'mode_switcher.dart';
import 'panorama_guide_overlay.dart';
import 'processing_overlay.dart';
import 'top_camera_bar.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final CameraControllerService _cameraService = CameraControllerService();
  final CaptureStore _captureStore = CaptureStore();
  final ProcessingClient _processingClient = ProcessingClient();
  final List<File> _panoramaFiles = [];
  final EventChannel _orientationChannel = const EventChannel(
    'feature_cam/orientation',
  );

  CameraMode _mode = CameraMode.photo;
  FisheyeLensConfig _fisheyeLens = const FisheyeLensConfig();
  PanoramaCaptureState _panorama = const PanoramaCaptureState();
  bool _flashEnabled = false;
  bool _isRecording = false;
  bool _isInitializingCamera = true;
  bool _showCaptureFlash = false;
  bool _isProcessing = false;
  bool _isModeBarOpen = false;
  int _backgroundJobCount = 0;
  String? _cameraError;
  File? _lastCapture;
  File? _panoramaGuideImage;
  Offset? _focusIndicatorPoint;
  Timer? _focusIndicatorTimer;
  StreamSubscription<dynamic>? _orientationSubscription;
  int _controlQuarterTurns = 0;
  double _controlTurns = 0;
  double _captureAspectRatio = 3 / 4;

  @override
  void initState() {
    super.initState();
    _startOrientationUpdates();
    _initializeCamera();
  }

  @override
  void dispose() {
    _focusIndicatorTimer?.cancel();
    _orientationSubscription?.cancel();
    _processingClient.close();
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializingCamera = true;
      _cameraError = null;
    });

    try {
      await _cameraService.initialize();
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializingCamera = false;
        _cameraError = null;
      });
    } on CameraException catch (error) {
      _setCameraFailure(error.description ?? error.code);
    } catch (error) {
      _setCameraFailure(error.toString());
    }
  }

  void _setMode(CameraMode mode) {
    HapticFeedback.selectionClick();
    setState(() {
      _mode = mode;
      _isModeBarOpen = false;
      _isRecording = false;
      if (mode != CameraMode.panorama) {
        _resetPanorama();
      }
    });
  }

  void _toggleModeBar() {
    HapticFeedback.selectionClick();
    setState(() {
      _isModeBarOpen = !_isModeBarOpen;
    });
  }

  void _toggleFlash() {
    HapticFeedback.selectionClick();
    setState(() {
      _flashEnabled = !_flashEnabled;
    });
  }

  void _updateFisheyeLens(FisheyeLensConfig lens) {
    setState(() {
      _fisheyeLens = lens;
    });
  }

  void _handlePreviewTap(
    TapUpDetails details,
    Size previewSize,
    Offset previewOrigin,
  ) {
    if (!_cameraService.isReady || _isInitializingCamera) {
      return;
    }

    final localPosition = details.localPosition;
    final normalizedPoint = Offset(
      localPosition.dx / previewSize.width,
      localPosition.dy / previewSize.height,
    );
    HapticFeedback.selectionClick();
    setState(() {
      _focusIndicatorPoint = previewOrigin + localPosition;
    });
    _focusIndicatorTimer?.cancel();
    _focusIndicatorTimer = Timer(CameraMotion.focusIndicator, () {
      if (mounted) {
        setState(() {
          _focusIndicatorPoint = null;
        });
      }
    });
    unawaited(_cameraService.focusAt(normalizedPoint));
  }

  Future<void> _handleShutter() async {
    if (_isInitializingCamera) {
      return;
    }

    HapticFeedback.lightImpact();

    switch (_mode) {
      case CameraMode.photo:
        await _captureNormalPhoto();
      case CameraMode.video:
        await _toggleVideoRecording();
      case CameraMode.fisheye:
        await _captureFisheyePhoto();
      case CameraMode.panorama:
        await _capturePanoramaStep();
    }
  }

  Future<void> _captureNormalPhoto() async {
    try {
      await _runPhotoFlash();
      final rawPhoto = await _cameraService.takePhoto(
        captureOrientation: _captureOrientation(),
      );
      final output = await _captureStore.copyOriginal(
        rawPhoto,
        mode: CameraMode.photo,
        kind: 'photo',
        cropToCaptureFrame: true,
        cropAspectRatio: _captureCropAspectRatio(),
      );
      _setLastCapture(output, '사진 저장됨');
    } catch (error) {
      _showStatus('사진을 저장할 수 없습니다: $error');
    }
  }

  Future<void> _captureFisheyePhoto() async {
    try {
      await _runPhotoFlash();
      final rawPhoto = await _cameraService.takePhoto(
        captureOrientation: _captureOrientation(),
      );
      final original = await _captureStore.copyOriginal(
        rawPhoto,
        mode: CameraMode.fisheye,
        kind: 'photo',
        cropToCaptureFrame: true,
        cropAspectRatio: _captureCropAspectRatio(),
      );
      _runBackgroundProcessing(
        startedMessage: 'Fisheye 처리 시작됨',
        task: () async {
          final output = await _captureStore.createCaptureFile(
            mode: CameraMode.fisheye,
            kind: 'photo',
            extension: 'jpg',
            processed: true,
          );
          return _processingClient.processPhoto(
            image: original,
            output: output,
            lens: _fisheyeLens,
          );
        },
        successMessage: 'Fisheye 사진 저장됨',
        failurePrefix: 'Fisheye 처리 실패',
      );
    } catch (error) {
      _showStatus('Fisheye 촬영 실패: $error');
    }
  }

  Future<void> _toggleVideoRecording() async {
    try {
      if (_isRecording) {
        final rawVideo = await _cameraService.stopVideoRecording();
        final output = await _captureStore.copyOriginal(
          rawVideo,
          mode: CameraMode.video,
          kind: 'video',
        );
        _setLastCapture(output, '영상 저장됨');
        if (_mode == CameraMode.fisheye) {
          _runBackgroundProcessing(
            startedMessage: 'Fisheye 영상 처리 시작됨',
            task: () async {
              final processed = await _captureStore.createCaptureFile(
                mode: CameraMode.fisheye,
                kind: 'video',
                extension: 'mp4',
                processed: true,
              );
              return _processingClient.processVideo(
                video: output,
                output: processed,
                lens: _fisheyeLens,
              );
            },
            successMessage: 'Fisheye 영상 저장됨',
            failurePrefix: 'Fisheye 영상 처리 실패',
          );
        }
        if (!mounted) {
          return;
        }
        setState(() {
          _isRecording = false;
        });
        return;
      }

      await _cameraService.startVideoRecording(
        captureOrientation: _captureOrientation(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = true;
      });
    } catch (error) {
      _showStatus('영상 녹화를 처리할 수 없습니다: $error');
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
    }
  }

  Future<void> _capturePanoramaStep() async {
    try {
      await _runPhotoFlash();
      final rawPhoto = await _cameraService.takePhoto();
      final original = await _captureStore.copyOriginal(
        rawPhoto,
        mode: CameraMode.panorama,
        kind: 'photo',
        cropToCaptureFrame: true,
        cropAspectRatio: _captureCropAspectRatio(),
      );
      _panoramaFiles.add(original);

      final nextCount = _panoramaFiles.length.clamp(0, 3);
      setState(() {
        _panorama = PanoramaCaptureState(
          capturedCount: nextCount,
          guideVisible: nextCount > 0 && nextCount < 3,
        );
        _panoramaGuideImage = nextCount > 0 && nextCount < 3 ? original : null;
      });

      if (nextCount == 3) {
        final panoramaInputs = List<File>.unmodifiable(_panoramaFiles);
        setState(_resetPanorama);
        _runBackgroundProcessing(
          startedMessage: '파노라마 합성 시작됨',
          task: () async {
            final output = await _captureStore.createCaptureFile(
              mode: CameraMode.panorama,
              kind: 'photo',
              extension: 'jpg',
              processed: true,
            );
            return _processingClient.processPanorama(
              images: panoramaInputs,
              output: output,
            );
          },
          successMessage: '파노라마 저장됨',
          failurePrefix: '파노라마 합성 실패',
        );
      }
    } catch (error) {
      _showStatus('파노라마 촬영/처리 실패: $error');
    }
  }

  void _runBackgroundProcessing({
    required String startedMessage,
    required Future<File> Function() task,
    required String successMessage,
    required String failurePrefix,
  }) {
    _backgroundJobCount += 1;
    setState(() {
      _isProcessing = true;
    });
    _showStatus(startedMessage);

    () async {
      try {
        await _processingClient.checkHealth();
        final output = await task();
        await _captureStore.saveToDcim(output);
        _setLastCapture(output, successMessage);
      } catch (error) {
        _showStatus('$failurePrefix: $error');
      } finally {
        _backgroundJobCount = (_backgroundJobCount - 1).clamp(0, 999);
        if (mounted) {
          setState(() {
            _isProcessing = _backgroundJobCount > 0;
          });
        }
      }
    }();
  }

  Future<void> _switchCamera() async {
    if (_isRecording) {
      return;
    }

    try {
      setState(() {
        _isInitializingCamera = true;
      });
      await _cameraService.switchCamera();
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializingCamera = false;
        _cameraError = null;
      });
    } catch (error) {
      _setCameraFailure(error.toString());
    }
  }

  Future<void> _runPhotoFlash() async {
    setState(() {
      _showCaptureFlash = true;
    });
    await Future<void>.delayed(CameraMotion.captureFlash);
    if (!mounted) {
      return;
    }
    setState(() {
      _showCaptureFlash = false;
    });
  }

  void _setCameraFailure(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isInitializingCamera = false;
      _cameraError = message;
    });
  }

  void _setLastCapture(File output, String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _lastCapture = output;
    });
    _showStatus(message);
  }

  void _showStatus(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _resetPanorama() {
    _panorama = const PanoramaCaptureState();
    _panoramaFiles.clear();
    _panoramaGuideImage = null;
  }

  void _startOrientationUpdates() {
    _orientationSubscription = _orientationChannel.receiveBroadcastStream().listen(
      (value) {
        final nextQuarterTurns = switch (value) {
          int turns => turns,
          num turns => turns.toInt(),
          _ => 0,
        };
        final normalizedQuarterTurns = nextQuarterTurns % 4;
        if (!mounted || normalizedQuarterTurns == _controlQuarterTurns) {
          return;
        }
        final nextTurns = CameraMotion.naturalOrientationTurns(
          quarterTurns: normalizedQuarterTurns,
          fromTurns: _controlTurns,
        );
        setState(() {
          _controlQuarterTurns = normalizedQuarterTurns;
          _controlTurns = nextTurns;
        });
      },
      onError: (_) {
        // Sensor rotation is a presentation enhancement; the camera still works.
      },
    );
  }

  void _openGallery() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const FeatureCamGalleryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isDeviceLandscape =
        _controlQuarterTurns == 1 || _controlQuarterTurns == 3;
    final layout = _CameraLayoutSpec.fromSafePadding(
      safePadding,
      isLandscape: isLandscape,
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final captureFrame = _CaptureFrameSpec.fromScreen(
            Size(constraints.maxWidth, constraints.maxHeight),
            layout: layout,
            isLandscape: isLandscape,
          );
          _captureAspectRatio =
              captureFrame.rect.width / captureFrame.rect.height;

          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              Positioned.fromRect(
                rect: captureFrame.rect,
                child: LayoutBuilder(
                  builder: (context, previewConstraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _handlePreviewTap(
                        details,
                        Size(
                          previewConstraints.maxWidth,
                          previewConstraints.maxHeight,
                        ),
                        captureFrame.rect.topLeft,
                      ),
                      child: CameraPreviewView(
                        mode: _mode,
                        controller: _cameraService.controller,
                        errorMessage: _cameraError,
                        isInitializing: _isInitializingCamera,
                      ),
                    );
                  },
                ),
              ),
              Positioned.fromRect(
                rect: captureFrame.rect,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _showCaptureFlash ? 0.35 : 0,
                    duration: CameraMotion.captureFlash,
                    curve: CameraMotion.cameraEaseOut,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                left: isLandscape ? null : 0,
                right: isLandscape ? layout.bottomBarSideWidth : 0,
                top: isLandscape ? 0 : null,
                bottom: isLandscape ? 0 : layout.controlBarBottom,
                width: isLandscape ? layout.controlBarSideWidth : null,
                height: isLandscape ? null : layout.controlBarHeight,
                child: TopCameraBar(
                  flashEnabled: _flashEnabled,
                  isRecording: _isRecording,
                  isModeBarOpen: _isModeBarOpen,
                  selectedMode: _mode,
                  onSettingsPressed: () {},
                  onModePressed: _toggleModeBar,
                  onFlashPressed: _toggleFlash,
                  isLandscape: isLandscape,
                  contentTurns: _controlTurns,
                ),
              ),
              Positioned(
                left: isLandscape ? null : 0,
                right: isLandscape ? layout.modeBarRight : 0,
                top: isLandscape ? 0 : null,
                bottom: isLandscape ? 0 : layout.modeBarBottom,
                width: isLandscape ? layout.modeBarSideWidth : null,
                height: isLandscape ? null : layout.modeBarHeight,
                child: ModeSwitcher(
                  selectedMode: _mode,
                  isOpen: _isModeBarOpen,
                  onModeSelected: _setMode,
                  isLandscape: isLandscape,
                  contentTurns: _controlTurns,
                ),
              ),
              if (_mode == CameraMode.fisheye)
                Positioned.fromRect(
                  rect: captureFrame.rect,
                  child: FisheyeLensOverlay(
                    lens: _fisheyeLens,
                    onChanged: _updateFisheyeLens,
                  ),
                ),
              if (_mode == CameraMode.panorama)
                Positioned.fromRect(
                  rect: captureFrame.rect,
                  child: PanoramaGuideOverlay(
                    state: _panorama,
                    guideImage: _panoramaGuideImage,
                    orientationQuarterTurns: _controlQuarterTurns,
                  ),
                ),
              if (_focusIndicatorPoint != null)
                Positioned(
                  left: _focusIndicatorPoint!.dx - 32,
                  top: _focusIndicatorPoint!.dy - 32,
                  width: 64,
                  height: 64,
                  child: IgnorePointer(
                    child: _FocusIndicator(key: ValueKey(_focusIndicatorPoint)),
                  ),
                ),
              Positioned(
                left: isLandscape
                    ? null
                    : isDeviceLandscape
                    ? (_controlQuarterTurns == 1 ? -64 : null)
                    : 0,
                right: isLandscape
                    ? layout.secondaryControlsRight
                    : isDeviceLandscape
                    ? (_controlQuarterTurns == 3 ? -64 : null)
                    : 0,
                top: isLandscape
                    ? 0
                    : isDeviceLandscape
                    ? 0
                    : null,
                bottom: isLandscape
                    ? 0
                    : isDeviceLandscape
                    ? 0
                    : layout.secondaryControlsBottom,
                width: isLandscape
                    ? layout.secondaryControlsHeight
                    : isDeviceLandscape
                    ? 224
                    : null,
                height: isLandscape || isDeviceLandscape
                    ? null
                    : layout.secondaryControlsHeight,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: CameraMotion.controlShift,
                    switchInCurve: CameraMotion.cameraEaseOut,
                    switchOutCurve: CameraMotion.cameraEaseInOut,
                    child: _mode != CameraMode.panorama
                        ? const SizedBox.shrink(
                            key: ValueKey('empty-lens-space'),
                          )
                        : PanoramaCaptureStrip(
                            key: const ValueKey('panorama-strip'),
                            state: _panorama,
                            onReset: () => setState(_resetPanorama),
                          ),
                  ),
                ),
              ),
              Positioned(
                left: isLandscape ? null : 0,
                right: 0,
                top: isLandscape ? 0 : null,
                bottom: 0,
                width: isLandscape ? layout.bottomBarSideWidth : null,
                height: isLandscape ? null : layout.bottomBarHeight,
                child: BottomCaptureBar(
                  mode: _mode,
                  isRecording: _isRecording,
                  onShutterPressed: _handleShutter,
                  onGalleryPressed: _openGallery,
                  onSwitchCameraPressed: _switchCamera,
                  lastCapture: _lastCapture,
                  isLandscape: isLandscape,
                  contentTurns: _controlTurns,
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: layout.processingTop,
                child: ProcessingOverlay(
                  isVisible: _isProcessing,
                  label: _mode == CameraMode.panorama
                      ? '파노라마를 합성하는 중'
                      : '처리하는 중',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  DeviceOrientation _captureOrientation() {
    return switch (_controlQuarterTurns) {
      1 => DeviceOrientation.landscapeRight,
      2 => DeviceOrientation.portraitDown,
      3 => DeviceOrientation.landscapeLeft,
      _ => DeviceOrientation.portraitUp,
    };
  }

  double _captureCropAspectRatio() {
    if (_controlQuarterTurns == 1 || _controlQuarterTurns == 3) {
      return 1 / _captureAspectRatio;
    }
    return _captureAspectRatio;
  }
}

class _FocusIndicator extends StatelessWidget {
  const _FocusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.18, end: 1),
      duration: CameraMotion.focusIndicator,
      curve: CameraMotion.cameraEaseOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FeatureCamColors.amber, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: FeatureCamColors.amber.withValues(alpha: 0.22),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: FeatureCamColors.amber,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CaptureFrameSpec {
  const _CaptureFrameSpec({required this.rect});

  final Rect rect;

  static _CaptureFrameSpec fromScreen(
    Size screenSize, {
    required _CameraLayoutSpec layout,
    required bool isLandscape,
  }) {
    const landscapeRatio = 4 / 3;

    if (isLandscape) {
      final maxWidth =
          screenSize.width -
          layout.bottomBarSideWidth -
          layout.controlBarSideWidth;
      final availableWidth = math.max(0.0, maxWidth);
      var height = screenSize.height;
      var width = height * landscapeRatio;
      if (width > availableWidth) {
        width = availableWidth;
        height = width / landscapeRatio;
      }
      return _CaptureFrameSpec(
        rect: Rect.fromLTWH(0, (screenSize.height - height) / 2, width, height),
      );
    }

    final frameTop = layout.overlayTop;
    const frameBottomGap = 0.0;
    final lowerControlTop =
        screenSize.height - layout.controlBarBottom - layout.controlBarHeight;
    final frameBottom = lowerControlTop - frameBottomGap;
    final availableHeight = math.max(1.0, frameBottom - frameTop);
    return _CaptureFrameSpec(
      rect: Rect.fromLTWH(0, frameTop, screenSize.width, availableHeight),
    );
  }
}

class _CameraLayoutSpec {
  const _CameraLayoutSpec({
    required this.controlBarBottom,
    required this.controlBarHeight,
    required this.controlBarSideWidth,
    required this.modeBarBottom,
    required this.modeBarHeight,
    required this.modeBarRight,
    required this.modeBarSideWidth,
    required this.overlayTop,
    required this.overlayBottom,
    required this.overlayRight,
    required this.secondaryControlsBottom,
    required this.secondaryControlsRight,
    required this.secondaryControlsHeight,
    required this.bottomBarHeight,
    required this.bottomBarSideWidth,
    required this.processingTop,
  });

  final double controlBarBottom;
  final double controlBarHeight;
  final double controlBarSideWidth;
  final double modeBarBottom;
  final double modeBarHeight;
  final double modeBarRight;
  final double modeBarSideWidth;
  final double overlayTop;
  final double overlayBottom;
  final double overlayRight;
  final double secondaryControlsBottom;
  final double secondaryControlsRight;
  final double secondaryControlsHeight;
  final double bottomBarHeight;
  final double bottomBarSideWidth;
  final double processingTop;

  factory _CameraLayoutSpec.fromSafePadding(
    EdgeInsets safePadding, {
    required bool isLandscape,
  }) {
    const controlBarHeight = 48.0;
    const controlBarSideWidth = 54.0;
    const modeBarGap = 6.0;
    const modeBarHeight = 54.0;
    const modeBarSideWidth = 112.0;
    const bottomControlsContentHeight = 140.0;
    const bottomControlsSideWidth = 132.0;
    const secondaryControlsGap = 10.0;
    const secondaryControlsHeight = 58.0;

    final bottomBarHeight = safePadding.bottom + bottomControlsContentHeight;
    final bottomBarSideWidth = safePadding.right + bottomControlsSideWidth;
    final modeBarBottom = bottomBarHeight + controlBarHeight + modeBarGap;
    final modeBarRight = bottomBarSideWidth + controlBarSideWidth + modeBarGap;
    final secondaryControlsBottom =
        modeBarBottom + modeBarHeight + secondaryControlsGap;
    final secondaryControlsRight =
        modeBarRight + modeBarSideWidth + secondaryControlsGap;

    return _CameraLayoutSpec(
      controlBarBottom: bottomBarHeight,
      controlBarHeight: controlBarHeight,
      controlBarSideWidth: controlBarSideWidth,
      modeBarBottom: modeBarBottom,
      modeBarHeight: modeBarHeight,
      modeBarRight: modeBarRight,
      modeBarSideWidth: modeBarSideWidth,
      overlayTop: safePadding.top + 12,
      overlayBottom: isLandscape
          ? safePadding.bottom + 12
          : secondaryControlsBottom + secondaryControlsHeight + 12,
      overlayRight: isLandscape
          ? bottomBarSideWidth + controlBarSideWidth + 12
          : 0,
      secondaryControlsBottom: secondaryControlsBottom,
      secondaryControlsRight: secondaryControlsRight,
      secondaryControlsHeight: secondaryControlsHeight,
      bottomBarHeight: bottomBarHeight,
      bottomBarSideWidth: bottomBarSideWidth,
      processingTop: safePadding.top + 14,
    );
  }
}
