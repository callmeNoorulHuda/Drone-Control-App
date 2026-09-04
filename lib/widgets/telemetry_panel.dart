import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';
import '../state/connection_status.dart';
import '../state/vehicle_state.dart';
import '../theme/app_theme.dart';
import '../state/settings_controller.dart';
import '../state/unit_system.dart';
import '../screens/telemetry_detail_screen.dart';

class TelemetryPanel extends StatelessWidget {
  const TelemetryPanel({super.key, this.compact = false});

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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final connected =
        vehicleState.connectionStatus == ConnectionStatus.connected;
    final hasFix =
        vehicleState.latitude != null && vehicleState.longitude != null;
    final distanceToHome = vehicleState.distanceToHomeMeters;
    final bearingToHome = vehicleState.bearingToHomeDegrees;
    final flightDuration = vehicleState.flightDuration;

    return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TelemetryDetailScreen()),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(compact ? 12 : 16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 16,
                  compact ? 10 : 14,
                  compact ? 12 : 16,
                  compact ? 10 : 14,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(compact ? 12 : 16),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black54 : Colors.black26,
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: compact ? 8 : 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                size: compact ? 14 : 16,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'telemetry'.tr().toUpperCase(),
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontSize: compact ? 12 : 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _TelemetryRow(
                        icon: Icons.battery_full,
                        label: 'battery'.tr(),
                        value: connected
                            ? '${(vehicleState.batteryPercent ?? 0).toStringAsFixed(0)}%'
                            : '--',
                        compact: compact,
                        index: 0,
                      ),
                      _TelemetryRow(
                        icon: Icons.height,
                        label: 'altitude'.tr(),
                        value: connected
                            ? units.formatDistance(
                                vehicleState.altitudeMeters ?? 0,
                              )
                            : '--',
                        compact: compact,
                        index: 1,
                      ),
                      _TelemetryRow(
                        icon: Icons.speed,
                        label: 'speed'.tr(),
                        value: connected
                            ? units.formatSpeed(vehicleState.speedMps ?? 0)
                            : '--',
                        compact: compact,
                        index: 2,
                      ),
                      _TelemetryRow(
                        icon: (vehicleState.verticalSpeedMps ?? 0) < 0
                            ? Icons.south
                            : Icons.north,
                        label: 'v_speed'.tr(),
                        value: connected
                            ? units.formatVerticalSpeed(
                                vehicleState.verticalSpeedMps ?? 0,
                              )
                            : '--',
                        compact: compact,
                        index: 3,
                      ),
                      _TelemetryRow(
                        icon: Icons.explore,
                        label: 'heading'.tr(),
                        value: connected
                            ? '${(vehicleState.headingDegrees ?? 0).toStringAsFixed(0)}°'
                            : '--',
                        compact: compact,
                        index: 4,
                      ),
                      _TelemetryRow(
                        icon: hasFix ? Icons.gps_fixed : Icons.gps_not_fixed,
                        label: 'gps'.tr(),
                        value: connected ? (hasFix ? 'Fix' : 'No Fix') : '--',
                        compact: compact,
                        index: 5,
                      ),
                      _TelemetryRow(
                        icon: Icons.social_distance,
                        label: 'dist_home'.tr(),
                        value: connected && distanceToHome != null
                            ? units.formatDistance(distanceToHome)
                            : '--',
                        compact: compact,
                        index: 6,
                      ),
                      _TelemetryRow(
                        icon: Icons.assistant_navigation,
                        label: 'brg_home'.tr(),
                        value: connected && bearingToHome != null
                            ? '${bearingToHome.toStringAsFixed(0)}°'
                            : '--',
                        compact: compact,
                        index: 7,
                      ),
                      _TelemetryRow(
                        icon: Icons.timer_outlined,
                        label: 'flight_time'.tr(),
                        value: connected && flightDuration != null
                            ? _formatDuration(flightDuration)
                            : '--',
                        compact: compact,
                        showDivider: false,
                        index: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
        .animate()
        .slideX(
          begin: 1.0,
          end: 0.0,
          duration: 600.ms,
          curve: Curves.easeOutCubic,
        )
        .fadeIn();
  }
}

class _TelemetryRow extends StatelessWidget {
  const _TelemetryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.compact,
    this.showDivider = true,
    required this.index,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool compact;
  final bool showDivider;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
              padding: EdgeInsets.symmetric(vertical: compact ? 7 : 9),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      icon,
                      size: compact ? 12 : 14,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: compact ? 9 : 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 3,
                    child: Text(
                      value,
                      style: telemetryNumberStyle.copyWith(
                        fontSize: compact ? 13 : 15,
                        color: scheme.secondary,
                        shadows: [
                          Shadow(
                            color: scheme.secondary.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(delay: (200 + index * 50).ms, duration: 400.ms)
            .slideX(begin: 0.2, end: 0.0, curve: Curves.easeOut),
        if (showDivider)
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.outlineVariant.withValues(alpha: 0),
                  scheme.outlineVariant.withValues(alpha: 0.5),
                  scheme.outlineVariant.withValues(alpha: 0),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
