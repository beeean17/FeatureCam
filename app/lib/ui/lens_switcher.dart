import 'package:flutter/material.dart';

import 'camera_motion.dart';
import 'camera_theme.dart';

class LensSwitcher extends StatelessWidget {
  const LensSwitcher({
    super.key,
    required this.selectedZoom,
    required this.onZoomSelected,
  });

  final double selectedZoom;
  final ValueChanged<double> onZoomSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LensButton(
          label: '0.5',
          value: 0.5,
          isSelected: selectedZoom == 0.5,
          onSelected: onZoomSelected,
        ),
        const SizedBox(width: 14),
        _LensButton(
          label: '1x',
          value: 1,
          isSelected: selectedZoom == 1,
          onSelected: onZoomSelected,
        ),
        const SizedBox(width: 14),
        _LensButton(
          label: '2x',
          value: 2,
          isSelected: selectedZoom == 2,
          onSelected: onZoomSelected,
        ),
      ],
    );
  }
}

class _LensButton extends StatelessWidget {
  const _LensButton({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final double value;
  final bool isSelected;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    final size = isSelected ? 48.0 : 42.0;

    return GestureDetector(
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: CameraMotion.modeSwitch,
        curve: CameraMotion.cameraSpring,
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? FeatureCamColors.amber.withValues(alpha: 0.18)
              : FeatureCamColors.surfaceSoft,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? FeatureCamColors.amber
                : FeatureCamColors.strokeSubtle,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: FeatureCamColors.amber.withValues(alpha: 0.25),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? FeatureCamColors.amber : FeatureCamColors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
