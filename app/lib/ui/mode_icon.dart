import 'package:flutter/material.dart';

import '../camera/camera_modes.dart';

class ModeIcon extends StatelessWidget {
  const ModeIcon({
    super.key,
    required this.mode,
    required this.color,
    this.size = 22,
  });

  final CameraMode mode;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      CameraMode.photo => Icon(
        Icons.photo_camera_outlined,
        color: color,
        size: size,
      ),
      CameraMode.video => Icon(
        Icons.movie_creation_outlined,
        color: color,
        size: size,
      ),
      CameraMode.fisheye => CustomPaint(
        size: Size.square(size),
        painter: _FishPainter(color: color),
      ),
      CameraMode.panorama => Icon(
        Icons.panorama_horizontal_outlined,
        color: color,
        size: size,
      ),
    };
  }
}

class _FishPainter extends CustomPainter {
  const _FishPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final body = Path()
      ..moveTo(size.width * 0.14, size.height * 0.50)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.22,
        size.width * 0.66,
        size.height * 0.22,
        size.width * 0.84,
        size.height * 0.50,
      )
      ..cubicTo(
        size.width * 0.66,
        size.height * 0.78,
        size.width * 0.34,
        size.height * 0.78,
        size.width * 0.14,
        size.height * 0.50,
      );
    canvas.drawPath(body, stroke);

    final tail = Path()
      ..moveTo(size.width * 0.18, size.height * 0.50)
      ..lineTo(size.width * 0.02, size.height * 0.30)
      ..lineTo(size.width * 0.02, size.height * 0.70)
      ..close();
    canvas.drawPath(tail, stroke);

    canvas.drawCircle(
      Offset(size.width * 0.68, size.height * 0.43),
      size.width * 0.045,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _FishPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
