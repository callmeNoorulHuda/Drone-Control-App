import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../state/vehicle_state.dart';
import '../state/connection_status.dart';
import '../connection/connection_manager.dart';
import '../theme/app_theme.dart';
import '../models/mission_waypoint.dart';
import 'package:latlong2/latlong.dart' as ll;

/// Quick-select altitude presets shown as chips under the slider.
const List<double> _kAltitudePresets = [10, 30, 50, 80, 100];

class AutoMissionPanel extends StatefulWidget {
  const AutoMissionPanel({super.key, required this.compact});

  final bool compact;

  @override
  State<AutoMissionPanel> createState() => _AutoMissionPanelState();
}

class _AutoMissionPanelState extends State<AutoMissionPanel> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final vehicleState = context.watch<VehicleState>();
    final connectionManager = context.read<ConnectionManager>();
    final scheme = Theme.of(context).colorScheme;

    final waypoints = vehicleState.missionWaypoints;
    final connected =
        vehicleState.connectionStatus == ConnectionStatus.connected;
    final executionState = vehicleState.missionExecutionState;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MissionHeader(
            state: executionState,
            compact: widget.compact,
            waypointCount: waypoints.length,
            currentWP: vehicleState.currentWaypointIndex,
            connectionLost: vehicleState.connectionLost,
            isExpanded: _isExpanded,
            onToggle: () => setState(() => _isExpanded = !_isExpanded),
          ),
          if (_isExpanded) ...[
            Flexible(
              child: waypoints.isEmpty
                  ? _EmptyWaypointsState(compact: widget.compact)
                  : Scrollbar(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                        onReorder: (oldIndex, newIndex) =>
                            vehicleState.reorderWaypoints(oldIndex, newIndex),
                        itemCount: waypoints.length,
                        shrinkWrap: true,
                        itemBuilder: (context, index) {
                          final wp = waypoints[index];

                          // ArduPilot sequences: 0=Home, 1=Takeoff, 2=First User WP.
                          final wpSeq = index + 2;
                          final isActive =
                              vehicleState.currentWaypointIndex == wpSeq;

                          // Waypoint is done if it's in the reached set
                          // OR if we've progressed significantly past it.
                          final isDone =
                              vehicleState.reachedWaypoints.contains(wpSeq) ||
                              (vehicleState.currentWaypointIndex != null &&
                                  vehicleState.currentWaypointIndex! >
                                      wpSeq + 1);

                          return _WaypointRow(
                            key: ValueKey('wp_${wp.seq}_$index'),
                            wp: wp,
                            index: index,
                            isActive: isActive,
                            isDone: isDone,
                            isLast: index == waypoints.length - 1,
                            onDelete: () {
                              HapticFeedback.selectionClick();
                              vehicleState.removeWaypoint(index);
                            },
                            onAltChanged: (val) =>
                                vehicleState.updateWaypointAltitude(index, val),
                          );
                        },
                      ),
                    ),
            ),
            Flexible(
              flex: 0,
              child: SingleChildScrollView(
                child: _MissionControls(
                  compact: widget.compact,
                  waypoints: waypoints,
                  vehicleState: vehicleState,
                  connectionManager: connectionManager,
                  connected: connected,
                  executionState: executionState,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MissionHeader extends StatelessWidget {
  const _MissionHeader({
    required this.state,
    required this.compact,
    required this.waypointCount,
    this.currentWP,
    this.connectionLost = false,
    required this.isExpanded,
    required this.onToggle,
  });

  final MissionExecutionState state;
  final bool compact;
  final int waypointCount;
  final int? currentWP;
  final bool connectionLost;
  final bool isExpanded;
  final VoidCallback onToggle;

  ({String text, Color color, IconData icon, bool pulse, String? subtext})
  _visuals() {
    switch (state) {
      case MissionExecutionState.disconnected:
        return (
          text: 'disconnected',
          color: Colors.grey,
          icon: Icons.link_off_rounded,
          pulse: false,
          subtext: 'Mission upload unavailable.',
        );
      case MissionExecutionState.connected:
        return (
          text: 'connected',
          color: const Color(0xFF2E9E5B),
          icon: Icons.link_rounded,
          pulse: false,
          subtext: null,
        );
      case MissionExecutionState.planning:
        return (
          text: 'mission_planning',
          color: AppColors.amber,
          icon: Icons.edit_location_alt_rounded,
          pulse: false,
          subtext: null,
        );
      case MissionExecutionState.ready:
        return (
          text: 'mission_ready',
          color: const Color(0xFF2F7FE0),
          icon: Icons.check_circle_outline_rounded,
          pulse: false,
          subtext: null,
        );
      case MissionExecutionState.uploading:
        return (
          text: 'uploading',
          color: AppColors.amber,
          icon: Icons.sync_rounded,
          pulse: true,
          subtext: null,
        );
      case MissionExecutionState.uploaded:
        return (
          text: 'mission_uploaded',
          color: const Color(0xFF2E9E5B),
          icon: Icons.cloud_done_rounded,
          pulse: false,
          subtext: null,
        );
      case MissionExecutionState.active:
        String text = 'auto_active';
        Color color = const Color(0xFF2E9E5B);
        if (connectionLost) {
          text = 'CONNECTION LOST';
          color = AppColors.danger;
        }
        String? sub;
        if (currentWP != null && currentWP! >= 2) {
          sub = 'WP ${currentWP! - 1} / $waypointCount';
        }
        return (
          text: text,
          color: color,
          icon: Icons.flight_takeoff_rounded,
          pulse: true,
          subtext: sub,
        );
      case MissionExecutionState.lost:
        return (
          text: 'connection_lost',
          color: AppColors.danger,
          icon: Icons.signal_wifi_off_rounded,
          pulse: false,
          subtext: 'Last known telemetry shown.',
        );
      case MissionExecutionState.complete:
        return (
          text: 'mission_complete',
          color: const Color(0xFF2F7FE0),
          icon: Icons.flag_rounded,
          pulse: false,
          subtext: 'Final waypoint reached.',
        );
      case MissionExecutionState.failed:
        return (
          text: 'mission_failed',
          color: AppColors.danger,
          icon: Icons.error_outline_rounded,
          pulse: false,
          subtext: 'Upload timed out or rejected.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = _visuals();

    Widget dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(shape: BoxShape.circle, color: v.color),
    );
    if (v.pulse) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fade(begin: 0.3, end: 1, duration: 700.ms);
    }

    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                dot,
                const SizedBox(width: 7),
                Icon(v.icon, color: v.color, size: compact ? 14 : 16),
                const SizedBox(width: 6),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      v.text.tr().toUpperCase(),
                      key: ValueKey(v.text),
                      style: TextStyle(
                        color: v.color,
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 10.5 : 12,
                        letterSpacing: 0.4,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            if (isExpanded && v.subtext != null) ...[
              const SizedBox(height: 4),
              Text(
                v.subtext!.tr(),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: compact ? 9.5 : 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (isExpanded && waypointCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$waypointCount WP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyWaypointsState extends StatelessWidget {
  const _EmptyWaypointsState({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 16 : 30,
            horizontal: 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                    painter: _DashedCirclePainter(color: scheme.outlineVariant),
                    child: SizedBox(
                      width: compact ? 40 : 54,
                      height: compact ? 40 : 54,
                      child: Icon(
                        Icons.add_location_alt_outlined,
                        color: scheme.onSurfaceVariant,
                        size: compact ? 20 : 24,
                      ),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(
                    begin: -3,
                    end: 3,
                    duration: 1400.ms,
                    curve: Curves.easeInOut,
                  ),
              SizedBox(height: compact ? 10 : 16),
              Text(
                'tap_map_to_add_waypoints'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: compact ? 11 : 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaypointRow extends StatelessWidget {
  const _WaypointRow({
    super.key,
    required this.wp,
    required this.index,
    required this.isActive,
    required this.isDone,
    required this.isLast,
    required this.onDelete,
    required this.onAltChanged,
  });

  final MissionWaypoint wp;
  final int index;
  final bool isActive;
  final bool isDone;
  final bool isLast;
  final VoidCallback onDelete;
  final ValueChanged<double> onAltChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('wp_$index${wp.lat}${wp.lon}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              child: Column(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? Colors.grey
                          : (isActive ? AppColors.amber : scheme.surface),
                      border: Border.all(
                        color: isDone
                            ? Colors.grey
                            : (isActive
                                  ? AppColors.amber
                                  : scheme.outlineVariant),
                        width: 1.4,
                      ),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: (isActive || isDone)
                            ? Colors.white
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.4,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: scheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Opacity(
                opacity: isDone ? 0.6 : 1.0,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'WP ${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: AppColors.amber.withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.amber,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                          if (isDone) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 14,
                            ),
                          ],
                          const Spacer(),
                          Text(
                            '${wp.alt.round()} m',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${wp.lat.toStringAsFixed(4)}, ${wp.lon.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: scheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          activeTrackColor: scheme.onSurfaceVariant,
                          inactiveTrackColor: scheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 10,
                          ),
                          thumbColor: isActive
                              ? AppColors.amber
                              : scheme.onSurface,
                          overlayColor: scheme.onSurface.withValues(alpha: 0.1),
                        ),
                        child: Slider(
                          value: wp.alt.clamp(2.0, 120.0),
                          min: 2.0,
                          max: 120.0,
                          divisions: 118,
                          onChanged: isDone ? null : onAltChanged,
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        children: _kAltitudePresets.map((preset) {
                          final selected = (wp.alt - preset).abs() < 0.5;
                          return GestureDetector(
                            onTap: isDone
                                ? null
                                : () {
                                    HapticFeedback.selectionClick();
                                    onAltChanged(preset);
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? scheme.onSurface
                                    : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${preset.round()}m',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? scheme.surface
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionControls extends StatelessWidget {
  const _MissionControls({
    required this.compact,
    required this.waypoints,
    required this.vehicleState,
    required this.connectionManager,
    required this.connected,
    required this.executionState,
  });

  final bool compact;
  final List<MissionWaypoint> waypoints;
  final VehicleState vehicleState;
  final ConnectionManager connectionManager;
  final bool connected;
  final MissionExecutionState executionState;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final outOfRange = waypoints.any(
      (wp) =>
          ll.Distance().as(
            ll.LengthUnit.Meter,
            ll.LatLng(vehicleState.latitude ?? 0, vehicleState.longitude ?? 0),
            wp.toLatLng,
          ) >
          vehicleState.wifiRangeMeters,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (outOfRange)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: AppColors.danger, width: 3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.danger,
                    size: 15,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'waypoint_out_of_range'.tr(),
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.2, end: 0),
          Row(
            children: [
              Icon(
                Icons.home_rounded,
                size: 14,
                color: vehicleState.rtlAfterMission
                    ? AppColors.amber
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'rtl_after_mission'.tr(),
                  style: TextStyle(
                    fontSize: compact ? 10.5 : 12.0,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 32,
                child: Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: vehicleState.rtlAfterMission,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      vehicleState.setRtlAfterMission(val);
                    },
                    activeColor: AppColors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (executionState == MissionExecutionState.ready ||
              executionState == MissionExecutionState.uploading ||
              executionState == MissionExecutionState.failed)
            _ActionButton(
              onPressed:
                  connected && executionState != MissionExecutionState.uploading
                  ? () => connectionManager.uploadAndStartMission(
                      waypoints,
                      rtlAfter: vehicleState.rtlAfterMission,
                    )
                  : null,
              icon: executionState == MissionExecutionState.uploading
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      executionState == MissionExecutionState.failed
                          ? Icons.refresh_rounded
                          : Icons.cloud_upload_rounded,
                      size: 17,
                    ),
              label:
                  (executionState == MissionExecutionState.failed
                          ? 'retry_upload'
                          : 'upload_and_start')
                      .tr()
                      .toUpperCase(),
              color: executionState == MissionExecutionState.failed
                  ? AppColors.danger
                  : AppColors.amber,
            ),

          if (executionState == MissionExecutionState.uploaded)
            _ActionButton(
              onPressed: connected ? () => connectionManager.startAuto() : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 17),
              label: 'start_auto'.tr().toUpperCase(),
              color: const Color(0xFF2E9E5B), // Green for Go
            ),

          if (executionState == MissionExecutionState.active ||
              (connected && vehicleState.armed))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _ActionButton(
                onPressed: connected
                    ? () => connectionManager.setMode('RTL')
                    : null,
                icon: const Icon(Icons.home_rounded, size: 17),
                label: 'rtl'.tr().toUpperCase(),
                color: AppColors.danger,
              ),
            ),
          if (waypoints.isNotEmpty &&
              executionState != MissionExecutionState.active)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => vehicleState.clearWaypoints(),
                icon: Icon(
                  Icons.delete_sweep_rounded,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                label: Text(
                  'clear_all'.tr(),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final Color color;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: enabled
          ? (_) {
              setState(() => _pressed = true);
              HapticFeedback.lightImpact();
            }
          : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: enabled ? widget.color : Colors.transparent,
                border: Border.all(
                  color: enabled
                      ? widget.color
                      : scheme.outlineVariant.withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme(
                    data: IconThemeData(
                      color: enabled ? Colors.white : scheme.onSurfaceVariant,
                    ),
                    child: widget.icon,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: enabled ? Colors.white : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    const dashCount = 16;
    const gapFraction = 0.45;
    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i / dashCount) * 2 * 3.141592653589793;
      final sweep = (2 * 3.141592653589793 / dashCount) * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
