import 'package:flutter/widgets.dart';

enum CameraMode {
  photo('PHOTO'),
  video('VIDEO'),
  fisheye('FISHEYE'),
  panorama('PANORAMA');

  const CameraMode(this.label);

  final String label;
}

@immutable
class FisheyeLensConfig {
  const FisheyeLensConfig({
    this.strength = 0.85,
    this.center = const Offset(0.5, 0.46),
    this.radius = 0.34,
  });

  final double strength;
  final Offset center;
  final double radius;

  FisheyeLensConfig copyWith({
    double? strength,
    Offset? center,
    double? radius,
  }) {
    return FisheyeLensConfig(
      strength: strength ?? this.strength,
      center: center ?? this.center,
      radius: radius ?? this.radius,
    );
  }
}

@immutable
class PanoramaCaptureState {
  const PanoramaCaptureState({
    this.capturedCount = 0,
    this.guideVisible = false,
  });

  final int capturedCount;
  final bool guideVisible;

  int get step => (capturedCount + 1).clamp(1, 3);
  bool get isComplete => capturedCount >= 3;

  PanoramaCaptureState copyWith({int? capturedCount, bool? guideVisible}) {
    return PanoramaCaptureState(
      capturedCount: capturedCount ?? this.capturedCount,
      guideVisible: guideVisible ?? this.guideVisible,
    );
  }
}
