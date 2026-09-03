import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CollapsibleCard extends StatefulWidget {
  const CollapsibleCard({
    super.key,
    required this.header,
    required this.child,
    this.initiallyExpanded = true,
    this.compact = false,
    this.borderRadius,
  });

  final Widget header;
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black45 : Colors.black12,
                blurRadius: 20,
                offset: const Offset(0, 8),
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
                    widget.compact ? 12 : 16,
                    widget.compact ? 8 : 12,
                    widget.compact ? 12 : 16,
                    widget.compact ? 6 : 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant.withValues(alpha: 0.6),
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
                            size: 20,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(
                          widget.compact ? 12 : 16,
                          0,
                          widget.compact ? 12 : 16,
                          widget.compact ? 12 : 16,
                        ),
                        child: widget.child,
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
