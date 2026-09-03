import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../screens/settings_screen.dart';
import '../screens/vehicle_health_screen.dart';
import '../state/vehicle_state.dart';
import '../models/health_state.dart';
import '../theme/app_theme.dart';
import 'connection_button.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          SizedBox(width: compact ? 4 : 8),
          Image.asset('assets/images/logo.png', height: compact ? 20 : 24),
          SizedBox(width: compact ? 6 : 10),
          if (MediaQuery.of(context).size.width > (compact ? 450 : 600))
            Text(
              'app_title'.tr(),
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: compact ? 12 : 16,
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
          SizedBox(width: compact ? 8 : 12),
          ConnectionButton(
            status: vehicleState.connectionStatus,
            connectionLost: vehicleState.connectionLost,
            onTap: onTapConnection,
            compact: compact,
          ),
          SizedBox(width: compact ? 8 : 12),
          _HealthIndicator(
            status: vehicleState.overallHealth,
            compact: compact,
          ),
          SizedBox(width: compact ? 2 : 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Icon(
                  Icons.settings_outlined,
                  color: scheme.onSurfaceVariant,
                  size: compact ? 18 : 22,
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? 2 : 4),
        ],
      ),
    );
  }
}

class _HealthIndicator extends StatelessWidget {
  final HealthStatus status;
  final bool compact;

  const _HealthIndicator({required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (status) {
      case HealthStatus.healthy:
        icon = Icons.check_circle_outline;
        color = AppColors.success;
        break;
      case HealthStatus.unhealthy:
        icon = Icons.warning_amber_rounded;
        color = AppColors.danger;
        break;
      case HealthStatus.unknown:
      default:
        icon = Icons.help_outline;
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
    }

    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const VehicleHealthScreen())),
      child: Icon(icon, color: color, size: compact ? 20 : 24),
    );
  }
}
