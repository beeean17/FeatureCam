import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../camera/camera_modes.dart';

class CameraPreviewView extends StatelessWidget {
  const CameraPreviewView({
    super.key,
    required this.mode,
    required this.controller,
    required this.errorMessage,
    required this.isInitializing,
  });

  final CameraMode mode;
  final CameraController? controller;
  final String? errorMessage;
  final bool isInitializing;

  @override
  Widget build(BuildContext context) {
    final activeController = controller;

    return ColoredBox(
      color: const Color(0xFF090909),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (activeController != null && activeController.value.isInitialized)
            _CameraPreviewFill(controller: activeController)
          else
            CustomPaint(painter: _ViewfinderPainter(mode: mode)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0x99000000),
                ],
                stops: [0, 0.24, 0.62, 1],
              ),
            ),
          ),
          if (activeController == null || !activeController.value.isInitialized)
            _CameraStateMessage(
              message:
                  errorMessage ??
                  (isInitializing ? '카메라 준비 중' : '카메라를 사용할 수 없습니다'),
            ),
        ],
      ),
    );
  }
}

class _CameraPreviewFill extends StatelessWidget {
  const _CameraPreviewFill({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }

    final orientation = MediaQuery.orientationOf(context);
    final previewWidth = orientation == Orientation.portrait
        ? previewSize.height
        : previewSize.width;
    final previewHeight = orientation == Orientation.portrait
        ? previewSize.width
        : previewSize.height;

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewWidth,
          height: previewHeight,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _CameraStateMessage extends StatelessWidget {
  const _CameraStateMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter({required this.mode});

  final CameraMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()..color = const Color(0xFF242B2D);
    final ground = Paint()..color = const Color(0xFF101112);
    canvas.drawRect(Offset.zero & size, sky);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.62, size.width, size.height * 0.38),
      ground,
    );

    _drawPerspectiveLines(canvas, size);
    _drawBuildings(canvas, size);
    _drawFocusFrame(canvas, size);
  }

  void _drawPerspectiveLines(Canvas canvas, Size size) {
    final vanishing = Offset(size.width * 0.56, size.height * 0.42);
    final linePaint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1;

    for (var i = 0; i < 11; i++) {
      final x = size.width * i / 10;
      canvas.drawLine(Offset(x, size.height), vanishing, linePaint);
    }

    for (var i = 0; i < 8; i++) {
      final y = size.height * (0.66 + i * 0.045);
      canvas.drawLine(Offset(0, y), Offset(size.width, y - i * 6), linePaint);
    }
  }

  void _drawBuildings(Canvas canvas, Size size) {
    final paints = [
      Paint()..color = const Color(0xFF1E2020),
      Paint()..color = const Color(0xFF2C302F),
      Paint()..color = const Color(0xFF171818),
    ];
    final windowPaint = Paint()..color = const Color(0x33FFDCA1);
    final stroke = Paint()
      ..color = const Color(0x22FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final buildingCount = 7;
    for (var i = 0; i < buildingCount; i++) {
      final width = size.width * (0.16 + (i % 3) * 0.025);
      final left = size.width * (i / buildingCount) - width * 0.22;
      final height = size.height * (0.34 + (i % 4) * 0.055);
      final top = size.height * 0.62 - height;
      final rect = Rect.fromLTWH(left, top, width, height);
      canvas.drawRect(rect, paints[i % paints.length]);
      canvas.drawRect(rect, stroke);

      final columns = math.max(2, width ~/ 20);
      final rows = math.max(3, height ~/ 28);
      for (var x = 1; x < columns; x++) {
        for (var y = 1; y < rows; y++) {
          if ((x + y + i) % 3 == 0) {
            continue;
          }
          final window = Rect.fromLTWH(
            rect.left + x * width / columns - 3,
            rect.top + y * height / rows - 4,
            6,
            8,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(window, const Radius.circular(1)),
            windowPaint,
          );
        }
      }
    }
  }

  void _drawFocusFrame(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x20FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final side = math.min(size.width, size.height) * 0.17;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.46),
      width: side,
      height: side,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) {
    return oldDelegate.mode != mode;
  }
}
