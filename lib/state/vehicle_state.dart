import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'connection_status.dart';
import '../models/health_state.dart';
import '../models/mission_waypoint.dart';

enum MissionUploadStatus { idle, uploading, uploaded, failed }

enum MissionExecutionState {
  disconnected,
  connected,
  planning,
  ready,
  uploading,
  uploaded,
  failed,
  active,
  lost,
  complete,
}

/// Holds "everything currently known about the drone" in one place.
/// The MAVLink layer updates this as messages arrive; the UI layer only
/// ever reads from this, never from raw MAVLink messages directly.
///
/// This is a plain ChangeNotifier (no external state-management package
/// required) so screens rebuild via ListenableBuilder when values change.
class VehicleState extends ChangeNotifier {
  ConnectionStatus connectionStatus = ConnectionStatus.disconnected;
  DateTime? lastHeartbeat;
  bool connectionLost = false;
  bool armed = false;
  String currentMode = '--';

  double? batteryPercent;
  double? batteryVoltage;

  double? altitudeMeters;
  double? headingDegrees;
  double? speedMps;
  double? latitude;
  double? longitude;
  String? lastError;
  double? verticalSpeedMps; // positive = climbing, negative = descending

  int? gpsFixType;
  int? gpsSatellites;

  Map<String, ComponentHealth> sensorHealth = {};
  List<VehicleAlert> activeAlerts = [];
  VehicleAlert? lastNewAlert;

  // Captured once, the first time we're armed with a known GPS fix — this
  // is "home" for distance/bearing-to-home. Stays set across a disarm (so
  // the pilot can still see how far they are from launch after landing);
  // only cleared on reset() (disconnect).
  double? homeLatitude;
  double? homeLongitude;

  // Set the moment armed flips false->true, cleared the moment it flips
  // true->false. Drives the flight timer.
  DateTime? armedSince;

  // --- Mission & AUTO Mode State ------------------------------------
  List<MissionWaypoint> missionWaypoints = [];
  bool rtlAfterMission = true;
  MissionUploadStatus missionUploadStatus = MissionUploadStatus.idle;
  int? currentWaypointIndex;
  double wifiRangeMeters = 500.0;

  // Track if we are in AUTO mode (screen level state usually, but here for consistency)
  bool isAutoMode = false;

  // Last known telemetry for connection loss
  double? lastKnownLat;
  double? lastKnownLon;
  double? lastKnownAlt;
  double? lastKnownSpeed;
  double? lastKnownBattery;
  String? lastKnownMode;
  int? lastKnownWaypoint;
  DateTime? lastTelemetryTime;

  MissionExecutionState get missionExecutionState {
    if (connectionStatus != ConnectionStatus.connected) {
      if (connectionLost) return MissionExecutionState.lost;
      return MissionExecutionState.disconnected;
    }

    if (currentMode == 'AUTO') {
      if (currentWaypointIndex != null &&
          missionWaypoints.isNotEmpty &&
          currentWaypointIndex! >= missionWaypoints.length) {
        return MissionExecutionState.complete;
      }
      return MissionExecutionState.active;
    }

    if (missionUploadStatus == MissionUploadStatus.uploading)
      return MissionExecutionState.uploading;
    if (missionUploadStatus == MissionUploadStatus.uploaded)
      return MissionExecutionState.uploaded;
    if (missionUploadStatus == MissionUploadStatus.failed)
      return MissionExecutionState.failed;

    if (missionWaypoints.isNotEmpty) return MissionExecutionState.ready;

    return MissionExecutionState.planning;
  }

  void setMissionWaypoints(List<MissionWaypoint> waypoints) {
    missionWaypoints = waypoints;
    missionUploadStatus = MissionUploadStatus.idle;
    notifyListeners();
  }

  void addWaypoint(double lat, double lon) {
    final seq = missionWaypoints.length;
    missionWaypoints.add(MissionWaypoint(lat: lat, lon: lon, seq: seq));
    missionUploadStatus = MissionUploadStatus.idle;
    notifyListeners();
  }

