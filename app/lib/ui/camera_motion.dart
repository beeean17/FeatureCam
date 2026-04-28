import 'package:flutter/animation.dart';

class CameraMotion {
  const CameraMotion._();

  static const cameraEaseOut = Cubic(0.20, 0.00, 0.00, 1.00);
  static const cameraEaseInOut = Cubic(0.37, 0.00, 0.13, 1.00);
  static const cameraSpring = Cubic(0.18, 0.89, 0.32, 1.18);

  static const tapDown = Duration(milliseconds: 90);
  static const tapRelease = Duration(milliseconds: 140);
  static const iconState = Duration(milliseconds: 160);
  static const modeSwitch = Duration(milliseconds: 220);
  static const overlayFade = Duration(milliseconds: 180);
  static const controlShift = Duration(milliseconds: 260);
  static const processing = Duration(milliseconds: 240);
  static const captureFlash = Duration(milliseconds: 120);
  static const panoramaGuide = Duration(milliseconds: 260);
  static const lensSettle = Duration(milliseconds: 180);
  static const focusIndicator = Duration(milliseconds: 720);

  static double naturalOrientationTurns({
    required int quarterTurns,
    required double fromTurns,
  }) {
    final baseTurns = (quarterTurns % 4) / 4;
    final candidates = <double>[
      baseTurns - 2,
      baseTurns - 1,
      baseTurns,
      baseTurns + 1,
      baseTurns + 2,
    ];
    var bestTurns = candidates.first;
    var bestDistance = (bestTurns - fromTurns).abs();
    for (final turns in candidates.skip(1)) {
      final distance = (turns - fromTurns).abs();
      if (distance < bestDistance) {
        bestTurns = turns;
        bestDistance = distance;
      }
    }
    return bestTurns;
  }
}
