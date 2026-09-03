import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../state/vehicle_state.dart';
import '../state/connection_status.dart';
import '../state/settings_controller.dart';
import '../state/unit_system.dart';
import '../theme/app_theme.dart';

class TelemetryDetailScreen extends StatelessWidget {
  const TelemetryDetailScreen({super.key});

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
          ),
          _TelemetryBlock(
            label: 'altitude'.tr().toUpperCase(),
            value: connected
                ? units.formatDistance(vehicleState.altitudeMeters ?? 0)
                : '--',
            icon: Icons.height,
            color: AppColors.cyan,
          ),
          _TelemetryBlock(
            label: 'ground_speed'.tr().toUpperCase(),
            value: connected
                ? units.formatSpeed(vehicleState.speedMps ?? 0)
                : '--',
            icon: Icons.speed,
            color: AppColors.amber,
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
          ),
          _TelemetryBlock(
            label: 'heading'.tr().toUpperCase(),
            value: connected
                ? '${(vehicleState.headingDegrees ?? 0).toStringAsFixed(0)}°'
                : '--',
            icon: Icons.explore,
            color: AppColors.amber,
          ),
          _TelemetryBlock(
            label: 'gps_status'.tr().toUpperCase(),
            value: connected
                ? (vehicleState.latitude != null
                      ? 'fix'.tr().toUpperCase()
                      : 'no_fix'.tr().toUpperCase())
                : '--',
            subValue: connected && vehicleState.latitude != null
                ? '${vehicleState.latitude!.toStringAsFixed(4)}, ${vehicleState.longitude!.toStringAsFixed(4)}'
                : '',
            icon: Icons.gps_fixed,
            color: vehicleState.latitude != null
                ? AppColors.success
                : AppColors.danger,
          ),
          _TelemetryBlock(
            label: 'dist_to_home'.tr().toUpperCase(),
            value: connected && vehicleState.distanceToHomeMeters != null
                ? units.formatDistance(vehicleState.distanceToHomeMeters!)
                : '--',
            icon: Icons.social_distance,
            color: AppColors.cyan,
          ),
          _TelemetryBlock(
            label: 'flight_time'.tr().toUpperCase(),
            value: connected && vehicleState.flightDuration != null
                ? _formatDuration(vehicleState.flightDuration!)
                : '--',
            icon: Icons.timer,
            color: AppColors.amber,
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
  });

  final String label;
  final String value;
  final String subValue;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
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
              Text(
                label,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
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
    );
  }
}
