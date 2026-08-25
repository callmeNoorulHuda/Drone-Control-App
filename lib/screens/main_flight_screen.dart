import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../connection/connection_manager.dart';
import '../state/connection_status.dart';
import '../state/joystick_controller.dart';
import '../state/settings_controller.dart';
import '../state/vehicle_state.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/camera_feed_panel.dart';
import '../widgets/drone_map_view.dart';
import '../widgets/flight_status_panel.dart';
import '../widgets/telemetry_panel.dart';
import '../widgets/top_bar.dart';
import '../widgets/virtual_joystick.dart';
import '../widgets/arrow_joystick.dart';
import '../state/joystick_style.dart';

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

  // No longer created here — sourced from Provider (see main.dart), since
  // they now live for the whole app's lifetime, not just this screen's.
  late final VehicleState _vehicleState;
  late final ConnectionManager _connectionManager;

  String? _lastShownError;
  bool _timedOutDialogShown = false;

  // Manual = joysticks + arm/disarm + flight-mode chips are shown.
  // Auto = those disappear; only map, telemetry, and camera feed remain.
  bool _manualMode = true;
  Offset _leftStick = Offset.zero;
  Offset _rightStick = Offset.zero;
  Timer? _controlTimer;

  // --- Battery warning/critical dialog state -------------------------
  // Warning: pop a confirm-or-cancel RTL dialog. Re-prompts every extra
  // _batteryRepromptStep percent the battery drops past the last time we
  // showed it (so cancelling once doesn't silence it for the whole flight,
  // but it also doesn't nag on every single percent tick).
  // Critical: no dialog — RTL is triggered automatically, no confirmation.
  static const double _batteryWarningThreshold = 20.0;
  static const double _batteryCriticalThreshold = 10.0;
  static const double _batteryRepromptStep = 2.0;
  double? _lastBatteryPromptPercent;
  bool _batteryDialogShowing = false;

  @override
  void initState() {
    super.initState();
    // context.read is safe here: we're not registering a rebuild
    // dependency, just fetching the instances once when this screen is
    // first created.
    _vehicleState = context.read<VehicleState>();
    _connectionManager = context.read<ConnectionManager>();

    WidgetsBinding.instance.addObserver(this);
    _applySystemUISettings();

    // KEPT as addListener on purpose — this drives one-shot side effects
    // (showing a snackbar, centering joysticks, battery warnings), not UI
    // rebuilding. See the note in build() for the part that WAS converted
    // to watch().
    _vehicleState.addListener(_onVehicleStateChanged);

    _controlTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
      if (_manualMode &&
          _vehicleState.connectionStatus == ConnectionStatus.connected) {
        final throttle = _forceIdleThrottleForArming
            ? -1.0
            : (-_leftStick.dy).clamp(-1.0, 1.0);
        _connectionManager.sendManualControl(
          throttle: throttle,
          yaw: _leftStick.dx,
          pitch: -_rightStick.dy,
          roll: _rightStick.dx,
        );
      }
    });
  }

  void _onManualModeChanged(bool manual) {
    setState(() {
      _manualMode = manual;
      if (!manual) {
        _leftStick = Offset.zero;
        _rightStick = Offset.zero;
        _leftController.center();
        _rightController.center();
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

  // Renamed from the old (never-called) _onArmPressed, and now handles
  // BOTH directions — arm and disarm — since it's the single entry point
  // FlightStatusPanel calls via its onArmToggle callback. Only the arm
  // path forces idle throttle first; disarm doesn't need that.
  Future<void> _onArmToggle(bool arm) async {
    if (arm) {
      setState(() => _forceIdleThrottleForArming = true);
      // Visually snaps the throttle stick to minimum.
      _leftController.moveTo(const Offset(0, 1));

      // Force a manual control packet with -1.0 throttle (idle) IMMEDIATELY.
      // ArduPilot rejects arm commands if the last received throttle wasn't 0.
      await _connectionManager.sendManualControl(
        throttle: -1.0,
        yaw: _leftStick.dx,
        pitch: -_rightStick.dy,
        roll: _rightStick.dx,
      );
    }

    await _connectionManager.armDisarm(arm);

    if (arm) {
      // Wait for the heartbeat to confirm armed, with a safety timeout
      // so a failed/rejected arm doesn't leave throttle stuck at 0 forever.
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (!_vehicleState.armed && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (mounted) {
        setState(() => _forceIdleThrottleForArming = false);
        // Automatically return throttle to center once armed, as requested.
        // NOTE: In Stabilize mode, this will spin motors to 50% (hover).
        _leftController.center();
      }
    }
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

    if (_vehicleState.connectionStatus == ConnectionStatus.timedOut) {
      if (!_timedOutDialogShown) {
        _timedOutDialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showConnectionTimeoutDialog();
        });
      }
    } else {
      _timedOutDialogShown = false;
    }

    _checkBatteryStatus();
  }

  Future<void> _showConnectionTimeoutDialog() async {
    final shouldRetry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text('Connection Timed Out'),
        content: const Text(
          'No response was received from the vehicle. Check that it\'s '
          'powered on and in range, then try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Dismiss'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    if (shouldRetry == true && mounted) {
      _connectionManager.connect(ip: '192.168.4.1', port: 14550);
    }
  }

  void _checkBatteryStatus() {
    final battery = _vehicleState.batteryPercent;
    if (battery == null) return;
    if (_vehicleState.connectionStatus != ConnectionStatus.connected) return;

    if (battery <= _batteryCriticalThreshold) {
      // Critical: no confirmation, just go — matches the "if less than a
      // certain level, make it automatically RTL and the person isn't
      // able to do anything" requirement.
      if (_vehicleState.currentMode != 'RTL') {
        _connectionManager.returnToLaunch();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Critical battery — returning to launch automatically.',
              ),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
      }
      return;
    }

    if (battery <= _batteryWarningThreshold) {
      final droppedEnoughToReprompt =
          _lastBatteryPromptPercent == null ||
          (_lastBatteryPromptPercent! - battery) >= _batteryRepromptStep;
      if (!_batteryDialogShowing && droppedEnoughToReprompt) {
        _lastBatteryPromptPercent = battery;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showBatteryDialog(battery);
        });
      }
    } else {
      // Battery recovered above the warning line (e.g. reconnect with a
      // fresh pack) — reset so a future dip re-prompts from scratch.
      _lastBatteryPromptPercent = null;
    }
  }

  Future<void> _showBatteryDialog(double percent) async {
    _batteryDialogShowing = true;
    final shouldReturn = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text('Battery Low'),
        content: Text(
          'Battery at ${percent.toStringAsFixed(0)}%. Return to launch now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RTL'),
          ),
        ],
      ),
    );
    _batteryDialogShowing = false;
    if (shouldReturn == true) {
      await _connectionManager.returnToLaunch();
    }
  }

  @override
  void dispose() {
    _vehicleState.removeListener(_onVehicleStateChanged);
    _controlTimer?.cancel();
    // _connectionManager.dispose() is NOT called here anymore — main.dart
    // owns that object now, so main.dart is responsible for disposing it.
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
    // CONVERTED from ListenableBuilder(listenable: _vehicleState, ...) to
    // context.watch — this subscribes the whole build() to VehicleState
    // and reruns it automatically on notifyListeners(), same effect as
    // the old ListenableBuilder wrapper, one less nested widget.
    final vehicleState = context.watch<VehicleState>();
    final settings = context.watch<SettingsController>();

    final connected =
        vehicleState.connectionStatus == ConnectionStatus.connected;
    final hasFix =
        vehicleState.latitude != null && vehicleState.longitude != null;

    // One breakpoint drives every size in this screen — phone gets
    // tighter panels/joysticks/fonts, tablet gets the fuller sizing.
    // Layout shape (map left, side panel right) stays the same on
    // both; only the numbers scale, per Noor's request.
    final tablet = isTabletLayout(context);
    final gap = tablet ? 12.0 : 4.0;
    final sidePanelWidth = tablet ? 260.0 : 135.0;
    final joystickSize = tablet ? 200.0 : 136.0;
    final edgeInset = tablet ? 20.0 : 12.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        left: false,
        child: Column(
          children: [
            TopBar(
              onTapConnection: () => _onTapConnection(connected),
              manualMode: _manualMode,
              onModeChanged: _onManualModeChanged,
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
                            latitude: vehicleState.latitude ?? 33.6844,
                            longitude: vehicleState.longitude ?? 73.0479,
                            headingDegrees: vehicleState.headingDegrees ?? 0,
                            connected: connected,
                            hasFix: hasFix,
                            isDarkMode: settings.isDarkMode,
                            markerStyle: settings.markerStyle,
                            useSatelliteMap: settings.useSatelliteMap,
                          ),
                          if (_manualMode) ...[
                            Positioned(
                              left: edgeInset,
                              bottom: edgeInset,
                              child: Opacity(
                                opacity: connected ? 1 : 0.35,
                                child: IgnorePointer(
                                  ignoring: !connected,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface.withValues(
                                            alpha: 0.8,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppColors.hairline,
                                          ),
                                        ),
                                        child: Text(
                                          '${(-_leftStick.dy * 100).round()}%',
                                          style: const TextStyle(
                                            color: AppColors.amber,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      settings.joystickStyle ==
                                              JoystickStyle.arrows
                                          ? ArrowJoystick(
                                              label: 'THROTTLE / YAW',
                                              size: joystickSize,
                                              springBack: false,
                                              onChanged: _onLeftStick,
                                              controller: _leftController,
                                            )
                                          : VirtualJoystick(
                                              label: 'THROTTLE / YAW',
                                              size: joystickSize,
                                              springBack: false,
                                              onChanged: _onLeftStick,
                                              controller: _leftController,
                                            ),
                                    ],
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
                                  enabled: connected,
                                  compact: !tablet,
                                  onArmToggle: _onArmToggle,
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
                                  child:
                                      settings.joystickStyle ==
                                          JoystickStyle.arrows
                                      ? ArrowJoystick(
                                          label: 'PITCH / ROLL',
                                          size: joystickSize,
                                          onChanged: _onRightStick,
                                          controller: _rightController,
                                        )
                                      : VirtualJoystick(
                                          label: 'PITCH / ROLL',
                                          size: joystickSize,
                                          onChanged: _onRightStick,
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
                          Expanded(child: TelemetryPanel(compact: !tablet)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
