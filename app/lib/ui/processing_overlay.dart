import 'dart:ui';

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
      ignoring: !isVisible,
      child: AnimatedOpacity(
        duration: CameraMotion.processing,
        curve: CameraMotion.cameraEaseOut,
        opacity: isVisible ? 1 : 0,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.32),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: FeatureCamColors.surface.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: FeatureCamColors.strokeSubtle),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FeatureCamColors.amber,
                          ),
                        ),
                        const SizedBox(width: 12),
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
        ),
      ),
    );
  }
}
