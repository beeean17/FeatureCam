import 'dart:ui';

import 'package:flutter/material.dart';

import 'camera_motion.dart';
import 'camera_theme.dart';

class TopCameraBar extends StatelessWidget {
  const TopCameraBar({
    super.key,
    required this.flashEnabled,
    required this.isRecording,
    required this.isModeBarOpen,
    required this.onSettingsPressed,
    required this.onModePressed,
    required this.onFlashPressed,
  });

  final bool flashEnabled;
  final bool isRecording;
  final bool isModeBarOpen;
  final VoidCallback onSettingsPressed;
  final VoidCallback onModePressed;
  final VoidCallback onFlashPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
          child: SizedBox(
            height: 50,
            child: Row(
              children: [
                _TopIconButton(
                  icon: Icons.settings_outlined,
                  onPressed: onSettingsPressed,
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: CameraMotion.iconState,
                  child: isRecording
                      ? const _RecordingPill(key: ValueKey('recording'))
                      : _ModeButton(
                          key: const ValueKey('mode-button'),
                          isOpen: isModeBarOpen,
                          onPressed: onModePressed,
                        ),
                ),
                const Spacer(),
                _TopIconButton(
                  icon: flashEnabled
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                  color: flashEnabled
                      ? FeatureCamColors.amber
                      : FeatureCamColors.white,
                  onPressed: onFlashPressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({super.key, required this.isOpen, required this.onPressed});

  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: AnimatedContainer(
        duration: CameraMotion.iconState,
        curve: CameraMotion.cameraEaseInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isOpen
              ? FeatureCamColors.amber.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isOpen
                ? FeatureCamColors.amber.withValues(alpha: 0.42)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MODE',
              style: TextStyle(
                color: isOpen ? FeatureCamColors.amber : FeatureCamColors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(width: 5),
            AnimatedRotation(
              turns: isOpen ? 0.5 : 0,
              duration: CameraMotion.iconState,
              curve: CameraMotion.cameraEaseInOut,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isOpen ? FeatureCamColors.amber : FeatureCamColors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingPill extends StatelessWidget {
  const _RecordingPill({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FeatureCamColors.recordingRed.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: FeatureCamColors.recordingRed.withValues(alpha: 0.42),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: FeatureCamColors.recordingRed, size: 7),
            SizedBox(width: 7),
            Text(
              'REC',
              style: TextStyle(
                color: FeatureCamColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopIconButton extends StatefulWidget {
  const _TopIconButton({
    required this.icon,
    required this.onPressed,
    this.color = FeatureCamColors.white,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_TopIconButton> createState() => _TopIconButtonState();
}

class _TopIconButtonState extends State<_TopIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1,
        duration: _pressed ? CameraMotion.tapDown : CameraMotion.tapRelease,
        curve: CameraMotion.cameraSpring,
        child: AnimatedContainer(
          duration: CameraMotion.iconState,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _pressed ? const Color(0x1AFFFFFF) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(widget.icon, color: widget.color, size: 24),
        ),
      ),
    );
  }
}
