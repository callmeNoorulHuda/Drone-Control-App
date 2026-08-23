import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'connection/connection_manager.dart';
import 'screens/splash_screen.dart';
import 'state/settings_controller.dart';
import 'state/vehicle_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DroneControlApp());
}

class DroneControlApp extends StatefulWidget {
  const DroneControlApp({super.key});
  @override
  State<DroneControlApp> createState() => _DroneControlAppState();
}

class _DroneControlAppState extends State<DroneControlApp> {
  // Created ONCE, here, for the whole app's lifetime.
  late final VehicleState _vehicleState = VehicleState();
  late final ConnectionManager _connectionManager = ConnectionManager(
    _vehicleState,
  );
  late final SettingsController _settingsController = SettingsController();

  @override
  void dispose() {
    _connectionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _vehicleState),
        Provider.value(value: _connectionManager),
        ChangeNotifierProvider.value(value: _settingsController),
      ],
      // _AppShell is a separate widget (not inlined here) specifically so
      // it can call context.watch<SettingsController>() — a widget can't
      // watch a provider declared in its own build() call, only ones
      // provided further UP the tree. Splitting it into a child widget
      // gives it a context that's actually "below" MultiProvider.
      child: const _AppShell(),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return MaterialApp(
      title: 'SafeSky Nexus',
      debugShowCheckedModeBanner: false,
      theme: buildAppLightTheme(),
      darkTheme: buildAppTheme(),
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
