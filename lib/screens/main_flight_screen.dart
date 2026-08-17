import 'package:flutter/material.dart';
import '../connection/connection_manager.dart';
import '../state/connection_status.dart';
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

class _MainFlightScreenState extends State<MainFlightScreen> {
  late final VehicleState _vehicleState = VehicleState();
  late final ConnectionManager _connectionManager = ConnectionManager(
    _vehicleState,
  );

  // Manual = joysticks + arm/disarm + flight-mode chips are shown.
  // Auto = those disappear; only map, telemetry, and camera feed remain.
  bool _manualMode = true;

  @override
  void dispose() {
    _connectionManager.dispose();
    super.dispose();
  }

  void _onLeftStick(Offset v) {
    print('[Joystick] throttle/yaw: $v');
    _connectionManager.sendManualControl(
      throttle: -v.dy,
      yaw: v.dx,
      pitch: 0,
      roll: 0,
    );
  }

  void _onRightStick(Offset v) {
    print('[Joystick] throttle/yaw: $v');
    _connectionManager.sendManualControl(
      throttle: 0,
      yaw: 0,
      pitch: -v.dy,
      roll: v.dx,
    );
  }

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
