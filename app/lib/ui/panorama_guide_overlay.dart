import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../camera/camera_modes.dart';
import 'camera_motion.dart';
import 'camera_theme.dart';

class PanoramaGuideOverlay extends StatelessWidget {
  const PanoramaGuideOverlay({super.key, required this.state});

  final PanoramaCaptureState state;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(child: _ProgressPill(step: state.step)),
              ),
              AnimatedPositioned(
                duration: CameraMotion.panoramaGuide,
                curve: CameraMotion.cameraEaseOut,
                left: state.guideVisible ? 0 : -96,
                top: 0,
                bottom: 0,
                width: constraints.maxWidth * 0.22,
                child: AnimatedOpacity(
                  duration: CameraMotion.panoramaGuide,
                  opacity: state.guideVisible ? 1 : 0,
                  child: const _PreviousFrameGuide(),
                ),
              ),
              if (state.guideVisible)
                Positioned(
                  left: 18,
                  top: constraints.maxHeight * 0.43,
                  child: const Icon(
                    Icons.keyboard_double_arrow_left_rounded,
                    color: FeatureCamColors.amber,
                    size: 28,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class PanoramaCaptureStrip extends StatelessWidget {
  const PanoramaCaptureStrip({
    super.key,
    required this.state,
    required this.onReset,
  });

  final PanoramaCaptureState state;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: FeatureCamColors.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: FeatureCamColors.strokeSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  _PanoramaSlot(
                    index: i,
                    isFilled: i < state.capturedCount,
                    isCurrent: i == state.capturedCount && !state.isComplete,
                  ),
                  if (i != 2) const SizedBox(width: 8),
                ],
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onReset,
                  child: const SizedBox.square(
                    dimension: 34,
                    child: Icon(
                      Icons.refresh_rounded,
                      color: FeatureCamColors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: FeatureCamColors.surface.withValues(alpha: 0.64),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: FeatureCamColors.strokeSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: AnimatedSwitcher(
              duration: CameraMotion.iconState,
              child: Text(
                'PANORAMA $step/3',
                key: ValueKey(step),
                style: const TextStyle(
                  color: FeatureCamColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviousFrameGuide extends StatelessWidget {
  const _PreviousFrameGuide();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PreviousFramePainter());
  }
}

class _PanoramaSlot extends StatelessWidget {
  const _PanoramaSlot({
    required this.index,
    required this.isFilled,
    required this.isCurrent,
  });

  final int index;
  final bool isFilled;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: CameraMotion.modeSwitch,
      curve: CameraMotion.cameraSpring,
      width: 42,
      height: 28,
      decoration: BoxDecoration(
        color: isFilled
            ? FeatureCamColors.amber.withValues(alpha: 0.9)
            : FeatureCamColors.surfaceSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCurrent
              ? FeatureCamColors.amber
              : FeatureCamColors.strokeSubtle,
        ),
      ),
      child: Center(
        child: isFilled
            ? const Icon(
                Icons.check_rounded,
                color: Color(0xFF271900),
                size: 17,
              )
            : Text(
                '${index + 1}',
                style: TextStyle(
                  color: isCurrent
                      ? FeatureCamColors.amber
                      : FeatureCamColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

class _PreviousFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          FeatureCamColors.amber.withValues(alpha: 0.46),
          FeatureCamColors.amber.withValues(alpha: 0.18),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final stripe = Paint()
      ..color = FeatureCamColors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1.2;
    for (var y = -size.height; y < size.height * 2; y += 28) {
      canvas.drawLine(
        Offset(0, y.toDouble()),
        Offset(size.width, y + size.width * 0.8),
        stripe,
      );
    }

    final edge = Paint()
      ..color = FeatureCamColors.amber
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width - 1, 0),
      Offset(size.width - 1, size.height),
      edge,
    );

    final dots = Paint()
      ..color = FeatureCamColors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 18; i++) {
      final y = size.height * (i / 17);
      final x = size.width * (0.5 + math.sin(i) * 0.24);
      canvas.drawCircle(Offset(x, y), 2, dots);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
