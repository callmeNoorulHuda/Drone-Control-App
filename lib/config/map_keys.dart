/// Map tile provider keys, injected at build/run time via --dart-define.
///
/// Never hardcode the real key here — it's read from the environment so it
/// never lands in source control.
///
/// Run/build with:
///   flutter run  --dart-define=CARTO_API_KEY=your_key_here
///   flutter build apk --dart-define=CARTO_API_KEY=your_key_here
///
/// Or, cleaner for multiple vars, put them in a gitignored file
/// (e.g. env/dev.json: {"CARTO_API_KEY": "your_key_here"}) and run:
///   flutter run --dart-define-from-file=env/dev.json
class MapKeys {
  static const String cartoApiKey = String.fromEnvironment('CARTO_API_KEY');

  /// True once a real key has actually been supplied at build time.
  static bool get hasCartoKey => cartoApiKey.isNotEmpty;
}
