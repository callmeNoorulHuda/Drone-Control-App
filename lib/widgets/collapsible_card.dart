import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A panel that can be collapsed down to just its header (drag handle +
/// header content) by tapping the chevron or swiping down on the header,
/// and expanded again by tapping or swiping up — same interaction pattern
/// as pulling down a phone's notification shade, just inverted (collapse
/// = swipe down here, since these panels sit low/anchored and collapsing
/// means "tuck the extra content away").
class CollapsibleCard extends StatefulWidget {
  const CollapsibleCard({
    super.key,
    required this.header,
    required this.child,
    this.initiallyExpanded = true,
    this.compact = false,
    this.borderRadius,
  });

  /// Content always visible, even when collapsed (e.g. "ARMED" badge or
  /// the "TELEMETRY" label) — put a short status summary here.
  final Widget header;

  /// Content only visible when expanded.
  final Widget child;

  final bool initiallyExpanded;
  final bool compact;
  final double? borderRadius;

  @override
  State<CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<CollapsibleCard> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() => setState(() => _expanded = !_expanded);

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 150 && _expanded) setState(() => _expanded = false);
    if (velocity < -150 && !_expanded) setState(() => _expanded = true);
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? (widget.compact ? 12 : 16);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            onVerticalDragEnd: _onDragEnd,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                widget.compact ? 10 : 14,
                widget.compact ? 8 : 10,
                widget.compact ? 10 : 14,
                widget.compact ? 6 : 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle — the visual cue this can slide, matching
                  // the notification-shade affordance.
                  Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: widget.header),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      widget.compact ? 10 : 14,
                      0,
                      widget.compact ? 10 : 14,
                      widget.compact ? 9 : 12,
                    ),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}
