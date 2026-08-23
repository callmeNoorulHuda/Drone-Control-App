import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'connection_status.dart';

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

  // Captured once, the first time we're armed with a known GPS fix — this
  // is "home" for distance/bearing-to-home. Stays set across a disarm (so
  // the pilot can still see how far they are from launch after landing);
  // only cleared on reset() (disconnect).
  double? homeLatitude;
  double? homeLongitude;

  // Set the moment armed flips false->true, cleared the moment it flips
  // true->false. Drives the flight timer.
  DateTime? armedSince;

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
    notifyListeners();
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
    notifyListeners();
  }
}
