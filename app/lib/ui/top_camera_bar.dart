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
    this.isLandscape = false,
    this.contentQuarterTurns = 0,
  });

  final bool flashEnabled;
  final bool isRecording;
  final bool isModeBarOpen;
  final VoidCallback onSettingsPressed;
  final VoidCallback onModePressed;
  final VoidCallback onFlashPressed;
  final bool isLandscape;
  final int contentQuarterTurns;

  @override
  Widget build(BuildContext context) {
    if (isLandscape) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: FeatureCamColors.surface.withValues(alpha: 0.62),
              border: Border(
                left: BorderSide(
                  color: FeatureCamColors.white.withValues(alpha: 0.04),
                ),
                right: BorderSide(
                  color: FeatureCamColors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: SafeArea(
              left: false,
              right: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 22,
                ),
                child: Column(
                  children: [
                    _TopIconButton(
                      icon: Icons.settings_outlined,
                      onPressed: onSettingsPressed,
                      quarterTurns: contentQuarterTurns,
                    ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: CameraMotion.iconState,
                      child: isRecording
                          ? const _RecordingPill(key: ValueKey('recording'))
                          : _ModeButton(
                              key: const ValueKey('mode-button'),
                              isOpen: isModeBarOpen,
                              isLandscape: true,
                              quarterTurns: contentQuarterTurns,
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
                      quarterTurns: contentQuarterTurns,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: FeatureCamColors.surface.withValues(alpha: 0.62),
            border: Border(
              top: BorderSide(
                color: FeatureCamColors.white.withValues(alpha: 0.06),
              ),
              bottom: BorderSide(
                color: FeatureCamColors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  _TopIconButton(
                    icon: Icons.settings_outlined,
                    onPressed: onSettingsPressed,
                    quarterTurns: contentQuarterTurns,
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: CameraMotion.iconState,
                    child: isRecording
                        ? const _RecordingPill(key: ValueKey('recording'))
                        : _ModeButton(
                            key: const ValueKey('mode-button'),
                            isOpen: isModeBarOpen,
                            isLandscape: false,
                            quarterTurns: contentQuarterTurns,
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
                    quarterTurns: contentQuarterTurns,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.isOpen,
    required this.isLandscape,
    required this.quarterTurns,
    required this.onPressed,
  });

  final bool isOpen;
  final bool isLandscape;
  final int quarterTurns;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: AnimatedContainer(
        duration: CameraMotion.iconState,
        curve: CameraMotion.cameraEaseInOut,
        width: isLandscape ? 40 : null,
        height: isLandscape ? 40 : null,
        padding: isLandscape
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
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
        child: AnimatedRotation(
          turns: quarterTurns / 4,
          duration: CameraMotion.controlShift,
          curve: CameraMotion.cameraEaseInOut,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLandscape)
                Icon(
                  Icons.dashboard_customize_outlined,
                  color: isOpen
                      ? FeatureCamColors.amber
                      : FeatureCamColors.white,
                  size: 21,
                )
              else ...[
                Text(
                  'MODE',
                  style: TextStyle(
                    color: isOpen
                        ? FeatureCamColors.amber
                        : FeatureCamColors.white,
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
                    Icons.keyboard_arrow_up_rounded,
                    color: isOpen
                        ? FeatureCamColors.amber
                        : FeatureCamColors.white,
                    size: 15,
                  ),
                ),
              ],
            ],
          ),
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
    required this.quarterTurns,
    this.color = FeatureCamColors.white,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final int quarterTurns;

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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _pressed ? const Color(0x1AFFFFFF) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: _RotatingIcon(
            icon: widget.icon,
            color: widget.color,
            quarterTurns: widget.quarterTurns,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _RotatingIcon extends StatelessWidget {
  const _RotatingIcon({
    required this.icon,
    required this.color,
    required this.quarterTurns,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final int quarterTurns;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: quarterTurns / 4,
      duration: CameraMotion.controlShift,
      curve: CameraMotion.cameraEaseInOut,
      child: Icon(icon, color: color, size: size),
    );
  }
}
