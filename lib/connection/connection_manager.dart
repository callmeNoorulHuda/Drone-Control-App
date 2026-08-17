import 'dart:async';
import 'dart:io';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';
import '../state/connection_status.dart';
import '../state/vehicle_state.dart';

const int _mySystemId = 255;
const int _myComponentId = mavTypeGcs;
int _sequence = 0;

/// Owns the real MAVLink connection: opens a UDP socket, feeds incoming
/// bytes into dart_mavlink's parser, and updates VehicleState from
/// whatever telemetry arrives.
///
/// STATUS: this class now genuinely RECEIVES and reads real data (verified
/// first in bin/heartbeat_test.dart before being moved in here, per the
/// roadmap's "prove it standalone first" rule). SENDING commands
/// (arm/disarm, mode changes, manual control) is still TODO — that's next
/// week's task, following the exact same pattern already used below for
/// Heartbeat.
class ConnectionManager {
  ConnectionManager(this.vehicleState);

  final VehicleState vehicleState;

  RawDatagramSocket? _socket;
  MavlinkParser? _parser;
  StreamSubscription? _parserSubscription;

  // Where we'll eventually SEND commands once arm/mode/manual control are
  // implemented (Week 3). Stored now, unused until then — today this class
  // only listens, it doesn't transmit anything yet.
  String? _targetIp;
  int? _targetPort;

  Future<void> connect({required String ip, required int port}) async {
    _targetIp = ip;
    _targetPort = port;

    vehicleState.setConnectionStatus(ConnectionStatus.connecting);

    // The "dialect" is the vocabulary of message types we know how to
    // decode — the base common.xml set from Monday's reading.
    final dialect = MavlinkDialectCommon();
    _parser = MavlinkParser(dialect);

    // Every time the parser finishes decoding one full, valid message, it
    // announces it here. We only act on Heartbeat for now — SYS_STATUS
    // and GLOBAL_POSITION_INT handling get added the same way, next.
    _parserSubscription = _parser!.stream.listen(_handleFrame);

    // Claim this port on this machine, before any data has arrived yet —
    // same "install the mailbox first" step as bin/heartbeat_test.dart.
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);

    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram != null) {
          _parser!.parse(datagram.data);
        }
      }
    });

    // MAVLink itself has no explicit "you are now connected" signal — we
    // treat "connected" as "the socket is open and listening." The first
    // real Heartbeat (below) is the actual proof it's alive; this just
    // reflects that we're ready and waiting for it.
    vehicleState.setConnectionStatus(ConnectionStatus.connected);
  }

  void _handleFrame(MavlinkFrame frame) {
    final message = frame.message;
    // print('[DEBUG] Received message type: ${message.runtimeType}');

    if (message is Heartbeat) {
      // Bit 128 in base_mode is the "armed" flag (from Day 1's glossary).
      final armed = (message.baseMode & 128) != 0;
      // customMode is just a raw number here — turning it into a readable
      // name like "Stabilize"/"Loiter" needs ArduPilot's mode-number
      // lookup table, which is still TODO. Showing the raw number for now
      // is enough to prove real data is flowing correctly.
      print(
        '[ConnectionManager] Heartbeat received — armed: $armed, mode: ${message.customMode}',
      );
      vehicleState.applyHeartbeat(
        armed: armed,
        mode: message.customMode.toString(),
      );
    }

    if (message is SysStatus) {
      // voltage_battery is millivolts, current_battery is centiamps —
      // both raw integer fields, scaled down to normal units here.
      final volts = message.voltageBattery / 1000.0;
      final percent = message.batteryRemaining.toDouble();
      print(
        '[ConnectionManager] SysStatus — battery: ${percent.toStringAsFixed(0)}%, ${volts.toStringAsFixed(1)}V',
      );
      vehicleState.applyBattery(percent: percent, voltage: volts);
    }

    if (message is GlobalPositionInt) {
      // lat/lon are degrees * 1e7, alt/relative_alt are millimeters,
      // hdg is centidegrees — all scaled down to normal units here.
      final lat = message.lat / 1e7;
      final lon = message.lon / 1e7;
      final alt = message.relativeAlt / 1000.0;
      final heading = message.hdg / 100.0;
      // Speed isn't a direct field — derived from the vx/vy velocity
      // components (cm/s), combined via Pythagoras for ground speed.
      final speed = (message.vx * message.vx + message.vy * message.vy) > 0
          ? (message.vx.abs() + message.vy.abs()) / 100.0
          : 0.0;
      print(
        '[ConnectionManager] GlobalPositionInt — alt: ${alt.toStringAsFixed(1)}m, heading: ${heading.toStringAsFixed(0)}°',
      );
      vehicleState.applyPosition(
        alt: alt,
        heading: heading,
        speed: speed,
        lat: lat,
        lon: lon,
      );
    }
  }

  void disconnect() {
    _parserSubscription?.cancel();
    _socket?.close();
    _socket = null;
    _parser = null;
    vehicleState.reset();
  }

  void _sendMessage(MavlinkMessage message) {
    if (_socket == null || _targetIp == null || _targetPort == null) return;
    final frame = MavlinkFrame.v2(
      _sequence,
      _mySystemId,
      _myComponentId,
      message,
    );
    _socket!.send(frame.serialize(), InternetAddress(_targetIp!), _targetPort!);
    _sequence = (_sequence + 1) % 255;
  }

  Future<void> armDisarm(bool arm) async {
    final command = CommandLong(
      command: mavCmdComponentArmDisarm,
      param1: arm ? 1 : 0,
      param2: 0,
      param3: 0,
      param4: 0,
      param5: 0,
      param6: 0,
      param7: 0,
      targetSystem: 1,
      targetComponent: 1,
      confirmation: 0,
    );
    _sendMessage(command);
  }

  Future<void> setMode(String mode) async {
    // TODO (Week 3): build a CommandLong with MAV_CMD_DO_SET_MODE
  }

  Future<void> sendManualControl({
    required double throttle,
    required double yaw,
    required double pitch,
    required double roll,
  }) async {
    // TODO (Week 3): build a ManualControl message, send it repeatedly
    // while the pilot is actively touching the virtual sticks.
  }

  Future<void> returnToLaunch() async {
    // TODO (Week 3): send MAV_CMD_NAV_RETURN_TO_LAUNCH
  }

  void dispose() {
    _parserSubscription?.cancel();
    _socket?.close();
  }
}
