import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';
import '../state/joystick_controller.dart';
import '../theme/app_theme.dart';
import 'package:drone_control/state/vehicle_state.dart';
import 'package:drone_control/state/connection_status.dart';

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
  Offset _stick = Offset.zero;

  double get _knobSize => (widget.size * 0.3).clamp(48, 80);

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
    final maxDist = radius - (_knobSize / 2 + 6);
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

    final radius = widget.size / 2;
    final knob = _knobSize;
    final travel = radius - (knob / 2 + 6);
    final arrowInset = radius * 0.15;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onPanStart: (d) => _updateFromLocal(d.localPosition),
          onPanUpdate: (d) => _updateFromLocal(d.localPosition),
          onPanEnd: (_) => _release(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glow
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // Glass Background
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surface.withValues(alpha: 0.4),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              // Crosshair Lines
              Container(
                width: 1,
                height: widget.size - 20,
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
              Container(
                width: widget.size - 20,
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
              // Directional Markers
              Positioned(
                top: arrowInset,
                child: Icon(
                  Icons.north,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 14,
                ),
              ),
              Positioned(
                bottom: arrowInset,
                child: Icon(
                  Icons.south,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 14,
                ),
              ),
              Positioned(
                left: arrowInset,
                child: Icon(
                  Icons.west,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 14,
                ),
              ),
              Positioned(
                right: arrowInset,
                child: Icon(
                  Icons.east,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 14,
                ),
              ),
              // Stick Knob with Pulse Effect
              Transform.translate(
                offset: Offset(_stick.dx * travel, _stick.dy * travel),
                child:
                    Container(
                          width: knob,
                          height: knob,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.amber,
                                AppColors.amber.withValues(alpha: 0.8),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.amber.withValues(alpha: 0.4),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: knob * 0.4,
                              height: knob * 0.4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.05, 1.05),
                          duration: 2.seconds,
                        ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            widget.label.tr().toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
