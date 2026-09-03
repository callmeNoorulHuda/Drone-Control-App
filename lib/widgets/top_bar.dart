import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../screens/settings_screen.dart';
import '../state/vehicle_state.dart';
import '../theme/app_theme.dart';
import 'connection_button.dart';
import 'mode_toggle.dart';

/// Slim header row: logo + title on the left, Manual/Auto toggle in the
/// middle, connection status and a settings shortcut on the right.
///
/// FIXED: the connection indicator used to hide its text label in compact
/// (phone) mode, leaving only a tiny colored dot with no visible "Connect"
/// affordance — easy to miss entirely. Now it's always a labeled, filled
/// pill, so it reads as a real button on every screen size.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.onTapConnection,
    required this.manualMode,
    required this.onModeChanged,
    this.compact = false,
  });

  // vehicleState field removed — fetched via context.watch below instead.
  final VoidCallback onTapConnection;
  final bool manualMode;
  final ValueChanged<bool> onModeChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Reads VehicleState from Provider and subscribes this widget to
    // rebuild whenever it changes — same effect as the old constructor
    // param, just sourced from the tree instead of passed in.
    final vehicleState = context.watch<VehicleState>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          SizedBox(width: compact ? 10 : 18),
          Image.asset('assets/images/logo.png', height: compact ? 24 : 24),
          SizedBox(width: compact ? 6 : 10),
          if (!compact || MediaQuery.of(context).size.width > 500)
            Text(
              'app_title'.tr(),
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: compact ? 13 : 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          const Spacer(),
          ModeToggle(
            manual: manualMode,
            onChanged: onModeChanged,
            compact: compact,
          ),
          SizedBox(width: compact ? 10 : 18),
          ConnectionButton(
            status: vehicleState.connectionStatus,
            connectionLost: vehicleState.connectionLost,
            onTap: onTapConnection,
            compact: compact,
          ),
          SizedBox(width: compact ? 10 : 18),
          GestureDetector(
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            child: Icon(
              Icons.settings_outlined,
              color: scheme.onSurfaceVariant,
              size: compact ? 17 : 20,
            ),
          ),
          SizedBox(width: compact ? 20 : 18),
        ],
      ),
    );
  }
}
