import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../state/marker_style.dart';
import '../state/settings_controller.dart';
import '../state/joystick_style.dart';
import '../theme/app_theme.dart';
import '../state/unit_system.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // watch here — this whole screen should redraw live as the person
    // taps the toggle or picks a different marker, same as any other
    // Provider-backed screen.
    final settings = context.watch<SettingsController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('settings'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          _SectionLabel('appearance'.tr()),
          const SizedBox(height: 10),
          _ThemeToggleCard(settings: settings),
          const SizedBox(height: 32),
          _SectionLabel('map_pointer'.tr()),
          const SizedBox(height: 4),
          Text(
            'choose_drone_map'.tr(),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
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
          const SizedBox(height: 32),
          _SectionLabel('joystick_style'.tr()),
          const SizedBox(height: 4),
          Text(
            'choose_joystick_look'.tr(),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: JoystickStyle.values
                .map(
                  (style) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _JoystickOption(
                        style: style,
                        selected: settings.joystickStyle == style,
                        onTap: () => settings.setJoystickStyle(style),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 32),
          _SectionLabel('units'.tr()),
          const SizedBox(height: 4),
          Text(
            'speed_altitude_readouts'.tr(),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: UnitSystem.values
                .map(
                  (system) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _TextOption(
                        label: system.label,
                        selected: settings.unitSystem == system,
                        onTap: () => settings.setUnitSystem(system),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 32),
          _SectionLabel('map_style'.tr()),
          const SizedBox(height: 4),
          Text(
            'tile_imagery_map'.tr(),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _TextOption(
                    label: 'street'.tr(),
                    selected: !settings.useSatelliteMap,
                    onTap: () => settings.setUseSatelliteMap(false),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _TextOption(
                    label: 'satellite'.tr(),
                    selected: settings.useSatelliteMap,
                    onTap: () => settings.setUseSatelliteMap(true),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SectionLabel('map_theme'.tr()),
          const SizedBox(height: 4),
          Text(
            'choose_map_theme'.tr(),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _TextOption(
                    label: 'light_mode'.tr(),
                    selected: !settings.isMapDark,
                    onTap: () => settings.setMapDark(false),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _TextOption(
                    label: 'dark_mode'.tr(),
                    selected: settings.isMapDark,
                    onTap: () => settings.setMapDark(true),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SectionLabel('language'.tr()),
          const SizedBox(height: 4),
          Text(
            'select_language'.tr(),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _LanguageOption(
                label: 'English',
                locale: const Locale('en'),
                selected: context.locale == const Locale('en'),
                onTap: () => context.setLocale(const Locale('en')),
              ),
              _LanguageOption(
                label: 'اردو',
                locale: const Locale('ur'),
                selected: context.locale == const Locale('ur'),
                onTap: () => context.setLocale(const Locale('ur')),
              ),
              _LanguageOption(
                label: '中文',
                locale: const Locale('zh'),
                selected: context.locale == const Locale('zh'),
                onTap: () => context.setLocale(const Locale('zh')),
              ),
              _LanguageOption(
                label: 'Español',
                locale: const Locale('es'),
                selected: context.locale == const Locale('es'),
                onTap: () => context.setLocale(const Locale('es')),
              ),
            ],
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
                : const [Color(0xFFFFFFFF), Color(0xFF8FD3FF)],
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.black12,
              blurRadius: 14,
              offset: const Offset(0, 6),
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
                    isDark ? 'dark_mode'.tr() : 'light_mode'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF11151F),
                    ),
                  ),
                  Text(
                    'tap_to_switch'.tr(),
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

class _JoystickOption extends StatelessWidget {
  const _JoystickOption({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final JoystickStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Widget preview = style == JoystickStyle.arrows
        ? SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 8,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  width: 34,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          )
        : const Icon(
            Icons.radio_button_checked,
            size: 34,
            color: AppColors.amber,
          );

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
            preview,
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

/// Simple text-only tappable option card — same visual treatment as
/// _MarkerOption but without an icon, for two-way text choices
/// (Metric/Imperial, Street/Satellite).
class _TextOption extends StatelessWidget {
  const _TextOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.amber : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.amber : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.locale,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Locale locale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.amber : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.amber : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
