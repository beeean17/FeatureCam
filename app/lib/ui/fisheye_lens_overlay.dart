import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../camera/camera_modes.dart';
import 'camera_motion.dart';
import 'camera_theme.dart';

class FisheyeLensOverlay extends StatefulWidget {
  const FisheyeLensOverlay({
    super.key,
    required this.lens,
    required this.onChanged,
  });

  final FisheyeLensConfig lens;
  final ValueChanged<FisheyeLensConfig> onChanged;

  @override
  State<FisheyeLensOverlay> createState() => _FisheyeLensOverlayState();
}

class _FisheyeLensOverlayState extends State<FisheyeLensOverlay> {
  bool _isDragging = false;
  double? _startRadius;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onDoubleTap: () {
            HapticFeedback.lightImpact();
            widget.onChanged(const FisheyeLensConfig());
          },
          onScaleStart: (details) {
            _startRadius = widget.lens.radius;
            setState(() => _isDragging = true);
          },
          onScaleUpdate: (details) {
            final nextCenter = Offset(
              (details.localFocalPoint.dx / size.width).clamp(0.08, 0.92),
              (details.localFocalPoint.dy / size.height).clamp(0.14, 0.74),
            );
            final nextRadius =
                ((_startRadius ?? widget.lens.radius) * details.scale).clamp(
                  0.18,
                  0.48,
                );
            widget.onChanged(
              widget.lens.copyWith(center: nextCenter, radius: nextRadius),
            );
          },
          onScaleEnd: (_) {
            _startRadius = null;
            setState(() => _isDragging = false);
          },
          child: Stack(
            children: [
              CustomPaint(
                size: size,
                painter: _FisheyeLensPainter(
                  lens: widget.lens,
                  isDragging: _isDragging,
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 28,
                child: AnimatedOpacity(
                  opacity: _isDragging ? 0 : 1,
                  duration: CameraMotion.overlayFade,
                  child: const _FisheyeHint(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FisheyeHint extends StatelessWidget {
  const _FisheyeHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FeatureCamColors.surface.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: FeatureCamColors.strokeSubtle),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            '촬영 후 원 안쪽이 Fisheye로 처리됩니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FeatureCamColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _FisheyeLensPainter extends CustomPainter {
  const _FisheyeLensPainter({required this.lens, required this.isDragging});

  final FisheyeLensConfig lens;
  final bool isDragging;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);
    final center = Offset(
      size.width * lens.center.dx,
      size.height * lens.center.dy,
    );
    final radius = shortest * lens.radius;
    final dimPaint = Paint()..color = const Color(0x22000000);
    final lensPath = Path()
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(lensPath, dimPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDragging ? 2.4 : 1.6
      ..color = isDragging
          ? FeatureCamColors.amber
          : FeatureCamColors.white.withValues(alpha: 0.74);
    canvas.drawCircle(center, radius, ringPaint);

    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = FeatureCamColors.white.withValues(alpha: 0.18);
    canvas.drawCircle(center, radius * 0.66, guidePaint);
    canvas.drawLine(
      center.translate(-radius, 0),
      center.translate(radius, 0),
      guidePaint,
    );
    canvas.drawLine(
      center.translate(0, -radius),
      center.translate(0, radius),
      guidePaint,
    );

    canvas.drawCircle(
      center,
      4,
      Paint()
        ..color = (isDragging ? FeatureCamColors.amber : FeatureCamColors.white)
            .withValues(alpha: 0.82),
    );
  }

  @override
  bool shouldRepaint(_FisheyeLensPainter oldDelegate) {
    return oldDelegate.lens != lens || oldDelegate.isDragging != isDragging;
  }
}
