import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'full_telemetry'.tr().toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontFamily: 'monospace',
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background HUD Elements
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(
                painter: _HUDGridPainter(color: scheme.primary),
              ),
            ),
          ),
          GridView.count(
            padding: const EdgeInsets.all(20),
            crossAxisCount: MediaQuery.of(context).size.width > 900
                ? 4
                : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.3,
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
                index: 0,
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
                index: 1,
              ),
              _TelemetryBlock(
                label: 'ground_speed'.tr().toUpperCase(),
                value: connected
                    ? units.formatSpeed(vehicleState.speedMps ?? 0)
                    : '--',
                icon: Icons.speed,
                color: AppColors.amber,
                helpText:
                    'Horizontal speed of the drone relative to the ground.',
                index: 2,
              ),
              _TelemetryBlock(
                label: 'vertical_speed'.tr().toUpperCase(),
                value: connected
                    ? units.formatVerticalSpeed(
                        vehicleState.verticalSpeedMps ?? 0,
                      )
                    : '--',
                icon: (vehicleState.verticalSpeedMps ?? 0) < 0
                    ? Icons.south
                    : Icons.north,
                color: AppColors.cyan,
                helpText:
                    'The rate at which the drone is climbing or descending.',
                index: 3,
              ),
              _TelemetryBlock(
                label: 'heading'.tr().toUpperCase(),
                value: connected
                    ? '${(vehicleState.headingDegrees ?? 0).toStringAsFixed(0)}°'
                    : '--',
                icon: Icons.explore,
                color: AppColors.amber,
                helpText:
                    'The compass direction the drone\'s nose is pointing.',
                index: 4,
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
                index: 5,
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
                  MaterialPageRoute(
                    builder: (_) => const VehicleHealthScreen(),
                  ),
                ),
                helpText:
                    'Overall status of onboard sensors (Gyro, Accel, Compass) and navigation filters.',
                index: 6,
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
                index: 7,
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
                index: 8,
              ),
            ],
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
    required this.index,
  });

  void _showHelp(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(
          helpText ?? '',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'close'.tr().toUpperCase(),
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
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
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, size: 16, color: color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          value,
                          style: telemetryNumberStyle.copyWith(
                            fontSize: 26,
                            color: scheme.onSurface,
                            shadows: [
                              Shadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        if (subValue.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              subValue,
                              style: TextStyle(
                                color: color.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (helpText != null)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _showHelp(context),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (index * 80).ms, duration: 500.ms)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic)
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(
          delay: 2.seconds,
          duration: 3.seconds,
          color: color.withValues(alpha: 0.1),
        );
  }
}

class _HUDGridPainter extends CustomPainter {
  final Color color;
  _HUDGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 60.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Circle HUD elements
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      200,
      paint..strokeWidth = 1,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      350,
      paint..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
