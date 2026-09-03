import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../screens/settings_screen.dart';
import '../screens/vehicle_health_screen.dart';
import '../state/vehicle_state.dart';
import '../models/health_state.dart';
import '../theme/app_theme.dart';
import 'connection_button.dart';
import 'mode_toggle.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.onTapConnection,
    required this.manualMode,
    required this.onModeChanged,
    this.compact = false,
  });

  final VoidCallback onTapConnection;
  final bool manualMode;
  final ValueChanged<bool> onModeChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final vehicleState = context.watch<VehicleState>();
    final scheme = Theme.of(context).colorScheme;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 6 : 10,
          ),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: compact ? 4 : 8),
              // Enhanced Logo Container to prevent merging with background
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo_1.png',
                  height: compact ? 22 : 28,
                ),
              ),
              SizedBox(width: compact ? 8 : 12),
              if (MediaQuery.of(context).size.width > (compact ? 500 : 700))
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      scheme.onSurface,
                      scheme.onSurface.withValues(alpha: 0.7),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'app_title'.tr(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 14 : 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              const Spacer(),
              ModeToggle(
                manual: manualMode,
                onChanged: onModeChanged,
                compact: compact,
              ),
              SizedBox(width: compact ? 8 : 12),
              ConnectionButton(
                status: vehicleState.connectionStatus,
                connectionLost: vehicleState.connectionLost,
                onTap: onTapConnection,
                compact: compact,
              ),
              SizedBox(width: compact ? 8 : 12),
              _HealthIndicator(
                status: vehicleState.overallHealth,
                compact: compact,
              ),
              SizedBox(width: compact ? 4 : 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.settings_outlined,
                      color: scheme.onSurfaceVariant,
                      size: compact ? 20 : 24,
                    ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 2 : 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthIndicator extends StatelessWidget {
  final HealthStatus status;
  final bool compact;

  const _HealthIndicator({required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (status) {
      case HealthStatus.healthy:
        icon = Icons.check_circle_outline;
        color = AppColors.success;
        break;
      case HealthStatus.unhealthy:
        icon = Icons.warning_amber_rounded;
        color = AppColors.danger;
        break;
      case HealthStatus.unknown:
      default:
        icon = Icons.help_outline;
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
    }

    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const VehicleHealthScreen())),
      child: Icon(icon, color: color, size: compact ? 20 : 24),
    );
  }
}