  void updateWaypointAltitude(int index, double alt) {
    if (index >= 0 && index < missionWaypoints.length) {
      missionWaypoints[index].alt = alt;
      missionUploadStatus = MissionUploadStatus.idle;
      notifyListeners();
    }
  }

  void removeWaypoint(int index) {
    if (index >= 0 && index < missionWaypoints.length) {
      missionWaypoints.removeAt(index);
      // Re-sequence
      for (int i = 0; i < missionWaypoints.length; i++) {
        missionWaypoints[i] = missionWaypoints[i].copyWith(seq: i);
      }
      missionUploadStatus = MissionUploadStatus.idle;
      notifyListeners();
    }
  }

  void clearWaypoints() {
    missionWaypoints.clear();
    missionUploadStatus = MissionUploadStatus.idle;
    currentWaypointIndex = null;
    notifyListeners();
  }

  void reorderWaypoints(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = missionWaypoints.removeAt(oldIndex);
    missionWaypoints.insert(newIndex, item);
    // Re-sequence
    for (int i = 0; i < missionWaypoints.length; i++) {
      missionWaypoints[i] = missionWaypoints[i].copyWith(seq: i);
    }
    missionUploadStatus = MissionUploadStatus.idle;
    notifyListeners();
  }

  void setRtlAfterMission(bool value) {
    rtlAfterMission = value;
    missionUploadStatus = MissionUploadStatus.idle;
    notifyListeners();
  }

  void setMissionUploadStatus(MissionUploadStatus status) {
    missionUploadStatus = status;
    notifyListeners();
  }

  void applyMissionCurrent(int seq) {
    currentWaypointIndex = seq;
    notifyListeners();
  }

  void setWifiRange(double meters) {
    wifiRangeMeters = meters;
    notifyListeners();
  }

  void setError(String message) {
    lastError = message;
    notifyListeners();
  }

  void clearError() {
    lastError = null;
    notifyListeners();
  }

  void setConnectionStatus(ConnectionStatus status) {
    connectionStatus = status;
    notifyListeners();
  }

  void applyHeartbeat({required bool armed, required String mode}) {
    final justArmed = armed && !this.armed;
    final justDisarmed = !armed && this.armed;
    this.armed = armed;
    currentMode = mode;
    lastHeartbeat = DateTime.now();
    connectionLost = false;
    lastKnownMode = mode;
    lastTelemetryTime = DateTime.now();

    if (justArmed) {
      armedSince = DateTime.now();
      if (homeLatitude == null && latitude != null && longitude != null) {
        homeLatitude = latitude;
        homeLongitude = longitude;
      }
    }
    if (justDisarmed) {
      armedSince = null;
    }
    notifyListeners();
  }

  void applyBattery({required double percent, required double voltage}) {
    batteryPercent = percent;
    batteryVoltage = voltage;
    lastKnownBattery = percent;
    lastTelemetryTime = DateTime.now();
    notifyListeners();
  }

  void updateSensorHealth(String name, HealthStatus status, {String? details}) {
    final prev = sensorHealth[name];
    sensorHealth[name] = ComponentHealth(
      name: name,
      status: status,
      details: details,
    );

    // If it was unhealthy and now it's healthy, maybe show a recovery alert
    if (prev != null &&
        prev.status == HealthStatus.unhealthy &&
        status == HealthStatus.healthy) {
      addAlert(
        VehicleAlert(
          id: 'recovery_$name',
          message: '✓ $name health restored.',
          severity: AlertSeverity.info,
        ),
      );
    } else if (status == HealthStatus.unhealthy) {
      addAlert(
        VehicleAlert(
          id: 'health_$name',
          message: '⚠ $name health problem detected',
          severity: AlertSeverity.warning,
        ),
      );
    }
    notifyListeners();
  }

  void addAlert(VehicleAlert alert) {
    // Deduplicate: don't add if an alert with same message/id is already there
    // but update timestamp if it's the same ID.
    final existingIndex = activeAlerts.indexWhere((a) => a.id == alert.id);
    if (existingIndex != -1) {
      if (activeAlerts[existingIndex].message == alert.message) {
        // Same alert, just update it if needed, or ignore to avoid spamming
        return;
      }
      activeAlerts.removeAt(existingIndex);
    }

    activeAlerts.add(alert);
    lastNewAlert = alert;
    notifyListeners();
  }

