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
  Timer? _heartbeatTimeoutTimer, _heartbeatTimer;
  static const int _mySystemId = 250;
  static const int _myComponentId = mavCompIdMissionplanner;
  int _sequence = 0;
  InternetAddress? _lastSenderAddress;
  int? _lastSenderPort;

  Timer? _connectTimeoutTimer;
  static const _connectTimeout = Duration(seconds: 10);

  // Where we'll eventually SEND commands once arm/mode/manual control are
  // implemented (Week 3). Stored now, unused until then — today this class
  // only listens, it doesn't transmit anything yet.
  String? _targetIp;
  int? _targetPort;

  static const _heartbeatTimeout = Duration(seconds: 4);
  // Fires only if we never received a single Heartbeat within
  // _connectTimeout of calling connect(). If we're already connected by
  // then, this is a no-op — the timer firing late doesn't matter since
  // _handleFrame already cancelled it.
  void _handleConnectTimeout() {
    if (vehicleState.connectionStatus != ConnectionStatus.connecting) return;
    _heartbeatTimer?.cancel();
    _parserSubscription?.cancel();
    _socket?.close();
    _socket = null;
    _parser = null;
    _heartbeatTimeoutTimer?.cancel();
    vehicleState.setConnectionStatus(ConnectionStatus.timedOut);
  }

  Future<void> connect({required String ip, required int port}) async {
    vehicleState.connectionLost = false;
    _targetIp = ip;
    _targetPort = port;

    vehicleState.setConnectionStatus(ConnectionStatus.connecting);
    // Start the "did we ever hear back at all" timer. This is cancelled
    // the moment the first Heartbeat arrives (see _handleFrame below). If
    // it fires first, we never got a single valid packet back — that's a
    // genuine timeout, distinct from _heartbeatTimeoutTimer below, which
    // only handles losing a connection that was already established.
    _connectTimeoutTimer = Timer(_connectTimeout, _handleConnectTimeout);

    // The "dialect" is the vocabulary of message types we know how to
    // decode — the base common.xml set from Monday's reading.
    final dialect = MavlinkDialectCommon();
    _parser = MavlinkParser(dialect);

    // Every time the parser finishes decoding one full, valid message, it
    // announces it here. We only act on Heartbeat for now.
    _parserSubscription = _parser!.stream.listen(_handleFrame);

    // Claim this port on this machine, before any data has arrived yet —
    // same "install the mailbox first" step as bin/heartbeat_test.dart.
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    _heartbeatTimeoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final last = vehicleState.lastHeartbeat;
      if (vehicleState.connectionStatus == ConnectionStatus.connected &&
          last != null &&
          DateTime.now().difference(last) > _heartbeatTimeout) {
        _handleConnectionLost();
      }
    });

    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram != null) {
          _lastSenderAddress = datagram.address;
          _lastSenderPort = datagram.port;
          _parser!.parse(datagram.data);
        }
      }
    });
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sendMessage(
        Heartbeat(
          type: mavTypeGcs,
          autopilot: mavAutopilotInvalid,
          baseMode: 0,
          customMode: 0,
          systemStatus: mavStateActive,
          mavlinkVersion: 3,
        ),
      );
    });
  }

  static const Map<int, String> _ardupilotModeNames = {
    0: 'Stabilize',
    5: 'Hover',
    6: 'RTL',
  };

  // Maps MAV_RESULT codes (from dart_mavlink's common.dart dialect) to
  // human-readable text, instead of always showing the generic
  // "Command failed (code N)" regardless of what actually went wrong.
  String _describeCommandResult(int result) {
    if (result == mavResultTemporarilyRejected) {
      return 'Command temporarily rejected — try again in a moment.';
    }
    if (result == mavResultDenied) {
      return 'Command denied by the flight controller.';
    }
    if (result == mavResultUnsupported) {
      return "This command isn't supported by the connected vehicle.";
    }
    if (result == mavResultFailed) {
      return 'Command failed to execute.';
    }
    if (result == mavResultInProgress) {
      return 'Command is still in progress.';
    }
    if (result == mavResultCancelled) {
      return 'Command was cancelled.';
    }
    return 'Command failed (code $result).';
  }

  void _handleFrame(MavlinkFrame frame) {
    final message = frame.message;
    // print('[DEBUG] Received message type: ${message.runtimeType}');
    if (message is CommandAck) {
      // print(
      //   '[ConnectionManager] CommandAck — command: ${message.command}, result: ${message.result}',
      // );
      if (message.result != mavResultAccepted) {
        vehicleState.setError(_describeCommandResult(message.result));
      }
    }

    if (message is Heartbeat) {
      if (vehicleState.connectionStatus != ConnectionStatus.connected) {
        vehicleState.setConnectionStatus(ConnectionStatus.connected);
        _connectTimeoutTimer?.cancel();
      }
      // Bit 12mo8 in base_mode is the "armed" flag (from Day 1's glossary).
      final armed = (message.baseMode & 128) != 0;
      // customMode is just a raw number here — turning it into a readable
      // name like "Stabilize"/"Loiter" needs ArduPilot's mode-number
      // lookup table, which is still
      // is enough to prove real data is flowing correctly.
      final modeName =
          _ardupilotModeNames[message.customMode] ??
          message.customMode.toString();
      // print(
      //   '[ConnectionManager] Heartbeat received — armed: $armed, mode: ${message.customMode}',
      // );
      vehicleState.applyHeartbeat(armed: armed, mode: modeName);
    }

    if (message is SysStatus) {
      // voltage_battery is millivolts, current_battery is centiamps —
      // both raw integer fields, scaled down to normal units here.
      final volts = message.voltageBattery / 1000.0;
      final percent = message.batteryRemaining.toDouble();

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
      // vz is NED "velocity down", cm/s, positive = descending. Negate
      // so positive = climbing, negative = descending (intuitive).
      final verticalSpeed = -message.vz / 100.0;

      vehicleState.applyPosition(
        alt: alt,
        heading: heading,
        speed: speed,
        verticalSpeed: verticalSpeed,
        lat: lat,
        lon: lon,
      );
    }
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _parserSubscription?.cancel();
    _socket?.close();
    _socket = null;
    _parser = null;
    _heartbeatTimeoutTimer?.cancel();
    vehicleState.reset();
    _connectTimeoutTimer?.cancel();
  }

  void _sendMessage(MavlinkMessage message) {
    if (_socket == null ||
        _lastSenderAddress == null ||
        _lastSenderPort == null) {
      return;
    }
    final frame = MavlinkFrame.v2(
      _sequence,
      _mySystemId,
      _myComponentId,
      message,
    );
    _socket!.send(frame.serialize(), _lastSenderAddress!, _lastSenderPort!);
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

  static const Map<String, int> _ardupilotModeNumbers = {
    'Stabilize': 0,
    'Hover': 5,
    'RTL': 6,
  };

  Future<void> setMode(String mode) async {
    final modeNumber = _ardupilotModeNumbers[mode];
    if (modeNumber == null) return;
    final command = CommandLong(
      command: mavCmdDoSetMode,
      param1: mavModeFlagCustomModeEnabled.toDouble(),
      param2: modeNumber.toDouble(),
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

  Future<void> sendManualControl({
    required double throttle,
    required double yaw,
    required double pitch,
    required double roll,
  }) async {
    final message = ManualControl(
      target: 1,
      x: (pitch.clamp(-1, 1) * 1000).round(),
      y: (roll.clamp(-1, 1) * 1000).round(),
      // Maps our [-1, 1] throttle input back to the [0, 1000] range that
      // flight controllers expect for their throttle channel.
      // -1.0 (Bottom) -> 0 (Zero Throttle)
      //  0.0 (Center) -> 500 (Neutral/Hover)
      //  1.0 (Top)    -> 1000 (Full Throttle)
      z: (((throttle.clamp(-1, 1) + 1) / 2) * 1000).round(),
      r: (yaw.clamp(-1, 1) * 1000).round(),
      buttons: 0,
      buttons2: 0,
      enabledExtensions: 0,
      s: 0,
      t: 0,
      aux1: 0,
      aux2: 0,
      aux3: 0,
      aux4: 0,
      aux5: 0,
      aux6: 0,
    );
    _sendMessage(message);
  }

  void _handleConnectionLost() {
    _parserSubscription?.cancel();
    _socket?.close();
    _socket = null;
    _parser = null;
    _heartbeatTimeoutTimer?.cancel();
    vehicleState.markConnectionLost();
  }

  Future<void> returnToLaunch() async {
    await setMode('RTL');
  }

  void dispose() {
    _parserSubscription?.cancel();
    _socket?.close();
    _heartbeatTimer?.cancel();
    _connectTimeoutTimer?.cancel();
  }
}
