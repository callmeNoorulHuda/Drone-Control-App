import 'package:flutter/material.dart';
import '../state/connection_status.dart';
import '../state/vehicle_state.dart';
import '../theme/app_theme.dart';

/// Compact vertical telemetry card that floats over the top-right corner
/// of the map, matching the reference layout's "TELEMETRY" readout box.
///
/// Only shows readings VehicleState actually has (battery, altitude,
/// speed, heading). GPS satellite count and distance-to-home aren't wired
/// up yet — add them here once SYS_STATUS / home-position tracking exists,
/// rather than showing placeholder numbers now.
class TelemetryPanel extends StatelessWidget {
  const TelemetryPanel({
    super.key,
    required this.vehicleState,
    this.compact = false,
  });

  final VehicleState vehicleState;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final connected =
        vehicleState.connectionStatus == ConnectionStatus.connected;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 14,
        compact ? 9 : 12,
        compact ? 10 : 14,
        compact ? 9 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'TELEMETRY',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: compact ? 9.5 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: compact ? 7 : 10),
          _Row(
            icon: Icons.battery_full,
            label: 'Battery',
            value: connected
                ? '${(vehicleState.batteryPercent ?? 0).toStringAsFixed(0)}%'
                : '--',
            compact: compact,
          ),
          _Row(
            icon: Icons.height,
            label: 'Altitude',
            value: connected
                ? '${(vehicleState.altitudeMeters ?? 0).toStringAsFixed(1)} m'
                : '--',
            compact: compact,
          ),
          _Row(
            icon: Icons.speed,
            label: 'Speed',
            value: connected
                ? '${(vehicleState.speedMps ?? 0).toStringAsFixed(1)} m/s'
                : '--',
            compact: compact,
          ),
          _Row(
            icon: Icons.explore,
            label: 'Heading',
            value: connected
                ? '${(vehicleState.headingDegrees ?? 0).toStringAsFixed(0)}°'
                : '--',
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    required this.compact,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 5 : 8),
      child: Row(
        children: [
          Icon(icon, size: compact ? 12 : 14, color: AppColors.textSecondary),
          SizedBox(width: compact ? 5 : 6),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: compact ? 10.5 : 12,
              ),
            ),
          ),
          Text(
            value,
            style: telemetryNumberStyle.copyWith(fontSize: compact ? 11 : 13),
          ),
        ],
      ),
    );
  }
}
