import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';
import '../connection/connection_manager.dart';
import '../state/vehicle_state.dart';
import '../theme/app_theme.dart';
import 'collapsible_card.dart';

const _availableModes = ['Stabilize', 'Loiter', 'RTL'];

class FlightStatusPanel extends StatelessWidget {
  const FlightStatusPanel({
    super.key,
    required this.enabled,
    required this.onArmToggle,
    this.compact = false,
  });

  final bool enabled;
  final Future<void> Function(bool arm) onArmToggle;
  final bool compact;

  Future<void> _confirmArm(BuildContext context, bool arm) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              arm ? Icons.warning_amber_rounded : Icons.stop_circle_outlined,
              color: arm ? AppColors.danger : AppColors.amber,
            ),
            const SizedBox(width: 12),
            Text(arm ? 'arm_motors_q'.tr() : 'disarm_motors_q'.tr()),
          ],
        ),
        content: Text(
          arm ? 'prop_spin_warning'.tr() : 'prop_stop_warning'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: arm ? AppColors.danger : AppColors.amber,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              arm ? 'arm'.tr().toUpperCase() : 'disarm'.tr().toUpperCase(),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await onArmToggle(arm);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleState = context.watch<VehicleState>();
    final connectionManager = context.read<ConnectionManager>();
    final scheme = Theme.of(context).colorScheme;

    return Opacity(
          opacity: enabled ? 1 : 0.4,
          child: IgnorePointer(
            ignoring: !enabled,
            child: SizedBox(
              width: compact ? 190 : 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: CollapsibleCard(
                    compact: compact,
                    header: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: vehicleState.armed
                                    ? AppColors.danger
                                    : AppColors.success,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (vehicleState.armed
                                                ? AppColors.danger
                                                : AppColors.success)
                                            .withValues(alpha: 0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .fadeOut(duration: 1.seconds),
                        const SizedBox(width: 8),
                        Text(
                          vehicleState.armed
                              ? 'armed'.tr().toUpperCase()
                              : 'disarmed'.tr().toUpperCase(),
                          style: TextStyle(
                            color: vehicleState.armed
                                ? AppColors.danger
                                : AppColors.success,
                            fontSize: compact ? 11 : 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () =>
                              _confirmArm(context, !vehicleState.armed),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              vertical: compact ? 10 : 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: vehicleState.armed
                                    ? [AppColors.danger, Color(0xFFB03A2E)]
                                    : [AppColors.amber, Color(0xFFB95D10)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (vehicleState.armed
                                              ? AppColors.danger
                                              : AppColors.amber)
                                          .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              vehicleState.armed
                                  ? 'disarm'.tr().toUpperCase()
                                  : 'arm'.tr().toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 13 : 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 12 : 16),
                        Row(
                          children: [
                            Text(
                              'flight_mode'.tr().toUpperCase(),
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.settings_input_component,
                              size: 10,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: _availableModes.map((m) {
                            final active = vehicleState.currentMode == m;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => connectionManager.setMode(m),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: compact ? 8 : 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? scheme.primary.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: active
                                          ? scheme.primary.withValues(
                                              alpha: 0.5,
                                            )
                                          : scheme.outlineVariant.withValues(
                                              alpha: 0.3,
                                            ),
                                    ),
                                  ),
                                  child: Text(
                                    m,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: active
                                          ? FontWeight.w900
                                          : FontWeight.w600,
                                      color: active
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: connectionManager.returnToLaunch,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              vertical: compact ? 8 : 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.cyan.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.home_outlined,
                                  size: 14,
                                  color: AppColors.cyan,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'return_home'.tr().toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.cyan,
                                    fontSize: compact ? 11 : 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
        .animate()
        .slideY(
          begin: 1.0,
          end: 0.0,
          duration: 600.ms,
          curve: Curves.easeOutCubic,
        )
        .fadeIn();
  }
}
