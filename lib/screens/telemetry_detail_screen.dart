import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('FULL TELEMETRY'),
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
            label: 'BATTERY',
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
            label: 'ALTITUDE',
            value: connected
                ? units.formatDistance(vehicleState.altitudeMeters ?? 0)
                : '--',
            icon: Icons.height,
            color: AppColors.cyan,
          ),
          _TelemetryBlock(
            label: 'GROUND SPEED',
            value: connected
                ? units.formatSpeed(vehicleState.speedMps ?? 0)
                : '--',
            icon: Icons.speed,
            color: AppColors.amber,
          ),
          _TelemetryBlock(
            label: 'VERTICAL SPEED',
            value: connected
                ? units.formatVerticalSpeed(vehicleState.verticalSpeedMps ?? 0)
                : '--',
            icon: (vehicleState.verticalSpeedMps ?? 0) < 0
                ? Icons.south
                : Icons.north,
            color: AppColors.cyan,
          ),
          _TelemetryBlock(
            label: 'HEADING',
            value: connected
                ? '${(vehicleState.headingDegrees ?? 0).toStringAsFixed(0)}°'
                : '--',
            icon: Icons.explore,
            color: AppColors.amber,
          ),
          _TelemetryBlock(
            label: 'GPS STATUS',
            value: connected
                ? (vehicleState.latitude != null ? 'FIX' : 'NO FIX')
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
            label: 'DIST. TO HOME',
            value: connected && vehicleState.distanceToHomeMeters != null
                ? units.formatDistance(vehicleState.distanceToHomeMeters!)
                : '--',
            icon: Icons.social_distance,
            color: AppColors.cyan,
          ),
          _TelemetryBlock(
            label: 'FLIGHT TIME',
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
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
                style: const TextStyle(
                  color: AppColors.textSecondary,
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
              color: AppColors.textPrimary,
            ),
          ),
          if (subValue.isNotEmpty)
            Text(
              subValue,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}
