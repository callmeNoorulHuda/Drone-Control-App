import 'dart:async';
import 'dart:math';
import '../state/connection_status.dart';
import '../state/vehicle_state.dart';

/// Owns the connection lifecycle and feeds VehicleState from incoming data.
///
/// STUBBED FOR NOW: this class currently simulates a connection and fake
/// telemetry so the UI is fully demoable before the real MAVLink socket
/// exists. Every method below is written to match the shape the real
/// implementation will have (per the roadmap: open a UDP socket, feed
/// bytes into dart_mavlink's parser, update VehicleState from parsed
/// messages) — swapping the mock body out for real dart_mavlink calls
/// should not require changing any screen.
///
/// TODO (Week 2): replace _mockConnect/_mockTelemetryLoop with:
///   - RawDatagramSocket bound to the bridge IP/port
///   - MavlinkParser(MavlinkDialectCommon()) parsing incoming bytes
///   - VehicleState.applyHeartbeat/applyBattery/applyPosition driven by
///     real HEARTBEAT / SYS_STATUS / GLOBAL_POSITION_INT messages
class ConnectionManager {
  ConnectionManager(this.vehicleState);

  final VehicleState vehicleState;

  Timer? _heartbeatTimeoutTimer;
  Timer? _mockTelemetryTimer;
  final _rand = Random();

  Future<void> connect({required String ip, required int port}) async {
    vehicleState.setConnectionStatus(ConnectionStatus.connecting);
    await _mockConnect();
    vehicleState.setConnectionStatus(ConnectionStatus.connected);
    _startMockTelemetry();
  }

  void disconnect() {
    _mockTelemetryTimer?.cancel();
    _heartbeatTimeoutTimer?.cancel();
    vehicleState.reset();
  }

  Future<void> armDisarm(bool arm) async {
    // TODO (Week 3): send COMMAND_LONG with MAV_CMD_COMPONENT_ARM_DISARM
    vehicleState.applyHeartbeat(armed: arm, mode: vehicleState.currentMode);
  }

  Future<void> setMode(String mode) async {
    // TODO (Week 3): send COMMAND_LONG with MAV_CMD_DO_SET_MODE
    vehicleState.applyHeartbeat(armed: vehicleState.armed, mode: mode);
  }

  Future<void> sendManualControl({
    required double throttle,
    required double yaw,
    required double pitch,
    required double roll,
  }) async {
    // TODO (Week 3): pack into MANUAL_CONTROL and send on a repeating timer
    // while the pilot is actively touching the sticks.
  }

  Future<void> returnToLaunch() async {
    // TODO (Week 3): send MAV_CMD_NAV_RETURN_TO_LAUNCH
    vehicleState.applyHeartbeat(armed: vehicleState.armed, mode: 'RTL');
  }

  Future<void> _mockConnect() => Future.delayed(const Duration(milliseconds: 900));

  void _startMockTelemetry() {
    vehicleState.applyHeartbeat(armed: false, mode: 'Stabilize');
    vehicleState.applyBattery(percent: 92, voltage: 12.4);
    vehicleState.applyPosition(
      alt: 0, heading: 0, speed: 0, lat: 33.6844, lon: 73.0479,
    );

    _mockTelemetryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final battery = (vehicleState.batteryPercent ?? 92) - 0.05;
      final alt = vehicleState.armed
          ? (vehicleState.altitudeMeters ?? 0) + (_rand.nextDouble() - 0.3)
          : 0.0;
      final heading =
          ((vehicleState.headingDegrees ?? 0) + _rand.nextDouble() * 4) % 360;
      final speed = vehicleState.armed
          ? (2.5 + _rand.nextDouble() * 3).toDouble()
          : 0.0;
      vehicleState.applyBattery(
        percent: battery.clamp(0, 100).toDouble(),
        voltage: 10.5 + (battery / 100) * 2.6,
      );
      vehicleState.applyPosition(
        alt: alt.clamp(0, 1000).toDouble(),
        heading: heading,
        speed: speed,
        lat: vehicleState.latitude ?? 33.6844,
        lon: vehicleState.longitude ?? 73.0479,
      );
    });
  }

  void dispose() {
    _mockTelemetryTimer?.cancel();
    _heartbeatTimeoutTimer?.cancel();
  }
}
