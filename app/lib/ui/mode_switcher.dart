import 'dart:ui';

import 'package:flutter/material.dart';

import '../camera/camera_modes.dart';
import 'camera_motion.dart';
import 'camera_theme.dart';

class ModeSwitcher extends StatelessWidget {
  const ModeSwitcher({
    super.key,
    required this.selectedMode,
    required this.isOpen,
    required this.onModeSelected,
  });

  final CameraMode selectedMode;
  final bool isOpen;
  final ValueChanged<CameraMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: CameraMotion.modeSwitch,
      switchInCurve: CameraMotion.cameraEaseOut,
      switchOutCurve: CameraMotion.cameraEaseInOut,
      transitionBuilder: (child, animation) {
        final position = Tween<Offset>(
          begin: const Offset(0, -0.35),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: position, child: child),
        );
      },
      child: isOpen
          ? Center(
              key: const ValueKey('mode-switcher-open'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: FeatureCamColors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: CameraMode.values.map((mode) {
                          return _ModeItem(
                            mode: mode,
                            isSelected: selectedMode == mode,
                            onTap: () => onModeSelected(mode),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox(key: ValueKey('mode-switcher-closed')),
    );
  }
}

class _ModeItem extends StatelessWidget {
  const _ModeItem({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final CameraMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 38,
        width: 82,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: CameraMotion.modeSwitch,
              curve: CameraMotion.cameraEaseInOut,
              style: TextStyle(
                color: isSelected
                    ? FeatureCamColors.amber
                    : FeatureCamColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
              child: Text(mode.label),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: CameraMotion.modeSwitch,
              curve: CameraMotion.cameraEaseInOut,
              width: isSelected ? 28 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: FeatureCamColors.amber,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
