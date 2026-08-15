import 'package:flutter/material.dart';
import '../state/connection_status.dart';
import '../state/vehicle_state.dart';
import '../theme/app_theme.dart';
import 'mode_toggle.dart';

/// Slim header row: logo + title on the left, Manual/Auto toggle in the
/// middle, connection status and a settings shortcut on the right.
/// Height scales down on phones so it doesn't eat into the already-tight
/// landscape vertical space.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.vehicleState,
    required this.onTapConnection,
    required this.manualMode,
    required this.onModeChanged,
    this.compact = false,
  });

  final VehicleState vehicleState;
  final VoidCallback onTapConnection;
  final bool manualMode;
  final ValueChanged<bool> onModeChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final connected =
        vehicleState.connectionStatus == ConnectionStatus.connected;
    final connecting =
        vehicleState.connectionStatus == ConnectionStatus.connecting;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16,
        vertical: compact ? 5 : 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.amberDim,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png', height: compact ? 24 : 24),
          SizedBox(width: compact ? 6 : 10),
          if (!compact || MediaQuery.of(context).size.width > 500)
            Text(
              'SafeSky Nexus',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: compact ? 13 : 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          const Spacer(),
          ModeToggle(
            manual: manualMode,
            onChanged: onModeChanged,
            compact: compact,
          ),
          SizedBox(width: compact ? 10 : 18),
          GestureDetector(
            onTap: onTapConnection,
            child: Row(
              children: [
                Container(
                  width: compact ? 7 : 9,
                  height: compact ? 7 : 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected
                        ? AppColors.success
                        : connecting
                        ? AppColors.amber
                        : AppColors.danger,
                  ),
                ),
                SizedBox(width: compact ? 5 : 7),
                if (!compact)
                  Text(
                    connected
                        ? 'Connected'
                        : connecting
                        ? 'Connecting…'
                        : 'Disconnected',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: compact ? 10 : 18),
          // Settings screen isn't built yet — icon is a placeholder anchor
          // point for sensor/radio/profile settings mentioned on the roadmap.
          Icon(
            Icons.settings_outlined,
            color: AppColors.textSecondary,
            size: compact ? 17 : 20,
          ),
        ],
      ),
    );
  }
}
