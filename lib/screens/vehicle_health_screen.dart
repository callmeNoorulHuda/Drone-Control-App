import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../state/vehicle_state.dart';
import '../models/health_state.dart';
import '../theme/app_theme.dart';

class VehicleHealthScreen extends StatelessWidget {
  const VehicleHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vehicleState = context.watch<VehicleState>();

    return Scaffold(
      appBar: AppBar(
        title: Text('drone_health'.tr().toUpperCase()),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: 'systems'.tr().toUpperCase()),
          ...vehicleState.sensorHealth.values.map(
            (h) =>
                _HealthItem(name: h.name, status: h.status, details: h.details),
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: 'battery'.tr().toUpperCase()),
          _HealthItem(
            name: 'battery'.tr(),
            status: _getBatteryHealth(vehicleState.batteryPercent),
            details: vehicleState.batteryPercent != null
                ? '${vehicleState.batteryPercent!.toStringAsFixed(0)}% (${vehicleState.batteryVoltage?.toStringAsFixed(1)}V)'
                : 'unknown'.tr(),
          ),
          const SizedBox(height: 20),
          if (vehicleState.activeAlerts.isNotEmpty) ...[
            _SectionHeader(title: 'active_alerts'.tr().toUpperCase()),
            ...vehicleState.activeAlerts.reversed.map(
              (a) => _AlertItem(alert: a),
            ),
          ],
        ],
      ),
    );
  }

  HealthStatus _getBatteryHealth(double? percent) {
    if (percent == null) return HealthStatus.unknown;
    if (percent < 10) return HealthStatus.unhealthy;
    return HealthStatus.healthy;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: scheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _HealthItem extends StatelessWidget {
  final String name;
  final HealthStatus status;
  final String? details;

  const _HealthItem({required this.name, required this.status, this.details});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    IconData icon;
    Color color;
    String statusText;

    switch (status) {
      case HealthStatus.healthy:
        icon = Icons.check_circle;
        color = AppColors.success;
        statusText = 'healthy'.tr();
        break;
      case HealthStatus.unhealthy:
        icon = Icons.warning;
        color = AppColors.danger;
        statusText = 'unhealthy'.tr();
        break;
      case HealthStatus.notPresent:
        icon = Icons.remove_circle_outline;
        color = scheme.onSurfaceVariant;
        statusText = 'not_present'.tr();
        break;
      case HealthStatus.notEnabled:
        icon = Icons.pause_circle_outline;
        color = AppColors.amber;
        statusText = 'disabled'.tr();
        break;
      case HealthStatus.unknown:
      default:
        icon = Icons.help_outline;
        color = scheme.onSurfaceVariant;
        statusText = 'unknown'.tr();
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (details != null)
                  Text(
                    details!,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            statusText.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertItem extends StatelessWidget {
  final VehicleAlert alert;
  const _AlertItem({required this.alert});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color color;
    IconData icon;

    switch (alert.severity) {
      case AlertSeverity.critical:
        color = AppColors.danger;
        icon = Icons.error;
        break;
      case AlertSeverity.warning:
        color = AppColors.amber;
        icon = Icons.warning;
        break;
      case AlertSeverity.info:
        color =
            scheme.secondary; // More neutral blue/grey than the amber primary
        icon = Icons.info;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              alert.message,
              style: TextStyle(color: scheme.onSurface, fontSize: 13),
            ),
          ),
          Text(
            '${alert.timestamp.hour.toString().padLeft(2, '0')}:${alert.timestamp.minute.toString().padLeft(2, '0')}:${alert.timestamp.second.toString().padLeft(2, '0')}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
