import 'dart:async';
import 'dart:io';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';
import '../state/connection_status.dart';
import '../state/vehicle_state.dart';

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

    // TODO (next): handle SysStatus (battery) and GlobalPositionInt
    // (GPS/altitude/speed) here too, calling vehicleState.applyBattery/
    // applyPosition — same "if (message is X)" pattern as Heartbeat above.
  }

  void disconnect() {
    _parserSubscription?.cancel();
    _socket?.close();
    _socket = null;
    _parser = null;
    vehicleState.reset();
  }

  Future<void> armDisarm(bool arm) async {
    // TODO (Week 3): build a CommandLong with MAV_CMD_COMPONENT_ARM_DISARM
    // and send its packed bytes to _targetIp:_targetPort via _socket!.send(...)
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
