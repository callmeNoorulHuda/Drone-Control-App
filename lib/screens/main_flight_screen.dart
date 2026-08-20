import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../connection/connection_manager.dart';
import '../state/connection_status.dart';
import '../state/joystick_controller.dart';
import '../state/vehicle_state.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/camera_feed_panel.dart';
import '../widgets/drone_map_view.dart';
import '../widgets/flight_status_panel.dart';
import '../widgets/telemetry_panel.dart';
import '../widgets/top_bar.dart';
import '../widgets/virtual_joystick.dart';

class MainFlightScreen extends StatefulWidget {
  const MainFlightScreen({super.key});

  @override
  State<MainFlightScreen> createState() => _MainFlightScreenState();
}

class _MainFlightScreenState extends State<MainFlightScreen>
    with WidgetsBindingObserver {
  bool _forceIdleThrottleForArming = false;
  final JoystickController _leftController = JoystickController();
  final JoystickController _rightController = JoystickController();
  late final VehicleState _vehicleState = VehicleState();
  late final ConnectionManager _connectionManager = ConnectionManager(
    _vehicleState,
  );
  String? _lastShownError;

  // Manual = joysticks + arm/disarm + flight-mode chips are shown.
  // Auto = those disappear; only map, telemetry, and camera feed remain.
  bool _manualMode = true;
  Offset _leftStick = Offset.zero;
  Offset _rightStick = Offset.zero;
  Timer? _controlTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applySystemUISettings();
    _vehicleState.addListener(_onVehicleStateChanged);
    _controlTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
      if (_vehicleState.connectionStatus == ConnectionStatus.connected) {
        final throttle = _forceIdleThrottleForArming
            ? 0.0
            : ((1 - _leftStick.dy) / 2).clamp(0.0, 1.0);
        _connectionManager.sendManualControl(
          throttle: throttle,
          yaw: _leftStick.dx,
          pitch: -_rightStick.dy,
          roll: _rightStick.dx,
        );
      }
    });
  }

  Future<void> _applySystemUISettings() async {
    // this makes the joystick stick in landscape layout
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // UI can temporarily appear if the user swipes from an edge, but Flutter will hide it again.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android kicks the app back out of immersive mode whenever it's
    // backgrounded and resumed (e.g. the pilot switches apps mid-flight
    // to check something, then comes back). Re-apply it every time we
    // come back to the foreground, or the bars silently reappear.
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> _onArmPressed() async {
    setState(() => _forceIdleThrottleForArming = true);
    _leftController.moveTo(const Offset(0, 1));
    await _connectionManager.armDisarm(true);

    // Wait for the heartbeat to confirm armed, with a safety timeout
    // so a failed/rejected arm doesn't leave throttle stuck at 0 forever.
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (!_vehicleState.armed && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) setState(() => _forceIdleThrottleForArming = false);
  }

  String? _lastMode;

  void _onVehicleStateChanged() {
    final error = _vehicleState.lastError;
    if (error != null && error != _lastShownError) {
      _lastShownError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
      _vehicleState.clearError();
    }
    if (_vehicleState.currentMode != _lastMode) {
      final previousMode = _lastMode;
      _lastMode = _vehicleState.currentMode;
      if (previousMode != null && _lastMode != 'Stabilize') {
        _leftController.center();
        _rightController.center();
      }
    }
  }

  @override
  void dispose() {
    _vehicleState.removeListener(_onVehicleStateChanged);
    _controlTimer?.cancel();
    _connectionManager.dispose();
    _applySystemUISettings();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onLeftStick(Offset v) => setState(() => _leftStick = v);
  void _onRightStick(Offset v) => setState(() => _rightStick = v);

  void _onTapConnection(bool connected) {
    if (connected) {
      _connectionManager.disconnect();
    } else {
      _connectionManager.connect(ip: '192.168.4.1', port: 14550);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListenableBuilder(
        listenable: _vehicleState,
        builder: (context, _) {
          final connected =
              _vehicleState.connectionStatus == ConnectionStatus.connected;
          final hasFix =
              _vehicleState.latitude != null && _vehicleState.longitude != null;

          // One breakpoint drives every size in this screen — phone gets
          // tighter panels/joysticks/fonts, tablet gets the fuller sizing.
          // Layout shape (map left, side panel right) stays the same on
          // both; only the numbers scale, per Noor's request.
          final tablet = isTabletLayout(context);
          final gap = tablet ? 12.0 : 0.0;
          final sidePanelWidth = tablet ? 260.0 : 128.0;
          final joystickSize = tablet ? 150.0 : 104.0;
          final edgeInset = tablet ? 20.0 : 10.0;

          return SafeArea(
            left: false,
            child: Column(
              children: [
                TopBar(
                  vehicleState: _vehicleState,
                  onTapConnection: () => _onTapConnection(connected),
                  manualMode: _manualMode,
                  onModeChanged: (v) => setState(() => _manualMode = v),
                  compact: !tablet,
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LEFT: map, with manual-only overlay controls.
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(gap),
                          child: Stack(
                            children: [
                              DroneMapView(
                                latitude: _vehicleState.latitude ?? 33.6844,
                                longitude: _vehicleState.longitude ?? 73.0479,
                                headingDegrees:
                                    _vehicleState.headingDegrees ?? 0,
                                connected: connected,
                                hasFix: hasFix,
                              ),
                              if (_manualMode) ...[
                                Positioned(
                                  left: edgeInset,
                                  bottom: edgeInset,
                                  child: Opacity(
                                    opacity: connected ? 1 : 0.35,
                                    child: IgnorePointer(
                                      ignoring: !connected,
                                      child: VirtualJoystick(
                                        label: 'THROTTLE / YAW',
                                        size: joystickSize,
                                        springBack: false,
                                        onChanged: _onLeftStick,
                                        vehicleState: _vehicleState,
                                        controller: _leftController,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: edgeInset,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: FlightStatusPanel(
                                      vehicleState: _vehicleState,
                                      connectionManager: _connectionManager,
                                      enabled: connected,
                                      compact: !tablet,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: edgeInset,
                                  bottom: edgeInset,
                                  child: Opacity(
                                    opacity: connected ? 1 : 0.35,
                                    child: IgnorePointer(
                                      ignoring: !connected,
                                      child: VirtualJoystick(
                                        label: 'PITCH / ROLL',
                                        size: joystickSize,
                                        onChanged: _onRightStick,
                                        vehicleState: _vehicleState,
                                        controller: _rightController,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // RIGHT: fixed-width side panel — camera feed on top,
                      // telemetry below. Always visible in both modes.
                      SizedBox(
                        width: sidePanelWidth,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(0, gap, gap, gap),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CameraFeedPanel(
                                connected: connected,
                                compact: !tablet,
                              ),
                              SizedBox(height: gap),
                              Expanded(
                                child: TelemetryPanel(
                                  vehicleState: _vehicleState,
                                  compact: !tablet,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
