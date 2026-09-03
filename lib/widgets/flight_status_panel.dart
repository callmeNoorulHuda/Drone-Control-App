import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../connection/connection_manager.dart';
import '../state/vehicle_state.dart';
import '../theme/app_theme.dart';
import 'collapsible_card.dart';

const _availableModes = ['Stabilize', 'Loiter', 'RTL'];

/// Center-bottom panel sitting between the two joysticks: armed state,
/// the big ARM/DISARM action, and flight-mode selection. Now wrapped in
/// CollapsibleCard — the ARMED/DISARMED badge stays visible even when
/// collapsed; the ARM button and mode row tuck away on swipe-down.
class FlightStatusPanel extends StatelessWidget {
  const FlightStatusPanel({
    super.key,
    required this.enabled,
    required this.onArmToggle,
    this.compact = false,
  });

  // vehicleState and connectionManager params removed — both now read
  // from Provider instead (watch for vehicleState since it drives
  // rendering, read for connectionManager since it's only ever called
  // from inside button callbacks, never used to build UI directly).
  //
  // onArmToggle is deliberately a callback INTO MainFlightScreen instead
  // of calling connectionManager.armDisarm() directly here — arming needs
  // to also force the throttle joystick to minimum first (see
  // MainFlightScreen._onArmToggle), and that joystick lives in a sibling
  // widget this panel has no reference to. Routing the actual arm/disarm
  // action back up to the screen that owns both pieces keeps that
  // coordination in one place instead of splitting it across two widgets.
  final bool enabled;
  final Future<void> Function(bool arm) onArmToggle;
  final bool compact;

  Future<void> _confirmArm(BuildContext context, bool arm) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(arm ? 'arm_motors_q'.tr() : 'disarm_motors_q'.tr()),
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
          width: compact ? 176 : 220,
          child: CollapsibleCard(
            compact: compact,
            header: Text(
              vehicleState.armed
                  ? 'armed'.tr().toUpperCase()
                  : 'disarmed'.tr().toUpperCase(),
              style: TextStyle(
                color: vehicleState.armed
                    ? AppColors.danger
                    : AppColors.success,
                fontSize: compact ? 11.5 : 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _confirmArm(context, !vehicleState.armed),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: compact ? 8 : 11),
                    decoration: BoxDecoration(
                      color: vehicleState.armed
                          ? AppColors.danger
                          : AppColors.amber,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      vehicleState.armed
                          ? 'disarm'.tr().toUpperCase()
                          : 'arm'.tr().toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 12.5 : 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: compact ? 9 : 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'flight_mode'.tr().toUpperCase(),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: compact ? 9 : 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                SizedBox(height: compact ? 5 : 6),
                Row(
                  children: _availableModes.map((m) {
                    final active = vehicleState.currentMode == m;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => connectionManager.setMode(m),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: EdgeInsets.symmetric(
                            vertical: compact ? 7 : 9,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.cyanDim
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: active
                                  ? Colors.transparent
                                  : scheme.outlineVariant,
                            ),
                          ),
                          child: Text(
                            m,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 9 : 10,
                              fontWeight: FontWeight.w600,
                              color: active
                                  ? AppColors.cyan
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                GestureDetector(
                  onTap: connectionManager.returnToLaunch,
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: compact ? 7 : 9),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.cyan),
                    ),
                    child: Text(
                      'return_home'.tr().toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.cyan,
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
