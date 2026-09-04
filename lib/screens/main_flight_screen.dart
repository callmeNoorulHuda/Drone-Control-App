import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../connection/connection_manager.dart';
import '../state/connection_status.dart';
import '../state/joystick_controller.dart';
import '../state/settings_controller.dart';
import '../state/vehicle_state.dart';
import '../models/health_state.dart';
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
import '../widgets/auto_mission_panel.dart';

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

  late final VehicleState _vehicleState;
  late final ConnectionManager _connectionManager;

  String? _lastShownError;
  VehicleAlert? _lastProcessedAlert;
  bool _timedOutDialogShown = false;

  bool _manualMode = true;
  Offset _leftStick = Offset.zero;
  Offset _rightStick = Offset.zero;
  Timer? _controlTimer;

  // --- Side Panels State --------------------------------------------
  double? _draggedRightPanelWidth;
  bool _rightPanelVisible = true;

  double? _draggedLeftPanelWidth;
  bool _leftPanelVisible = true;

  bool _dismissedConnectionOverlay = false;

  static const double _batteryWarningThreshold = 20.0;
  static const double _batteryCriticalThreshold = 10.0;
  static const double _batteryRepromptStep = 2.0;
  double? _lastBatteryPromptPercent;
  bool _batteryDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _vehicleState = context.read<VehicleState>();
    _connectionManager = context.read<ConnectionManager>();

    WidgetsBinding.instance.addObserver(this);
    _applySystemUISettings();

    _vehicleState.addListener(_onVehicleStateChanged);

    _vehicleState.addListener(() {
      if (!_vehicleState.connectionLost && _dismissedConnectionOverlay) {
        setState(() => _dismissedConnectionOverlay = false);
      }
    });

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
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> _onArmToggle(bool arm) async {
    if (arm) {
      setState(() => _forceIdleThrottleForArming = true);
      _leftController.moveTo(const Offset(0, 1));

      // Send a burst of zero-throttle packets. ArduPilot checks the last
      // few seconds of RC/Joystick input to ensure stability before arming.
      for (int i = 0; i < 5; i++) {
        await _connectionManager.sendManualControl(
          throttle: -1.0,
          yaw: _leftStick.dx,
          pitch: -_rightStick.dy,
          roll: _rightStick.dx,
        );
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    await _connectionManager.armDisarm(arm);

    if (arm) {
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (!_vehicleState.armed && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (mounted) {
        setState(() => _forceIdleThrottleForArming = false);
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

    _checkNewAlerts();
    _checkBatteryStatus();
  }

  void _checkNewAlerts() {
    final alert = _vehicleState.lastNewAlert;
    if (alert != null && alert != _lastProcessedAlert) {
      _lastProcessedAlert = alert;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Color bgColor;
        switch (alert.severity) {
          case AlertSeverity.critical:
            bgColor = AppColors.danger;
            break;
          case AlertSeverity.warning:
            bgColor = AppColors.amber;
            break;
          case AlertSeverity.info:
            bgColor = Theme.of(context).colorScheme.secondary;
            break;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  alert.severity == AlertSeverity.critical
                      ? Icons.error
                      : Icons.warning,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(alert.message)),
              ],
            ),
            backgroundColor: bgColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      });
    }
  }

  Future<void> _showConnectionTimeoutDialog() async {
    final scheme = Theme.of(context).colorScheme;
    final shouldRetry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('connection_timeout'.tr()),
        content: Text('connection_timeout_msg'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('dismiss'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('retry'.tr()),
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
      if (_vehicleState.currentMode != 'RTL') {
        _connectionManager.returnToLaunch();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('critical_battery_msg'.tr()),
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
      _lastBatteryPromptPercent = null;
    }
  }

  Future<void> _showBatteryDialog(double percent) async {
    _batteryDialogShowing = true;
    final scheme = Theme.of(context).colorScheme;
    final shouldReturn = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text('battery_low'.tr()),
        content: Text(
          'battery_rtl_msg'.tr(
            namedArgs: {'percent': percent.toStringAsFixed(0)},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text('rtl'.tr().toUpperCase()),
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
    final vehicleState = context.watch<VehicleState>();
    final settings = context.watch<SettingsController>();

    final connected =
        vehicleState.connectionStatus == ConnectionStatus.connected;
    final hasFix =
        vehicleState.latitude != null && vehicleState.longitude != null;

    final tablet = isTabletLayout(context);
    final gap = tablet ? 12.0 : 4.0;

    final defaultSidePanelWidth = tablet ? 260.0 : 135.0;
    final minPanelWidth = tablet ? 100.0 : 60.0;
    final maxPanelWidth = tablet ? 500.0 : 250.0;

    final currentRightPanelWidth = _rightPanelVisible
        ? (_draggedRightPanelWidth ?? defaultSidePanelWidth)
        : 0.0;

    final currentLeftPanelWidth = (!_manualMode && _leftPanelVisible)
        ? (_draggedLeftPanelWidth ?? defaultSidePanelWidth)
        : 0.0;

    final joystickSize = tablet ? 200.0 : 136.0;
    final edgeInset = tablet ? 20.0 : 12.0;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
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
                  // LEFT: AUTO Mission Panel (if in AUTO mode)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: currentLeftPanelWidth,
                    child: currentLeftPanelWidth > 0
                        ? Padding(
                            padding: EdgeInsets.fromLTRB(gap, gap, 0, gap),
                            child: AutoMissionPanel(compact: !tablet),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // CENTER: Map and Overlays
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(gap),
                      child: Stack(
                        children: [
                          DroneMapView(
                            latitude:
                                vehicleState.latitude ??
                                vehicleState.lastKnownLat ??
                                33.6844,
                            longitude:
                                vehicleState.longitude ??
                                vehicleState.lastKnownLon ??
                                73.0479,
                            headingDegrees: vehicleState.headingDegrees ?? 0,
                            connected: connected,
                            hasFix: hasFix || vehicleState.lastKnownLat != null,
                            isDarkMode: settings.isDarkMode,
                            isMapDark: settings.isMapDark,
                            markerStyle: settings.markerStyle,
                            useSatelliteMap: settings.useSatelliteMap,
                            onMapTap: (point) {
                              if (!_manualMode && connected) {
                                vehicleState.addWaypoint(
                                  point.latitude,
                                  point.longitude,
                                );
                              } else if (!_manualMode && !connected) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Connect to the drone to add waypoints.',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            waypoints: vehicleState.missionWaypoints,
                            homeLat: vehicleState.homeLatitude,
                            homeLon: vehicleState.homeLongitude,
                            currentWaypointIndex:
                                vehicleState.currentWaypointIndex,
                            wifiRangeMeters: vehicleState.wifiRangeMeters,
                            showSearch: !_manualMode,
                          ),
                          if (!_manualMode &&
                              vehicleState.connectionLost &&
                              !_dismissedConnectionOverlay)
                            _ConnectionLostOverlay(
                              vehicleState: vehicleState,
                              compact: !tablet,
                              onDismiss: () => setState(
                                () => _dismissedConnectionOverlay = true,
                              ),
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
                                          color: scheme.surface.withValues(
                                            alpha: 0.8,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: scheme.outlineVariant,
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
                                              label: 'throttle_yaw',
                                              size: joystickSize,
                                              springBack: false,
                                              onChanged: _onLeftStick,
                                              controller: _leftController,
                                            )
                                          : VirtualJoystick(
                                              label: 'throttle_yaw',
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
                                          label: 'pitch_roll',
                                          size: joystickSize,
                                          onChanged: _onRightStick,
                                          controller: _rightController,
                                        )
                                      : VirtualJoystick(
                                          label: 'pitch_roll',
                                          size: joystickSize,
                                          onChanged: _onRightStick,
                                          controller: _rightController,
                                        ),
                                ),
                              ),
                            ),
                          ],
                          // --- LEFT DRAG HANDLE (for AUTO Mission Panel) ---
                          if (!_manualMode)
                            Positioned(
                              left: 0,
                              bottom: edgeInset + joystickSize + 20,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: () => setState(
                                  () => _leftPanelVisible = !_leftPanelVisible,
                                ),
                                onHorizontalDragUpdate: (details) {
                                  setState(() {
                                    if (!_leftPanelVisible) {
                                      if (details.delta.dx > 5) {
                                        _leftPanelVisible = true;
                                        _draggedLeftPanelWidth =
                                            defaultSidePanelWidth;
                                      }
                                    } else {
                                      final baseWidth =
                                          _draggedLeftPanelWidth ??
                                          defaultSidePanelWidth;
                                      final newWidth =
                                          (baseWidth + details.delta.dx);

                                      if (newWidth < 40) {
                                        _leftPanelVisible = false;
                                        _draggedLeftPanelWidth = 0.0;
                                      } else {
                                        _draggedLeftPanelWidth = newWidth.clamp(
                                          minPanelWidth,
                                          maxPanelWidth,
                                        );
                                      }
                                    }
                                  });
                                },
                                child: Container(
                                  width: 32,
                                  color: Colors.transparent,
                                  child: Center(
                                    child: Container(
                                      width: 24,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: scheme.surface.withValues(
                                          alpha: 0.8,
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(8),
                                          bottomRight: Radius.circular(8),
                                        ),
                                        border: Border.all(
                                          color: scheme.outlineVariant,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(2, 0),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        _leftPanelVisible
                                            ? Icons.chevron_left
                                            : Icons.chevron_right,
                                        size: 20,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // --- RIGHT DRAG HANDLE (for Telemetry Panel) ---
                          Positioned(
                            right: 0,
                            bottom: edgeInset + joystickSize + 20,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () => setState(
                                () => _rightPanelVisible = !_rightPanelVisible,
                              ),
                              onHorizontalDragUpdate: (details) {
                                setState(() {
                                  if (!_rightPanelVisible) {
                                    if (details.delta.dx < -5) {
                                      _rightPanelVisible = true;
                                      _draggedRightPanelWidth =
                                          defaultSidePanelWidth;
                                    }
                                  } else {
                                    final baseWidth =
                                        _draggedRightPanelWidth ??
                                        defaultSidePanelWidth;
                                    final newWidth =
                                        (baseWidth - details.delta.dx);

                                    if (newWidth < 40) {
                                      _rightPanelVisible = false;
                                      _draggedRightPanelWidth = 0.0;
                                    } else {
                                      _draggedRightPanelWidth = newWidth.clamp(
                                        minPanelWidth,
                                        maxPanelWidth,
                                      );
                                    }
                                  }
                                });
                              },
                              child: Container(
                                width: 32,
                                color: Colors.transparent,
                                child: Center(
                                  child: Container(
                                    width: 24,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: scheme.surface.withValues(
                                        alpha: 0.8,
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        bottomLeft: Radius.circular(8),
                                      ),
                                      border: Border.all(
                                        color: scheme.outlineVariant,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(-2, 0),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _rightPanelVisible
                                          ? Icons.chevron_right
                                          : Icons.chevron_left,
                                      size: 20,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // RIGHT: Telemetry Panel
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: currentRightPanelWidth,
                    child: currentRightPanelWidth > 0
                        ? Padding(
                            padding: EdgeInsets.fromLTRB(0, gap, gap, gap),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                CameraFeedPanel(
                                  connected: true,
                                  compact: !tablet,
                                ),
                                SizedBox(height: gap),
                                Expanded(
                                  child: TelemetryPanel(compact: !tablet),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
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

class _ConnectionLostOverlay extends StatelessWidget {
  const _ConnectionLostOverlay({
    required this.vehicleState,
    required this.compact,
    required this.onDismiss,
  });
  final VehicleState vehicleState;
  final bool compact;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 450),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.signal_wifi_off_rounded,
                          color: AppColors.danger,
                          size: 36,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'connection_lost'.tr().toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'last_telemetry_received'.tr(
                          namedArgs: {
                            'time':
                                vehicleState.lastTelemetryTime
                                    ?.toIso8601String()
                                    .split('T')
                                    .last
                                    .substring(0, 8) ??
                                '--',
                          },
                        ),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _LastTelemetryGrid(vehicleState: vehicleState),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.amber,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => context
                            .read<ConnectionManager>()
                            .connect(ip: '192.168.4.1', port: 14550),
                        child: Text(
                          'reconnect'.tr().toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: -16,
                  top: -16,
                  child: Material(
                    color: scheme.surface,
                    elevation: 4,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 28),
                      onPressed: onDismiss,
                      color: scheme.onSurface,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LastTelemetryGrid extends StatelessWidget {
  const _LastTelemetryGrid({required this.vehicleState});
  final VehicleState vehicleState;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _LastTelemetryItem(
          label: 'altitude',
          value: '${vehicleState.lastKnownAlt?.toStringAsFixed(1) ?? '--'} m',
          icon: Icons.height,
        ),
        _LastTelemetryItem(
          label: 'speed',
          value:
              '${vehicleState.lastKnownSpeed?.toStringAsFixed(1) ?? '--'} m/s',
          icon: Icons.speed,
        ),
        _LastTelemetryItem(
          label: 'battery',
          value:
              '${vehicleState.lastKnownBattery?.toStringAsFixed(0) ?? '--'}%',
          icon: Icons.battery_std,
        ),
        _LastTelemetryItem(
          label: 'mode',
          value: vehicleState.lastKnownMode ?? '--',
          icon: Icons.settings_input_component,
        ),
      ],
    );
  }
}

class _LastTelemetryItem extends StatelessWidget {
  const _LastTelemetryItem({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: scheme.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label.tr(),
          style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
