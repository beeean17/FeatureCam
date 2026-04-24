import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../camera/camera_modes.dart';
import 'bottom_capture_bar.dart';
import 'camera_motion.dart';
import 'camera_preview_view.dart';
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
  CameraMode _mode = CameraMode.photo;
  FisheyeLensConfig _fisheyeLens = const FisheyeLensConfig();
  PanoramaCaptureState _panorama = const PanoramaCaptureState();
  double _zoom = 1;
  bool _flashEnabled = false;
  bool _isRecording = false;
  bool _showCaptureFlash = false;
  bool _isProcessing = false;
  bool _isModeBarOpen = false;

  void _setMode(CameraMode mode) {
    if (_isProcessing) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      if (_mode != mode) {
        _mode = mode;
      }
      _isModeBarOpen = false;
      _isRecording = false;
      if (mode != CameraMode.panorama) {
        _panorama = const PanoramaCaptureState();
      }
    });
  }

  void _toggleModeBar() {
    if (_isProcessing) {
      return;
    }

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

  Future<void> _handleShutter() async {
    if (_isProcessing) {
      return;
    }

    HapticFeedback.lightImpact();

    if (_mode == CameraMode.video) {
      setState(() {
        _isRecording = !_isRecording;
      });
      return;
    }

    if (_mode == CameraMode.panorama) {
      await _capturePanoramaStep();
      return;
    }

    await _runPhotoFlash();
  }

  Future<void> _capturePanoramaStep() async {
    await _runPhotoFlash();
    final nextCount = (_panorama.capturedCount + 1).clamp(0, 3);
    setState(() {
      _panorama = PanoramaCaptureState(
        capturedCount: nextCount,
        guideVisible: nextCount > 0 && nextCount < 3,
      );
    });

    if (nextCount == 3) {
      await _showProcessingFor(const Duration(milliseconds: 900));
      if (!mounted) {
        return;
      }
      setState(() {
        _panorama = const PanoramaCaptureState();
      });
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

  Future<void> _showProcessingFor(Duration duration) async {
    setState(() {
      _isProcessing = true;
    });
    await Future<void>.delayed(duration);
    if (!mounted) {
      return;
    }
    setState(() {
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.paddingOf(context);
    final layout = _CameraLayoutSpec.fromSafePadding(safePadding);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CameraPreviewView(mode: _mode, zoom: _zoom),
          ),
          Positioned.fill(
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
            left: 0,
            right: 0,
            top: 0,
            height: layout.topBarHeight,
            child: SafeArea(
              bottom: false,
              child: TopCameraBar(
                flashEnabled: _flashEnabled,
                isRecording: _isRecording,
                isModeBarOpen: _isModeBarOpen,
                onSettingsPressed: () {},
                onModePressed: _toggleModeBar,
                onFlashPressed: _toggleFlash,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: layout.modeBarTop,
            height: layout.modeBarHeight,
            child: ModeSwitcher(
              selectedMode: _mode,
              isOpen: _isModeBarOpen,
              onModeSelected: _setMode,
            ),
          ),
          if (_mode == CameraMode.fisheye)
            Positioned(
              left: 0,
              right: 0,
              top: layout.overlayTop,
              bottom: layout.overlayBottom,
              child: FisheyeLensOverlay(
                lens: _fisheyeLens,
                onChanged: _updateFisheyeLens,
              ),
            ),
          if (_mode == CameraMode.panorama)
            Positioned(
              left: 0,
              right: 0,
              top: layout.overlayTop,
              bottom: layout.overlayBottom,
              child: PanoramaGuideOverlay(state: _panorama),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: layout.secondaryControlsBottom,
            height: layout.secondaryControlsHeight,
            child: Center(
              child: AnimatedSwitcher(
                duration: CameraMotion.controlShift,
                switchInCurve: CameraMotion.cameraEaseOut,
                switchOutCurve: CameraMotion.cameraEaseInOut,
                child: _mode != CameraMode.panorama
                    ? const SizedBox.shrink(key: ValueKey('empty-lens-space'))
                    : PanoramaCaptureStrip(
                        key: const ValueKey('panorama-strip'),
                        state: _panorama,
                        onReset: () {
                          setState(() {
                            _panorama = const PanoramaCaptureState();
                          });
                        },
                      ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: layout.bottomBarHeight,
            child: BottomCaptureBar(
              mode: _mode,
              isRecording: _isRecording,
              onShutterPressed: _handleShutter,
              onGalleryPressed: () {},
              onSwitchCameraPressed: () {},
            ),
          ),
          Positioned.fill(
            child: ProcessingOverlay(
              isVisible: _isProcessing,
              label: _mode == CameraMode.panorama ? '파노라마를 합성하는 중' : '처리하는 중',
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraLayoutSpec {
  const _CameraLayoutSpec({
    required this.topBarHeight,
    required this.modeBarTop,
    required this.modeBarHeight,
    required this.overlayTop,
    required this.overlayBottom,
    required this.secondaryControlsBottom,
    required this.secondaryControlsHeight,
    required this.bottomBarHeight,
  });

  final double topBarHeight;
  final double modeBarTop;
  final double modeBarHeight;
  final double overlayTop;
  final double overlayBottom;
  final double secondaryControlsBottom;
  final double secondaryControlsHeight;
  final double bottomBarHeight;

  factory _CameraLayoutSpec.fromSafePadding(EdgeInsets safePadding) {
    const topControlsHeight = 64.0;
    const modeBarGap = 8.0;
    const modeBarHeight = 54.0;
    const bottomControlsContentHeight = 140.0;
    const secondaryControlsGap = 18.0;
    const secondaryControlsHeight = 58.0;

    final topBarHeight = safePadding.top + topControlsHeight;
    final bottomBarHeight = safePadding.bottom + bottomControlsContentHeight;
    final secondaryControlsBottom = bottomBarHeight + secondaryControlsGap;

    return _CameraLayoutSpec(
      topBarHeight: topBarHeight,
      modeBarTop: topBarHeight + modeBarGap,
      modeBarHeight: modeBarHeight,
      overlayTop: topBarHeight + modeBarGap + modeBarHeight + 8,
      overlayBottom: secondaryControlsBottom + secondaryControlsHeight + 12,
      secondaryControlsBottom: secondaryControlsBottom,
      secondaryControlsHeight: secondaryControlsHeight,
      bottomBarHeight: bottomBarHeight,
    );
  }
}
