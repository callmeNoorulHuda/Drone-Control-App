import 'package:flutter/material.dart';
import '../state/connection_status.dart';
import '../theme/app_theme.dart';

class ConnectionButton extends StatefulWidget {
  const ConnectionButton({
    super.key,
    required this.status,
    required this.connectionLost,
    required this.onTap,
    this.compact = false,
  });

  final ConnectionStatus status;
  final bool connectionLost;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<ConnectionButton> createState() => _ConnectionButtonState();
}

class _ConnectionButtonState extends State<ConnectionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _updateAnimation();
  }

  @override
  void didUpdateWidget(ConnectionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimation();
  }

  void _updateAnimation() {
    if (widget.status == ConnectionStatus.connecting ||
        widget.status == ConnectionStatus.timedOut ||
        widget.connectionLost) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool connected = widget.status == ConnectionStatus.connected;
    final bool connecting = widget.status == ConnectionStatus.connecting;
    final bool error =
        widget.status == ConnectionStatus.timedOut || widget.connectionLost;

    final Color statusColor = connected
        ? AppColors.success
        : connecting
        ? AppColors.amber
        : error
        ? AppColors.danger
        : AppColors.textSecondary;

    final String label = connected
        ? 'Connected'
        : connecting
        ? 'Connecting...'
        : widget.connectionLost
        ? 'Connection Lost'
        : widget.status == ConnectionStatus.timedOut
        ? 'Timed Out'
        : 'Connect';

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 10 : 14,
              vertical: widget.compact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(
                alpha: (connecting || error)
                    ? 0.12 * _pulseAnimation.value
                    : 0.12,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusColor.withValues(
                  alpha: (connecting || error)
                      ? 0.4 * _pulseAnimation.value
                      : 0.4,
                ),
                width: 1.5,
              ),
              boxShadow: connected
                  ? [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Status Dot
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (connecting || error)
                      Container(
                        width: widget.compact ? 12 : 14,
                        height: widget.compact ? 12 : 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor.withValues(
                            alpha: 0.3 * (1.0 - _pulseAnimation.value),
                          ),
                        ),
                      ),
                    Container(
                      width: widget.compact ? 7 : 9,
                      height: widget.compact ? 7 : 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: widget.compact ? 6 : 8),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: widget.compact ? 10.5 : 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
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
