import 'package:flutter/material.dart';
import '../connection/connection_manager.dart';
import '../state/vehicle_state.dart';
import '../theme/app_theme.dart';

const _availableModes = ['Stabilize', 'Loiter', 'RTL'];

/// Center-bottom panel sitting between the two joysticks: armed state,
/// the big ARM/DISARM action, and flight-mode selection — matching the
/// reference layout's "ARMED / DISARM / FLIGHT MODE" stack.
class FlightStatusPanel extends StatelessWidget {
  const FlightStatusPanel({
    super.key,
    required this.vehicleState,
    required this.connectionManager,
    required this.enabled,
    this.compact = false,
  });

  final VehicleState vehicleState;
  final ConnectionManager connectionManager;
  final bool enabled;
  final bool compact;

  Future<void> _confirmArm(BuildContext context, bool arm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: Text(arm ? 'Arm motors?' : 'Disarm motors?'),
        content: Text(arm
            ? 'Propellers will be able to spin once armed.'
            : 'This will stop the motors immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: arm ? AppColors.danger : AppColors.surface),
            onPressed: () => Navigator.pop(context, true),
            child: Text(arm ? 'Arm' : 'Disarm'),
          ),
        ],
      ),
    );
    if (confirmed == true) connectionManager.armDisarm(arm);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Container(
          width: compact ? 176 : 220,
          padding: EdgeInsets.all(compact ? 10 : 14),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(compact ? 12 : 16),
            border: Border.all(color: AppColors.hairline),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                vehicleState.armed ? 'ARMED' : 'DISARMED',
                style: TextStyle(
                  color: vehicleState.armed ? AppColors.danger : AppColors.success,
                  fontSize: compact ? 11.5 : 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: compact ? 6 : 8),
              GestureDetector(
                onTap: () => _confirmArm(context, !vehicleState.armed),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: compact ? 8 : 11),
                  decoration: BoxDecoration(
                    color: vehicleState.armed ? AppColors.danger : AppColors.amber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    vehicleState.armed ? 'DISARM' : 'ARM',
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
                  'FLIGHT MODE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
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
                        padding: EdgeInsets.symmetric(vertical: compact ? 7 : 9),
                        decoration: BoxDecoration(
                          color: active ? AppColors.cyanDim : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: active ? Colors.transparent : AppColors.hairline,
                          ),
                        ),
                        child: Text(
                          m,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 9 : 10,
                            fontWeight: FontWeight.w600,
                            color: active ? AppColors.cyan : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
