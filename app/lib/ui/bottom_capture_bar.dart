import 'dart:ui';

import 'package:flutter/material.dart';

import '../camera/camera_modes.dart';
import 'camera_motion.dart';
import 'camera_theme.dart';

class BottomCaptureBar extends StatelessWidget {
  const BottomCaptureBar({
    super.key,
    required this.mode,
    required this.isRecording,
    required this.onShutterPressed,
    required this.onGalleryPressed,
    required this.onSwitchCameraPressed,
  });

  final CameraMode mode;
  final bool isRecording;
  final VoidCallback onShutterPressed;
  final VoidCallback onGalleryPressed;
  final VoidCallback onSwitchCameraPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: FeatureCamColors.surface,
              border: Border(
                top: BorderSide(color: FeatureCamColors.strokeSubtle),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 18, 30, 26),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ThumbnailButton(onPressed: onGalleryPressed),
                    ShutterButton(
                      mode: mode,
                      isRecording: isRecording,
                      onPressed: onShutterPressed,
                    ),
                    _RoundIconButton(
                      icon: Icons.cameraswitch_rounded,
                      onPressed: isRecording ? null : onSwitchCameraPressed,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShutterButton extends StatefulWidget {
  const ShutterButton({
    super.key,
    required this.mode,
    required this.isRecording,
    required this.onPressed,
  });

  final CameraMode mode;
  final bool isRecording;
  final VoidCallback onPressed;

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton> {
  bool _pressed = false;

  bool get _isVideo => widget.mode == CameraMode.video;

  @override
  Widget build(BuildContext context) {
    final innerSize = widget.isRecording ? 36.0 : 76.0;
    final innerRadius = widget.isRecording ? 9.0 : 999.0;
    final innerColor = _isVideo
        ? FeatureCamColors.recordingRed
        : FeatureCamColors.white;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: _pressed ? CameraMotion.tapDown : CameraMotion.tapRelease,
        curve: CameraMotion.cameraSpring,
        child: SizedBox.square(
          dimension: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: CameraMotion.modeSwitch,
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FeatureCamColors.white.withValues(alpha: 0.92),
                    width: 3,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: CameraMotion.modeSwitch,
                curve: CameraMotion.cameraEaseInOut,
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  color: innerColor,
                  borderRadius: BorderRadius.circular(innerRadius),
                ),
              ),
              AnimatedOpacity(
                duration: CameraMotion.tapRelease,
                opacity: _pressed ? 1 : 0,
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: FeatureCamColors.amber.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailButton extends StatelessWidget {
  const _ThumbnailButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: FeatureCamColors.strokeSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(painter: _ThumbnailPainter()),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedOpacity(
        duration: CameraMotion.iconState,
        opacity: onPressed == null ? 0.35 : 1,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: FeatureCamColors.surfaceSoft,
            shape: BoxShape.circle,
            border: Border.all(color: FeatureCamColors.strokeSubtle),
          ),
          child: Icon(icon, color: FeatureCamColors.white, size: 28),
        ),
      ),
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF222625),
    );
    canvas.drawCircle(
      Offset(size.width * 0.68, size.height * 0.28),
      size.width * 0.18,
      Paint()..color = FeatureCamColors.amber.withValues(alpha: 0.8),
    );
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.42, size.height * 0.48)
      ..lineTo(size.width * 0.72, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF3C4743));
    final path2 = Path()
      ..moveTo(size.width * 0.34, size.height)
      ..lineTo(size.width * 0.72, size.height * 0.42)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path2, Paint()..color = const Color(0xFF52625D));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
