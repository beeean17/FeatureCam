import 'package:flutter/material.dart';

import 'camera_motion.dart';
import 'camera_theme.dart';

class ProcessingOverlay extends StatelessWidget {
  const ProcessingOverlay({
    super.key,
    required this.isVisible,
    required this.label,
  });

  final bool isVisible;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: AnimatedSlide(
        duration: CameraMotion.processing,
        curve: CameraMotion.cameraEaseOut,
        offset: isVisible ? Offset.zero : const Offset(0, -0.35),
        child: AnimatedOpacity(
          duration: CameraMotion.processing,
          curve: CameraMotion.cameraEaseOut,
          opacity: isVisible ? 1 : 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: FeatureCamColors.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FeatureCamColors.strokeSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FeatureCamColors.amber,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: const TextStyle(
                        color: FeatureCamColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
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
