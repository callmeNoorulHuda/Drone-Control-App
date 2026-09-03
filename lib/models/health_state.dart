import 'package:flutter/material.dart';

enum HealthStatus { healthy, unhealthy, notPresent, notEnabled, unknown }

enum AlertSeverity { info, warning, critical }

class VehicleAlert {
  final String id;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;

  VehicleAlert({
    required this.id,
    required this.message,
    required this.severity,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleAlert &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ComponentHealth {
  final String name;
  final HealthStatus status;
  final String? details;
  final DateTime lastUpdate;

  ComponentHealth({
    required this.name,
    required this.status,
    this.details,
    DateTime? lastUpdate,
  }) : lastUpdate = lastUpdate ?? DateTime.now();

  bool get isStale =>
      DateTime.now().difference(lastUpdate) > const Duration(seconds: 10);
}