  void removeAlert(String id) {
    activeAlerts.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  void applyGpsStatus({required int fixType, required int satellites}) {
    gpsFixType = fixType;
    gpsSatellites = satellites;

    if (fixType <= 1) {
      updateSensorHealth('GPS', HealthStatus.unhealthy, details: 'No Fix');
    } else {
      updateSensorHealth(
        'GPS',
        HealthStatus.healthy,
        details: 'Fix: ${fixType}D, Sats: $satellites',
      );
    }
    notifyListeners();
  }

  HealthStatus get overallHealth {
    if (connectionLost) return HealthStatus.unknown;
    if (activeAlerts.any((a) => a.severity == AlertSeverity.critical)) {
      return HealthStatus.unhealthy; // Or define a 'critical' health status
    }
    if (activeAlerts.any((a) => a.severity == AlertSeverity.warning)) {
      return HealthStatus.unhealthy;
    }
    return HealthStatus.healthy;
  }

  void applyPosition({
    required double alt,
    required double heading,
    required double speed,
    required double verticalSpeed,
    required double lat,
    required double lon,
  }) {
    altitudeMeters = alt;
    headingDegrees = heading;
    speedMps = speed;
    verticalSpeedMps = verticalSpeed;
    latitude = lat;
    longitude = lon;

    lastKnownLat = lat;
    lastKnownLon = lon;
    lastKnownAlt = alt;
    lastKnownSpeed = speed;
    lastTelemetryTime = DateTime.now();

    // Fallback: if we armed before any GPS fix had arrived, the capture
    // in applyHeartbeat was skipped — grab it here instead, the first
    // time a fix arrives while armed.
    if (armed && homeLatitude == null) {
      homeLatitude = lat;
      homeLongitude = lon;
    }
    notifyListeners();
  }

  double? get distanceToHomeMeters {
    if (homeLatitude == null ||
        homeLongitude == null ||
        latitude == null ||
        longitude == null) {
      return null;
    }
    const earthRadiusMeters = 6371000.0;
    final dLat = _degToRad(latitude! - homeLatitude!);
    final dLon = _degToRad(longitude! - homeLongitude!);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(homeLatitude!)) *
            math.cos(_degToRad(latitude!)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Compass bearing (0-360) FROM the current position TO home.
  double? get bearingToHomeDegrees {
    if (homeLatitude == null ||
        homeLongitude == null ||
        latitude == null ||
        longitude == null) {
      return null;
    }
    final lat1 = _degToRad(latitude!);
    final lat2 = _degToRad(homeLatitude!);
    final dLon = _degToRad(homeLongitude! - longitude!);
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final bearing = _radToDeg(math.atan2(y, x));
    return (bearing + 360) % 360;
  }

  /// Elapsed time since last armed. Null when disarmed. Call from
  /// build(), not once and cached — it needs to be fresh every rebuild.
  Duration? get flightDuration {
    final since = armedSince;
    if (since == null) return null;
    return DateTime.now().difference(since);
  }

  static double _degToRad(double deg) => deg * (math.pi / 180);
  static double _radToDeg(double rad) => rad * (180 / math.pi);

  void markConnectionLost() {
    connectionStatus = ConnectionStatus.disconnected;
    connectionLost = true;
    notifyListeners();
  }

  void reset() {
    connectionStatus = ConnectionStatus.disconnected;
    armed = false;
    currentMode = '--';
    batteryPercent = null;
    batteryVoltage = null;
    altitudeMeters = null;
    headingDegrees = null;
    speedMps = null;
    latitude = null;
    longitude = null;
    connectionLost = false;
    verticalSpeedMps = null;
    homeLatitude = null;
    homeLongitude = null;
    armedSince = null;
    gpsFixType = null;
    gpsSatellites = null;
    sensorHealth.clear();
    activeAlerts.clear();
    lastNewAlert = null;
    notifyListeners();
  }
}
