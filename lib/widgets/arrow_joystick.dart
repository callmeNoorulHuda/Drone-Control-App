import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../state/joystick_controller.dart';
import '../theme/app_theme.dart';
import 'package:drone_control/state/vehicle_state.dart';
import 'package:drone_control/state/connection_status.dart';

/// A D-pad style joystick that looks like a PlayStation controller's arrows.
/// Works functionally exactly like VirtualJoystick by mapping touch
/// coordinates to a normalized [-1, 1] Offset.
class ArrowJoystick extends StatefulWidget {
  const ArrowJoystick({
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
  State<ArrowJoystick> createState() => _ArrowJoystickState();
}

class _ArrowJoystickState extends State<ArrowJoystick> {
  Offset _stick = Offset.zero;

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

    // We allow a bit of travel within the cross shape
    final maxDist = radius * 0.8;
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
    final vehicleState = context.watch<VehicleState>();
    final scheme = Theme.of(context).colorScheme;

    if (vehicleState.connectionStatus != ConnectionStatus.connected &&
        _stick != Offset.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _stick = Offset.zero);
          widget.onChanged?.call(Offset.zero);
        }
      });
    }

    final arrowSize = widget.size * 0.32;
    final crossWidth = widget.size * 0.38;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onPanStart: (d) => _updateFromLocal(d.localPosition),
          onPanUpdate: (d) => _updateFromLocal(d.localPosition),
          onPanEnd: (_) => _release(),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The "PlayStation" cross background
                Container(
                  width: crossWidth,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant, width: 2),
                  ),
                ),
                Container(
                  width: widget.size,
                  height: crossWidth,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant, width: 2),
                  ),
                ),

                // Arrow Icons
                _ArrowIcon(
                  icon: Icons.keyboard_arrow_up,
                  direction: const Offset(0, -1),
                  activeStick: _stick,
                  size: arrowSize,
                  alignment: Alignment.topCenter,
                ),
                _ArrowIcon(
                  icon: Icons.keyboard_arrow_down,
                  direction: const Offset(0, 1),
                  activeStick: _stick,
                  size: arrowSize,
                  alignment: Alignment.bottomCenter,
                ),
                _ArrowIcon(
                  icon: Icons.keyboard_arrow_left,
                  direction: const Offset(-1, 0),
                  activeStick: _stick,
                  size: arrowSize,
                  alignment: Alignment.centerLeft,
                ),
                _ArrowIcon(
                  icon: Icons.keyboard_arrow_right,
                  direction: const Offset(1, 0),
                  activeStick: _stick,
                  size: arrowSize,
                  alignment: Alignment.centerRight,
                ),

                // Center pivot area (static, just for visual)
                Container(
                  width: crossWidth * 0.8,
                  height: crossWidth * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surface,
                  ),
                ),

                // Tiny active dot that moves to show exact analog position
                // within the D-pad area.
                Transform.translate(
                  offset: Offset(
                    _stick.dx * (widget.size * 0.35),
                    _stick.dy * (widget.size * 0.35),
                  ),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.amber,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.amber.withValues(alpha: 0.6),
                          blurRadius: 8,
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

class _ArrowIcon extends StatelessWidget {
  const _ArrowIcon({
    required this.icon,
    required this.direction,
    required this.activeStick,
    required this.size,
    required this.alignment,
  });

  final IconData icon;
  final Offset direction;
  final Offset activeStick;
  final double size;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Determine if the user is pushing in this direction.
    // We use a dot product to check alignment.
    final dot = (activeStick.dx * direction.dx + activeStick.dy * direction.dy);
    final isActive = dot > 0.2;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Icon(
          icon,
          color: isActive ? AppColors.amber : scheme.onSurfaceVariant,
          size: size,
        ),
      ),
    );
  }
}
