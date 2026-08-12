import 'package:flutter/foundation.dart';
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

  bool armed = false;
  String currentMode = '--';

  double? batteryPercent;
  double? batteryVoltage;

  double? altitudeMeters;
  double? headingDegrees;
  double? speedMps;
  double? latitude;
  double? longitude;

  void setConnectionStatus(ConnectionStatus status) {
    connectionStatus = status;
    notifyListeners();
  }

  void applyHeartbeat({required bool armed, required String mode}) {
    this.armed = armed;
    currentMode = mode;
    lastHeartbeat = DateTime.now();
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
    required double lat,
    required double lon,
  }) {
    altitudeMeters = alt;
    headingDegrees = heading;
    speedMps = speed;
    latitude = lat;
    longitude = lon;
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
    notifyListeners();
  }
}
