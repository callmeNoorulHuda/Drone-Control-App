import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../state/vehicle_state.dart';
import '../state/connection_status.dart';
import '../state/settings_controller.dart';
import '../state/unit_system.dart';
import '../theme/app_theme.dart';
import '../models/health_state.dart';
import '../screens/vehicle_health_screen.dart';

class TelemetryDetailScreen extends StatelessWidget {
  const TelemetryDetailScreen({super.key});

  Color _getHealthColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.healthy:
        return AppColors.success;
      case HealthStatus.unhealthy:
        return AppColors.danger;
      default:
        return AppColors.cyan;
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final vehicleState = context.watch<VehicleState>();
    final units = context.watch<SettingsController>().unitSystem;
    final connected =
        vehicleState.connectionStatus == ConnectionStatus.connected;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('full_telemetry'.tr().toUpperCase()),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [
          _TelemetryBlock(
            label: 'battery'.tr().toUpperCase(),
            value: connected
                ? '${(vehicleState.batteryPercent ?? 0).toStringAsFixed(0)}%'
                : '--',
            subValue: connected
                ? '${(vehicleState.batteryVoltage ?? 0).toStringAsFixed(1)}V'
                : '',
            icon: Icons.battery_charging_full,
            color: AppColors.success,
            helpText:
                'Percentage of charge remaining in the flight battery and its current voltage.',
          ),
          _TelemetryBlock(
            label: 'altitude'.tr().toUpperCase(),
            value: connected
                ? units.formatDistance(vehicleState.altitudeMeters ?? 0)
                : '--',
            icon: Icons.height,
            color: AppColors.cyan,
            helpText:
                'Current height of the drone relative to the takeoff point.',
          ),
          _TelemetryBlock(
            label: 'ground_speed'.tr().toUpperCase(),
            value: connected
                ? units.formatSpeed(vehicleState.speedMps ?? 0)
                : '--',
            icon: Icons.speed,
            color: AppColors.amber,
            helpText: 'Horizontal speed of the drone relative to the ground.',
          ),
          _TelemetryBlock(
            label: 'vertical_speed'.tr().toUpperCase(),
            value: connected
                ? units.formatVerticalSpeed(vehicleState.verticalSpeedMps ?? 0)
                : '--',
            icon: (vehicleState.verticalSpeedMps ?? 0) < 0
                ? Icons.south
                : Icons.north,
            color: AppColors.cyan,
            helpText: 'The rate at which the drone is climbing or descending.',
          ),
          _TelemetryBlock(
            label: 'heading'.tr().toUpperCase(),
            value: connected
                ? '${(vehicleState.headingDegrees ?? 0).toStringAsFixed(0)}°'
                : '--',
            icon: Icons.explore,
            color: AppColors.amber,
            helpText: 'The compass direction the drone\'s nose is pointing.',
          ),
          _TelemetryBlock(
            label: 'gps_status'.tr().toUpperCase(),
            value: connected
                ? (vehicleState.latitude != null
                      ? 'fix'.tr().toUpperCase()
                      : 'no_fix'.tr().toUpperCase())
                : '--',
            subValue: connected && vehicleState.latitude != null
                ? 'Sats: ${vehicleState.gpsSatellites ?? 0}'
                : '',
            icon: Icons.gps_fixed,
            color: vehicleState.latitude != null
                ? AppColors.success
                : AppColors.danger,
            helpText:
                'GPS lock quality (3D Fix is ideal) and the number of satellites used for positioning.',
          ),
          _TelemetryBlock(
            label: 'sys_health'.tr().toUpperCase(),
            value: connected
                ? vehicleState.overallHealth.name.toUpperCase()
                : '--',
            subValue: connected
                ? '${vehicleState.activeAlerts.length} Alerts'
                : '',
            icon: Icons.health_and_safety,
            color: _getHealthColor(vehicleState.overallHealth),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VehicleHealthScreen()),
            ),
            helpText:
                'Overall status of onboard sensors (Gyro, Accel, Compass) and navigation filters.',
          ),
          _TelemetryBlock(
            label: 'dist_to_home'.tr().toUpperCase(),
            value: connected && vehicleState.distanceToHomeMeters != null
                ? units.formatDistance(vehicleState.distanceToHomeMeters!)
                : '--',
            icon: Icons.social_distance,
            color: AppColors.cyan,
            helpText:
                'Direct distance from the drone\'s current position to the recorded home point.',
          ),
          _TelemetryBlock(
            label: 'flight_time'.tr().toUpperCase(),
            value: connected && vehicleState.flightDuration != null
                ? _formatDuration(vehicleState.flightDuration!)
                : '--',
            icon: Icons.timer,
            color: AppColors.amber,
            helpText:
                'Elapsed time since the drone was armed and motors were started.',
          ),
        ],
      ),
    );
  }
}

class _TelemetryBlock extends StatelessWidget {
  const _TelemetryBlock({
    required this.label,
    required this.value,
    this.subValue = '',
    required this.icon,
    required this.color,
    this.onTap,
    this.helpText,
  });

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
        content: Text(helpText ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr().toUpperCase()),
          ),
        ],
      ),
    );
  }

  final String label;
  final String value;
  final String subValue;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? helpText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                if (helpText != null)
                  GestureDetector(
                    onTap: () => _showHelp(context),
                    child: Icon(
                      Icons.help_outline,
                      size: 14,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: telemetryNumberStyle.copyWith(
                fontSize: 22,
                color: scheme.onSurface,
              ),
            ),
            if (subValue.isNotEmpty)
              Text(
                subValue,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }
}
