import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../state/marker_style.dart';
import '../state/settings_controller.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // watch here — this whole screen should redraw live as the person
    // taps the toggle or picks a different marker, same as any other
    // Provider-backed screen.
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          const _SectionLabel('APPEARANCE'),
          const SizedBox(height: 10),
          _ThemeToggleCard(settings: settings),
          const SizedBox(height: 32),
          const _SectionLabel('MAP POINTER'),
          const SizedBox(height: 4),
          Text(
            'Choose how the drone is shown on the map.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: MarkerStyle.values
                .map(
                  (style) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _MarkerOption(
                        style: style,
                        selected: settings.markerStyle == style,
                        onTap: () => settings.setMarkerStyle(style),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}

/// Animated day/night card — background gradient and icon swap between a
/// warm "sunset" look (light mode) and a navy "night sky" look (dark
/// mode), so the toggle itself previews the theme it switches to.
class _ThemeToggleCard extends StatelessWidget {
  const _ThemeToggleCard({required this.settings});
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final isDark = settings.isDarkMode;
    return GestureDetector(
      onTap: settings.toggleDarkMode,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0C1122), Color(0xFF1D2270)]
                : const [Color(0xFFFFE3A6), Color(0xFF8FD3FF)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                key: ValueKey(isDark),
                color: isDark ? Colors.amberAccent : const Color(0xFFB35B00),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDark ? 'Dark Mode' : 'Light Mode',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF11151F),
                    ),
                  ),
                  Text(
                    'Tap to switch',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : const Color(0xFF3A3F4D),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isDark,
              onChanged: settings.setDarkMode,
              activeColor: AppColors.amber,
            ),
          ],
        ),
      ),
    );
  }
}

/// One tappable card showing a live preview of the SVG marker, tinted
/// orange (brand accent) regardless of theme, with a highlighted border
/// when it's the currently-selected style.
class _MarkerOption extends StatelessWidget {
  const _MarkerOption({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final MarkerStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.amber : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              style.assetPath,
              width: 38,
              height: 38,
              // Always rendered in the brand orange here, regardless of
              // theme or connection state — this is a picker preview, not
              // the live map marker (which tints amber/gray based on
              // connection status).
              colorFilter: const ColorFilter.mode(
                AppColors.amber,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              style.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.amber : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
