import 'package:flutter/material.dart';
import '../state/joystick_controller.dart';
import '../theme/app_theme.dart';
import 'package:drone_control/state/vehicle_state.dart';
import 'package:drone_control/state/connection_status.dart';

/// A draggable virtual joystick. Reports normalized values in [-1, 1] for
/// both axes via [onChanged], and resets to center on release (matching a
/// spring-centered gimbal — pass [springBack: false] for a throttle-style
/// stick that should hold its position, e.g. if you want that behavior).
class VirtualJoystick extends StatefulWidget {
  final VehicleState vehicleState;
  final JoystickController? controller;
  const VirtualJoystick({
    super.key,
    required this.label,
    this.size = 200,
    this.springBack = true,
    this.onChanged,
    required this.vehicleState,
    this.controller,
  });

  final String label;
  final double size;
  final bool springBack;
  final ValueChanged<Offset>? onChanged;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  @override
  void initState() {
    super.initState();
    widget.vehicleState.addListener(_onVehicleStateChanged);
    widget.controller?.addListener(_onControllerMoved);
  }

  void _onControllerMoved() {
    setState(() => _stick = widget.controller!.target);
    widget.onChanged?.call(_stick);
  }

  void _onVehicleStateChanged() {
    if (widget.vehicleState.connectionStatus != ConnectionStatus.connected) {
      setState(() {
        _stick = Offset.zero;
      });

      widget.onChanged?.call(Offset.zero);
    }
  }

  Offset _stick = Offset.zero; // normalized, -1..1 on each axis

  double get _knobSize => (widget.size * 0.29).clamp(32, 44);

  void _updateFromLocal(Offset local) {
    final radius = widget.size / 2;
    final center = Offset(radius, radius);
    var delta = local - center;
    final maxDist = radius - (_knobSize / 2 + 4);
    if (delta.distance > maxDist) {
      delta = Offset.fromDirection(delta.direction, maxDist);
    }
    setState(() => _stick = Offset(delta.dx / maxDist, delta.dy / maxDist));
    widget.onChanged?.call(_stick);
  }

  void _release() {
    // X-axis (left/right = yaw) always snaps back to center, like a real
    // rudder — even on the throttle stick where springBack is false.
    // Y-axis (up/down = throttle) only snaps back when springBack is true;
    // for the throttle stick it holds wherever it was released.
    final newDx = 0.0;
    final newDy = widget.springBack ? 0.0 : _stick.dy;
    final next = Offset(newDx, newDy);
    setState(() => _stick = next);
    widget.onChanged?.call(next);
  }

  @override
  void dispose() {
    widget.vehicleState.removeListener(_onVehicleStateChanged);
    widget.controller?.removeListener(_onControllerMoved);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.size / 2;
    final knob = _knobSize;
    final travel = radius - (knob / 2 + 4);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onPanStart: (d) => _updateFromLocal(d.localPosition),
          onPanUpdate: (d) => _updateFromLocal(d.localPosition),
          onPanEnd: (_) => _release(),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.hairline, width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // crosshair
                Container(
                  width: 1,
                  height: widget.size,
                  color: AppColors.hairline,
                ),
                Container(
                  width: widget.size,
                  height: 1,
                  color: AppColors.hairline,
                ),
                // stick knob
                Transform.translate(
                  offset: Offset(_stick.dx * travel, _stick.dy * travel),
                  child: Container(
                    width: knob,
                    height: knob,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.amber,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.amber.withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: widget.size < 130 ? 4 : 8),
        Text(
          widget.label,
          style: TextStyle(
            fontSize: widget.size < 130 ? 9.5 : 12,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
