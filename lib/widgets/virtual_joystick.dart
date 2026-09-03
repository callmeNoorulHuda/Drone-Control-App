import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../state/joystick_controller.dart';
import '../theme/app_theme.dart';
import 'package:drone_control/state/vehicle_state.dart';
import 'package:drone_control/state/connection_status.dart';

/// A draggable virtual joystick. Reports normalized values in [-1, 1] for
/// both axes via [onChanged], and resets to center on release (matching a
/// spring-centered gimbal — pass [springBack: false] for a throttle-style
/// stick that should hold its position, e.g. if you want that behavior).
///
/// VehicleState is now read via Provider (context.watch) instead of being
/// passed in + manually listened to — it's shared app-wide state, so it
/// belongs in the widget tree above this one (see setup note below).
///
/// JoystickController stays a plain constructor param + addListener, same
/// as TextEditingController or ScrollController — it's a controller owned
/// per-widget-instance, not global state, so it doesn't belong in Provider.
class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({
    super.key,
    required this.label,
    this.size = 150,
    this.springBack = true,
    this.onChanged,
    this.controller,
  });

  final String label;
  final double size;
  final bool springBack;
  final ValueChanged<Offset>? onChanged;
  final JoystickController? controller;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _stick = Offset.zero; // normalized, -1..1 on each axis

  double get _knobSize => (widget.size * 0.27).clamp(46, 76);

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onControllerMoved);
  }

  void _onControllerMoved() {
    setState(() => _stick = widget.controller!.target);
    widget.onChanged?.call(_stick);
  }

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
    final newDx = 0.0;
    final newDy = widget.springBack ? 0.0 : _stick.dy;
    final next = Offset(newDx, newDy);
    setState(() => _stick = next);
    widget.onChanged?.call(next);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerMoved);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // context.watch subscribes this widget to VehicleState automatically —
    // no manual addListener/removeListener/dispose needed for it anymore.
    // Whenever VehicleState calls notifyListeners(), this build() re-runs.
    final vehicleState = context.watch<VehicleState>();
    final scheme = Theme.of(context).colorScheme;

    // Same effect as the old _onVehicleStateChanged listener: if we're not
    // connected, force the stick back to center. This runs as part of
    // build() now instead of a separate callback, since watch() already
    // guarantees build() re-runs when connectionStatus changes.
    if (vehicleState.connectionStatus != ConnectionStatus.connected &&
        _stick != Offset.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _stick = Offset.zero);
          widget.onChanged?.call(Offset.zero);
        }
      });
    }

    final radius = widget.size / 2;
    final knob = _knobSize;
    final travel = radius - (knob / 2 + 4);
    final arrowInset = radius * 0.10; // how far arrows sit from the edge

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
              color: scheme.surface,
              border: Border.all(color: scheme.outlineVariant, width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // crosshair
                Container(
                  width: 1,
                  height: widget.size,
                  color: scheme.outlineVariant,
                ),
                Container(
                  width: widget.size,
                  height: 1,
                  color: scheme.outlineVariant,
                ),
                // NEW: directional arrows at N / S / E / W
                Positioned(
                  top: arrowInset,
                  child: Icon(
                    Icons.keyboard_arrow_up,
                    color: scheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                Positioned(
                  bottom: arrowInset,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: scheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                Positioned(
                  left: arrowInset,
                  child: Icon(
                    Icons.keyboard_arrow_left,
                    color: scheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                Positioned(
                  right: arrowInset,
                  child: Icon(
                    Icons.keyboard_arrow_right,
                    color: scheme.onSurfaceVariant,
                    size: 22,
                  ),
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
          widget.label.tr(),
          style: TextStyle(
            fontSize: widget.size < 130 ? 9.5 : 12,
            letterSpacing: 0.8,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
