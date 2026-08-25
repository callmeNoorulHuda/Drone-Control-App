import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pill-style segmented toggle between Manual and Auto flight control.
/// Manual = joysticks + arm/disarm + flight-mode chips are shown.
/// Auto = those disappear; only map, telemetry, and camera feed remain.
class ModeToggle extends StatelessWidget {
  const ModeToggle({
    super.key,
    required this.manual,
    required this.onChanged,
    this.compact = false,
  });

  final bool manual;
  final ValueChanged<bool> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 26.0 : 30.0;
    final fontSize = compact ? 9.5 : 11.0;
    final hPad = compact ? 9.0 : 13.0;

    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            label: 'MANUAL',
            active: manual,
            onTap: () => onChanged(true),
            fontSize: fontSize,
            hPad: hPad,
          ),
          _Segment(
            label: 'AUTO',
            active: !manual,
            onTap: () => onChanged(false),
            fontSize: fontSize,
            hPad: hPad,
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
    required this.fontSize,
    required this.hPad,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final double fontSize;
  final double hPad;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: hPad),
        alignment: Alignment.center,
        height: double.infinity,
        decoration: BoxDecoration(
          color: active ? AppColors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
