import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/ardupilotmega.dart';
import '../state/connection_status.dart';
import '../state/vehicle_state.dart';
import '../models/health_state.dart';
import '../models/mission_waypoint.dart';

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

  // Caches for mission protocol fields extracted manually from raw bytes
  // to handle MAVLink v2 truncation (treating missing trailing fields as 0).
  // Consumed by _handleFrame for whichever datagram is currently being processed.
  ({int result, int missionType, int opaqueId})? _rawMissionAck;
  int? _rawMissionCountType;
  int? _rawMissionRequestIntType;
  int? _rawMissionItemIntType;

  // Where we'll eventually SEND commands once arm/mode/manual control are
  // implemented (Week 3). Stored now, unused until then — today this class
  // only listens, it doesn't transmit anything yet.
  String? _targetIp;
  int? _targetPort;

  int _vehicleSystemId = 1;
  int _vehicleComponentId = 1;

  // Mission Upload State
  List<MissionWaypoint>? _uploadingWaypoints;
  Completer<bool>? _missionUploadCompleter;

  // Mission Download State
  List<MissionWaypoint>? _downloadingWaypoints;
  int? _expectedDownloadCount;
  Completer<List<MissionWaypoint>?>? _missionDownloadCompleter;

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
    final dialect = MavlinkDialectArdupilotmega();
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
          // Manually locate mission messages in the raw bytes BEFORE handing
          // off to dart_mavlink's parser -- its generated classes have a
          // bug in this pinned version where they misread truncated fields
          // at the end of MAVLink v2 payloads.
          _scanForMissionProtocol(datagram.data);
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
    1: 'Acro',
    2: 'AltHold',
    3: 'AUTO',
    4: 'Guided',
    5: 'Loiter',
    6: 'RTL',
    7: 'Circle',
    9: 'Land',
    16: 'PosHold',
    17: 'Brake',
    21: 'SmartRTL',
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

  // Maps MAV_MISSION_RESULT codes to human-readable text
  String _describeMissionResult(int result) {
    if (result == mavMissionAccepted) return 'Mission accepted.';
    if (result == mavMissionNoSpace) return 'Error: Drone memory is full.';
    if (result == mavMissionInvalid) return 'Error: Mission item is invalid.';
    if (result == mavMissionInvalidParam1) return 'Error: Invalid param 1.';
    if (result == mavMissionInvalidParam2) return 'Error: Invalid param 2.';
    if (result == mavMissionInvalidParam3) return 'Error: Invalid param 3.';
    if (result == mavMissionInvalidParam4) return 'Error: Invalid param 4.';
    if (result == mavMissionInvalidParam5X) return 'Error: Invalid Latitude.';
    if (result == mavMissionInvalidParam6Y) return 'Error: Invalid Longitude.';
    if (result == mavMissionInvalidParam7) return 'Error: Invalid Altitude.';
    if (result == mavMissionInvalidSequence) return 'Error: Sequence mismatch.';
    if (result == mavMissionDenied) return 'Mission denied by drone.';
    if (result == mavMissionOperationCancelled) {
      return 'Upload Cancelled: Drone aborted the transaction.';
    }
    return 'Mission failed (Code $result).';
  }

  /// Manually decodes mission protocol messages straight from the raw UDP
  /// bytes, bypassing dart_mavlink's generated classes.
  ///
  /// Why: the pinned dart_mavlink version has a bug in its MAVLink v2
  /// implementation -- it doesn't correctly handle truncated payloads.
  /// The MAVLink v2 spec requires that trailing all-zero bytes be stripped
  /// from the wire, and receivers must treat missing trailing fields as 0.
  /// This library's parser instead reads past the end of the short payload
  /// into adjacent buffer memory, resulting in garbage values.
  ///
  /// We extract the mission fields here directly from the wire format:
  /// https://mavlink.io/en/guide/serialization.html
  void _scanForMissionProtocol(Uint8List data) {
    _rawMissionAck = null;
    _rawMissionCountType = null;
    _rawMissionRequestIntType = null;
    _rawMissionItemIntType = null;

    int i = 0;
    while (i < data.length) {
      if (data[i] != 0xFD) {
        i++;
        continue;
      }
      if (i + 10 > data.length) break;

      final payloadLen = data[i + 1];
      final msgId = data[i + 7] | (data[i + 8] << 8) | (data[i + 9] << 16);
      final payloadStart = i + 10;
      final payloadEnd = payloadStart + payloadLen;

      if (payloadEnd > data.length) {
        i++;
        continue;
      }

      // MISSION_ACK (msgid 47)
      if (msgId == 47 && payloadLen >= 2) {
        final targetSystem = data[payloadStart];
        if (targetSystem == _mySystemId) {
          final type = (payloadStart + 2 < payloadEnd)
              ? data[payloadStart + 2]
              : 0;
          final missionType = (payloadStart + 3 < payloadEnd)
              ? data[payloadStart + 3]
              : 0;
          int opaqueId = 0;
          if (payloadStart + 4 < payloadEnd) {
            int b0 = data[payloadStart + 4];
            int b1 = (payloadStart + 5 < payloadEnd)
                ? data[payloadStart + 5]
                : 0;
            int b2 = (payloadStart + 6 < payloadEnd)
                ? data[payloadStart + 6]
                : 0;
            int b3 = (payloadStart + 7 < payloadEnd)
                ? data[payloadStart + 7]
                : 0;
            opaqueId = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
          }
          _rawMissionAck = (
            result: type,
            missionType: missionType,
            opaqueId: opaqueId,
          );
        }
      }
      // MISSION_COUNT (msgid 44)
      else if (msgId == 44 && payloadLen >= 4) {
        final targetSystem = data[payloadStart + 2];
        if (targetSystem == _mySystemId) {
          _rawMissionCountType = (payloadStart + 4 < payloadEnd)
              ? data[payloadStart + 4]
              : 0;
        }
      }
      // MISSION_REQUEST_INT (msgid 51)
      else if (msgId == 51 && payloadLen >= 4) {
        final targetSystem = data[payloadStart + 2];
        if (targetSystem == _mySystemId) {
          _rawMissionRequestIntType = (payloadStart + 4 < payloadEnd)
              ? data[payloadStart + 4]
              : 0;
        }
      }
      // MISSION_ITEM_INT (msgid 73)
      else if (msgId == 73 && payloadLen >= 37) {
        final targetSystem = data[payloadStart + 32];
        if (targetSystem == _mySystemId) {
          _rawMissionItemIntType = (payloadStart + 37 < payloadEnd)
              ? data[payloadStart + 37]
              : 0;
        }
      }

      i++;
    }
  }

  void _handleFrame(MavlinkFrame frame) {
    // CRITICAL: Ignore all MAVLink messages sent by ourselves.
    // In UDP/SITL environments, packets are often echoed back. If the app
    // processes its own Mission messages, it will interfere with the
    // handshake state machines (completers).
    if (frame.systemId == _mySystemId) return;

    final message = frame.message;

    if (message is CommandAck) {
      if (message.command == mavCmdDoSetMode) {
        if (message.result == mavResultAccepted) {
          vehicleState.addAlert(
            VehicleAlert(
              id: 'mode_change_success',
              message: 'Flight mode updated.',
              severity: AlertSeverity.info,
            ),
          );
        } else {
          vehicleState.setError(
            'Mode switch failed: ${_describeCommandResult(message.result)}',
          );
        }
      } else if (message.result != mavResultAccepted) {
        vehicleState.setError(_describeCommandResult(message.result));
      }
    }

    if (message is Heartbeat) {
      if (vehicleState.connectionStatus != ConnectionStatus.connected) {
        vehicleState.setConnectionStatus(ConnectionStatus.connected);
        _connectTimeoutTimer?.cancel();
      }

      // Track the vehicle's IDs for addressing commands correctly
      _vehicleSystemId = frame.systemId;
      _vehicleComponentId = frame.componentId;

      // Bit 128 in base_mode is the "armed" flag (from Day 1's glossary).
      final armed = (message.baseMode & 128) != 0;

      final modeName =
          _ardupilotModeNames[message.customMode] ??
          message.customMode.toString();
      vehicleState.applyHeartbeat(armed: armed, mode: modeName);
    }

    // The mission protocol (MISSION_REQUEST / MISSION_REQUEST_INT /
    // MISSION_ACK) is shared across regular waypoints, geofence, and
    // rally points.
    if (message is MissionRequest) {
      _handleMissionRequest(message.seq);
    } else if (message is MissionRequestInt) {
      final missionType = _rawMissionRequestIntType ?? message.missionType;
      if (missionType == mavMissionTypeMission) {
        _handleMissionRequest(message.seq);
      }
    }

    if (message is MissionCount) {
      final missionType = _rawMissionCountType ?? message.missionType;
      if (missionType == mavMissionTypeMission) {
        _handleMissionCount(message);
      }
    }

    if (message is MissionItemInt) {
      final missionType = _rawMissionItemIntType ?? message.missionType;
      if (missionType == mavMissionTypeMission) {
        _handleMissionItem(message);
      }
    }

    if (message is MissionAck) {
      // See _scanForMissionProtocol's doc comment: this library's MissionAck
      // getters are unreliable for this field set, so we decode the real
      // result directly from the raw bytes of the datagram that produced
      // this frame, captured just before it was handed to the parser.
      final raw = _rawMissionAck;
      final int actualResult = raw?.result ?? message.type;

      final completer = _missionUploadCompleter;
      if (completer != null && !completer.isCompleted) {
        if (actualResult == mavMissionAccepted) {
          vehicleState.addAlert(
            VehicleAlert(
              id: 'mission_upload_success',
              message: 'Mission accepted by vehicle.',
              severity: AlertSeverity.info,
            ),
          );
          completer.complete(true);
        } else {
          final errorMsg = _describeMissionResult(actualResult);
          vehicleState.setError(errorMsg);
          completer.complete(false);
        }
      }
      _uploadingWaypoints = null;
    }

    if (message is MissionCurrent) {
      vehicleState.applyMissionCurrent(message.seq);
    }

    if (message is MissionItemReached) {
      // Could be used for more granular feedback
    }

    if (message is SysStatus) {
      // voltage_battery is millivolts, current_battery is centiamps —
      // both raw integer fields, scaled down to normal units here.
      final volts = message.voltageBattery / 1000.0;
      final percent = message.batteryRemaining.toDouble();

      vehicleState.applyBattery(percent: percent, voltage: volts);

      // Sensor health decoding
      _decodeSensorHealth(message);
    }

    if (message is GpsRawInt) {
      vehicleState.applyGpsStatus(
        fixType: message.fixType,
        satellites: message.satellitesVisible,
      );
    }

    if (message is EkfStatusReport) {
      _decodeEkfStatus(message);
    }

    if (message is Statustext) {
      // Find the first null character (0) to stop reading and avoid trailing garbage
      final charCodes = message.text.takeWhile((c) => c != 0).toList();
      final text = String.fromCharCodes(charCodes).trim();

      // Filter and translate common ArduPilot messages for better UX
      final translated = _translateStatusText(text);
      if (translated == null) return; // Hidden noise

      // Only add to Active Alerts if it's a Warning or Critical.
      if (message.severity <= mavSeverityWarning) {
        vehicleState.addAlert(
          VehicleAlert(
            id: 'status_${message.severity}_${text.hashCode}',
            message: translated,
            severity: _mapMavSeverity(message.severity),
          ),
        );
      }
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
      targetSystem: _vehicleSystemId,
      targetComponent: _vehicleComponentId,
      confirmation: 0,
    );
    _sendMessage(command);
  }

  static const Map<String, int> _ardupilotModeNumbers = {
    'Stabilize': 0,
    'Acro': 1,
    'AltHold': 2,
    'AUTO': 3,
    'Guided': 4,
    'Loiter': 5,
    'RTL': 6,
    'Circle': 7,
    'Land': 9,
    'PosHold': 16,
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
      targetSystem: _vehicleSystemId,
      targetComponent: _vehicleComponentId,
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
      target: _vehicleSystemId,
      x: (pitch.clamp(-1, 1) * 1000).round(),
      y: (roll.clamp(-1, 1) * 1000).round(),
      // ArduCopter specific: z is mapped to [0, 1000] for thrust
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

  Future<bool> uploadMission(
    List<MissionWaypoint> waypoints, {
    bool rtlAfter = true,
  }) async {
    if (waypoints.isEmpty) return false;

    // ArduPilot Mission Structure:
    // Seq 0: Home Position (Mandatory)
    // Seq 1: Takeoff (Required to lift off in AUTO mode)
    // Seq 2..N: Actual Waypoints
    // Seq N+1: RTL (Optional)

    final List<MissionWaypoint> items = [];

    // 0. Home
    items.add(
      MissionWaypoint(
        lat: vehicleState.latitude ?? 0,
        lon: vehicleState.longitude ?? 0,
        alt: 0,
        seq: 0,
      ),
    );

    // 1. Takeoff (Using first waypoint's location but marked as Takeoff)
    items.add(
      MissionWaypoint(
        lat: waypoints.first.lat,
        lon: waypoints.first.lon,
        alt: waypoints.first.alt,
        seq: 1,
      ),
    );

    // 2..N. Waypoints
    for (int i = 0; i < waypoints.length; i++) {
      items.add(waypoints[i].copyWith(seq: i + 2));
    }

    // N+1. RTL
    if (rtlAfter) {
      items.add(MissionWaypoint(lat: 0, lon: 0, alt: 0, seq: items.length));
    }

    // Prepare state BEFORE sending MAVLink commands
    _missionUploadCompleter = Completer<bool>();
    _uploadingWaypoints = items;

    vehicleState.setMissionUploadStatus(MissionUploadStatus.uploading);
    vehicleState.addAlert(
      VehicleAlert(
        id: 'mission_upload_start',
        message: 'Uploading mission (${waypoints.length} waypoints)...',
        severity: AlertSeverity.info,
      ),
    );

    // ArduPilot can be picky about addressing. Use System ID from last heartbeat
    final targetSys = _vehicleSystemId;
    final targetComp = _vehicleComponentId;

    _sendMessage(
      MissionCount(
        targetSystem: targetSys,
        targetComponent: targetComp,
        count: items.length,
        missionType: mavMissionTypeMission,
        opaqueId: 0,
      ),
    );

    // Wait for the ACK or failure
    final result = await _missionUploadCompleter!.future.timeout(
      const Duration(seconds: 30), // Extended for slow SITL/UDP
      onTimeout: () {
        final completer = _missionUploadCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete(false);
        }
        _uploadingWaypoints = null;
        return false;
      },
    );

    vehicleState.setMissionUploadStatus(
      result ? MissionUploadStatus.uploaded : MissionUploadStatus.failed,
    );
    return result;
  }

  void _handleMissionRequest(int seq) {
    final List<MissionWaypoint>? waypoints = _uploadingWaypoints;
    if (waypoints == null) return;

    if (seq >= 0 && seq < waypoints.length) {
      final wp = waypoints[seq];

      int command = mavCmdNavWaypoint;
      double p1 = 0;
      int frame = mavFrameGlobalRelativeAlt;

      if (seq == 0) {
        command = mavCmdNavWaypoint;
        frame = mavFrameGlobal;
      } else if (seq == 1) {
        command = mavCmdNavTakeoff;
        p1 = 0;
      } else if (wp.lat == 0 && wp.lon == 0 && seq == waypoints.length - 1) {
        command = mavCmdNavReturnToLaunch;
      }

      _sendMessage(
        MissionItemInt(
          targetSystem: _vehicleSystemId,
          targetComponent: _vehicleComponentId,
          seq: seq,
          frame: frame,
          command: command,
          current: 0,
          autocontinue: 1,
          param1: p1,
          param2: 0,
          param3: 0,
          param4: 0,
          x: (wp.lat * 1e7).toInt(),
          y: (wp.lon * 1e7).toInt(),
          z: wp.alt.toDouble(),
          missionType: mavMissionTypeMission,
        ),
      );
    }
  }

  Future<void> startAuto() async {
    // If the drone is not armed, we must arm it first.
    if (!vehicleState.armed) {
      vehicleState.addAlert(
        VehicleAlert(
          id: 'auto_arming',
          message: 'Arming drone for autonomous mission...',
          severity: AlertSeverity.info,
        ),
      );

      await armDisarm(true);

      // Wait for the drone to confirm it's armed.
      final deadline = DateTime.now().add(const Duration(seconds: 4));
      while (!vehicleState.armed && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (!vehicleState.armed) {
        vehicleState.setError('Arming failed. Mission start aborted.');
        return;
      }
    }

    // Now switch to AUTO mode.
    await setMode('AUTO');
  }

  /// Uploads the mission, and -- if (and only if) ArduPilot accepts it --
  /// immediately arms and switches to AUTO so the vehicle starts flying
  /// the route without a separate manual "Start Mission" tap.
  ///
  /// Returns true only if BOTH the upload was accepted AND the vehicle
  /// was successfully armed/started. If the upload fails, startAuto() is
  /// never called. If the upload succeeds but arming fails (e.g. failed
  /// pre-arm checks), the error is surfaced via VehicleAlert/setError
  /// same as before, and the mission stays uploaded-but-not-started so
  /// the user can retry starting it manually.
  Future<bool> uploadAndStartMission(
    List<MissionWaypoint> waypoints, {
    bool rtlAfter = true,
  }) async {
    final uploaded = await uploadMission(waypoints, rtlAfter: rtlAfter);
    if (!uploaded) return false;

    await startAuto();
    return true;
  }

  Future<List<MissionWaypoint>?> downloadMission() async {
    _downloadingWaypoints = [];
    _expectedDownloadCount = null;
    _missionDownloadCompleter = Completer<List<MissionWaypoint>?>();

    _sendMessage(
      MissionRequestList(
        targetSystem: _vehicleSystemId,
        targetComponent: _vehicleComponentId,
        missionType: mavMissionTypeMission,
      ),
    );

    final result = await _missionDownloadCompleter!.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        _missionDownloadCompleter = null;
        return null;
      },
    );

    if (result != null) {
      // Filter out Home (Seq 0) and Takeoff (Seq 1) for planning UI.
      // Modern GCS apps usually don't show internal flight controller
      // items in the waypoint list to avoid confusing the pilot.
      final userWps = result
          .where((wp) => wp.seq >= 2) // User waypoints start at index 2
          .map((wp) => wp.copyWith(seq: wp.seq - 2)) // Re-normalize seq
          .toList();
      vehicleState.setMissionWaypoints(userWps);
    }

    return result;
  }

  void _handleMissionCount(MissionCount msg) {
    if (_missionDownloadCompleter == null) return;
    _expectedDownloadCount = msg.count;
    _downloadingWaypoints = [];

    if (_expectedDownloadCount == 0) {
      _missionDownloadCompleter?.complete([]);
      return;
    }

    // Request first item
    _requestMissionItem(0);
  }

  void _requestMissionItem(int seq) {
    _sendMessage(
      MissionRequestInt(
        targetSystem: _vehicleSystemId,
        targetComponent: _vehicleComponentId,
        seq: seq,
        missionType: mavMissionTypeMission,
      ),
    );
  }

  void _handleMissionItem(MissionItemInt msg) {
    if (_missionDownloadCompleter == null || _expectedDownloadCount == null) {
      return;
    }

    final wp = MissionWaypoint(
      lat: msg.x / 1e7,
      lon: msg.y / 1e7,
      alt: msg.z,
      seq: msg.seq,
    );
    _downloadingWaypoints?.add(wp);

    if (_downloadingWaypoints!.length >= _expectedDownloadCount!) {
      _sendMessage(
        MissionAck(
          targetSystem: _vehicleSystemId,
          targetComponent: _vehicleComponentId,
          type: mavMissionAccepted,
          missionType: mavMissionTypeMission,
          opaqueId: 0,
        ),
      );
      _missionDownloadCompleter?.complete(_downloadingWaypoints);
      _missionDownloadCompleter = null;
    } else {
      _requestMissionItem(_downloadingWaypoints!.length);
    }
  }

  void _decodeSensorHealth(SysStatus msg) {
    final present = msg.onboardControlSensorsPresent;
    final enabled = msg.onboardControlSensorsEnabled;
    final health = msg.onboardControlSensorsHealth;

    _updateSensor(
      'Gyroscope',
      present,
      enabled,
      health,
      mavSysStatusSensor3dGyro,
    );
    _updateSensor(
      'Accelerometer',
      present,
      enabled,
      health,
      mavSysStatusSensor3dAccel,
    );
    _updateSensor('Compass', present, enabled, health, mavSysStatusSensor3dMag);
    _updateSensor(
      'Barometer',
      present,
      enabled,
      health,
      mavSysStatusSensorAbsolutePressure,
    );
  }

  void _updateSensor(
    String name,
    int present,
    int enabled,
    int health,
    int bit,
  ) {
    HealthStatus status;
    if ((present & bit) == 0) {
      status = HealthStatus.notPresent;
    } else if ((enabled & bit) == 0) {
      status = HealthStatus.notEnabled;
    } else if ((health & bit) == 0) {
      status = HealthStatus.unhealthy;
    } else {
      status = HealthStatus.healthy;
    }
    vehicleState.updateSensorHealth(name, status);
  }

  void _decodeEkfStatus(EkfStatusReport msg) {
    final flags = msg.flags;
    final healthy =
        (flags & ekfPosHorizRel) != 0 &&
        (flags & ekfPosHorizAbs) != 0 &&
        (flags & ekfPosVertAbs) != 0;

    vehicleState.updateSensorHealth(
      'EKF',
      healthy ? HealthStatus.healthy : HealthStatus.unhealthy,
      details: 'Flags: $flags',
    );
  }

  AlertSeverity _mapMavSeverity(int severity) {
    if (severity <= mavSeverityCritical) return AlertSeverity.critical;
    if (severity <= mavSeverityWarning) return AlertSeverity.warning;
    return AlertSeverity.info;
  }

  /// Translates raw ArduPilot status strings into pilot-friendly statements
  /// or returns null if the message should be filtered out (noise).
  String? _translateStatusText(String raw) {
    final lower = raw.toLowerCase();

    // Noise filtering
    if (lower.startsWith('terrain:') ||
        lower.contains('failsafe cleared') ||
        lower.contains('ekf2 waiting') ||
        lower.contains('ekf3 waiting')) {
      return null;
    }

    // Pre-arm check translations
    if (lower.contains('throttle too high')) {
      return 'Arming Denied: Move throttle stick to the bottom.';
    }
    if (lower.contains('not armed') && lower.contains('auto')) {
      return 'Action Required: Arm the drone before starting AUTO.';
    }
    if (lower.contains('need 3d fix')) {
      return 'Arming Denied: Waiting for GPS 3D fix.';
    }
    if (lower.contains('high gps hdop')) {
      return 'Arming Denied: GPS signal is too weak (High HDOP).';
    }
    if (lower.contains('compass not healthy')) {
      return 'Arming Denied: Compass error. Check for metal nearby.';
    }
    if (lower.contains('ekf primary changed')) {
      return 'Navigation System Updated (EKF Change).';
    }
    if (lower.contains('hardware safety switch')) {
      return 'Arming Denied: Press the physical safety switch on drone.';
    }
    if (lower.contains('check brd_type')) {
      return 'Critical: Autopilot hardware identification failed.';
    }

    // Default: Strip technical prefixes but keep the message
    return raw.replaceAll('PreArm: ', '').replaceAll('Arm: ', '');
  }

  void dispose() {
    _parserSubscription?.cancel();
    _socket?.close();
    _heartbeatTimer?.cancel();
    _connectTimeoutTimer?.cancel();
  }
}
