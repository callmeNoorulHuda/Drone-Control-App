import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/connection_status.dart';
import '../state/vehicle_state.dart';
import '../theme/app_theme.dart';
import '../state/settings_controller.dart';
import '../state/unit_system.dart';
import '../screens/telemetry_detail_screen.dart';

/// Compact vertical telemetry card that floats over the top-right corner
/// of the map, matching the reference layout's "TELEMETRY" readout box.
///
/// Only shows readings VehicleState actually has (battery, altitude,
/// speed, heading). GPS satellite count and distance-to-home aren't wired
/// up yet — add them here once SYS_STATUS / home-position tracking exists,
/// rather than showing placeholder numbers now.
class TelemetryPanel extends StatelessWidget {
  const TelemetryPanel({super.key, this.compact = false});

  // vehicleState field removed — fetched via context.watch below instead.
  final bool compact;

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
    final hasFix =
        vehicleState.latitude != null && vehicleState.longitude != null;
    final distanceToHome = vehicleState.distanceToHomeMeters;
    final bearingToHome = vehicleState.bearingToHomeDegrees;
    final flightDuration = vehicleState.flightDuration;

    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const TelemetryDetailScreen())),
      child: Container(
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
              blurRadius: 10,
              offset: Offset(0, 10),
            ),
          ],
        ),
        // Scrollable now — there are more rows than always fit on a small
        // phone's fixed-width side panel; this just prevents overflow.
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: compact ? 8 : 12),
                  child: Text(
                    'TELEMETRY',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: compact ? 12 : 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              _TelemetryRow(
                icon: Icons.battery_full,
                label: 'Battery',
                value: connected
                    ? '${(vehicleState.batteryPercent ?? 0).toStringAsFixed(0)}%'
                    : '--',
                compact: compact,
              ),
              _TelemetryRow(
                icon: Icons.height,
                label: 'Altitude',
                value: connected
                    ? units.formatDistance(vehicleState.altitudeMeters ?? 0)
                    : '--',
                compact: compact,
              ),
              _TelemetryRow(
                icon: Icons.speed,
                label: 'Speed',
                value: connected
                    ? units.formatSpeed(vehicleState.speedMps ?? 0)
                    : '--',
                compact: compact,
              ),
              _TelemetryRow(
                icon: (vehicleState.verticalSpeedMps ?? 0) < 0
                    ? Icons.south
                    : Icons.north,
                label: 'V. Speed',
                value: connected
                    ? units.formatVerticalSpeed(
                        vehicleState.verticalSpeedMps ?? 0,
                      )
                    : '--',
                compact: compact,
              ),
              _TelemetryRow(
                icon: Icons.explore,
                label: 'Heading',
                value: connected
                    ? '${(vehicleState.headingDegrees ?? 0).toStringAsFixed(0)}°'
                    : '--',
                compact: compact,
              ),
              _TelemetryRow(
                icon: hasFix ? Icons.gps_fixed : Icons.gps_not_fixed,
                label: 'GPS',
                value: connected ? (hasFix ? 'Fix' : 'No Fix') : '--',
                compact: compact,
              ),
              _TelemetryRow(
                icon: Icons.social_distance,
                label: 'Dist. Home',
                value: connected && distanceToHome != null
                    ? units.formatDistance(distanceToHome)
                    : '--',
                compact: compact,
              ),
              _TelemetryRow(
                icon: Icons.assistant_navigation,
                label: 'Brg. Home',
                value: connected && bearingToHome != null
                    ? '${bearingToHome.toStringAsFixed(0)}°'
                    : '--',
                compact: compact,
              ),
              _TelemetryRow(
                icon: Icons.timer_outlined,
                label: 'Flight Time',
                value: connected && flightDuration != null
                    ? _formatDuration(flightDuration)
                    : '--',
                compact: compact,
                showDivider: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TelemetryRow extends StatelessWidget {
  const _TelemetryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.compact,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool compact;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 6 : 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: compact ? 14 : 16,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                value,
                style: telemetryNumberStyle.copyWith(
                  fontSize: compact ? 13 : 15,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: AppColors.hairline.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}
