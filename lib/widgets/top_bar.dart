import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/connection_status.dart';
import '../state/vehicle_state.dart';
import '../theme/app_theme.dart';
import 'mode_toggle.dart';

/// Slim header row: logo + title on the left, Manual/Auto toggle in the
/// middle, connection status and a settings shortcut on the right.
///
/// FIXED: the connection indicator used to hide its text label in compact
/// (phone) mode, leaving only a tiny colored dot with no visible "Connect"
/// affordance — easy to miss entirely. Now it's always a labeled, filled
/// pill, so it reads as a real button on every screen size.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.onTapConnection,
    required this.manualMode,
    required this.onModeChanged,
    this.compact = false,
  });

  // vehicleState field removed — fetched via context.watch below instead.
  final VoidCallback onTapConnection;
  final bool manualMode;
  final ValueChanged<bool> onModeChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Reads VehicleState from Provider and subscribes this widget to
    // rebuild whenever it changes — same effect as the old constructor
    // param, just sourced from the tree instead of passed in.
    final vehicleState = context.watch<VehicleState>();

    final connected =
        vehicleState.connectionStatus == ConnectionStatus.connected;
    final connecting =
        vehicleState.connectionStatus == ConnectionStatus.connecting;

    final statusColor = connected
        ? AppColors.success
        : connecting
        ? AppColors.amber
        : AppColors.danger;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16,
        vertical: compact ? 5 : 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          SizedBox(width: compact ? 10 : 18),
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
          // Always a filled, labeled pill — never just a bare dot — so it
          // reads as a tappable button on phone screens too.
          GestureDetector(
            onTap: onTapConnection,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 14,
                vertical: compact ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.55)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: compact ? 7 : 9,
                    height: compact ? 7 : 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                  SizedBox(width: compact ? 5 : 7),
                  Text(
                    connected
                        ? 'Connected'
                        : connecting
                        ? 'Connecting…'
                        : vehicleState.connectionLost
                        ? 'Connection Lost'
                        : 'Connect',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: compact ? 11.5 : 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
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
