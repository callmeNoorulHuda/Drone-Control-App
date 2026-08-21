import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'connection/connection_manager.dart';
import 'screens/splash_screen.dart';
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
  // Created ONCE, here, for the whole app's lifetime — this replaces the
  // `late final VehicleState _vehicleState = VehicleState();` that used
  // to live inside MainFlightScreen. Same for ConnectionManager, since it
  // depends on _vehicleState and needs to be created after it.
  late final VehicleState _vehicleState = VehicleState();
  late final ConnectionManager _connectionManager = ConnectionManager(
    _vehicleState,
  );

  @override
  void dispose() {
    _connectionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // MultiProvider just lets you stack several Provider widgets without
      // deeply nesting them by hand. Order between these two doesn't
      // matter here since neither depends on the other being "found" via
      // context — only ConnectionManager's constructor depends on
      // _vehicleState, and that already happened above, in Dart code, not
      // through the widget tree.
      providers: [
        ChangeNotifierProvider.value(value: _vehicleState),
        Provider.value(value: _connectionManager),
      ],
      // Everything below this point — SplashScreen, and whatever it later
      // navigates to (MainFlightScreen) — can now reach both objects via
      // context.watch/context.read, no matter how deep they're nested.
      child: MaterialApp(
        title: 'SafeSky Nexus',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
