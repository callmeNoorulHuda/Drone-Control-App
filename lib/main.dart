import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // This is a control app, not a general-purpose one — flying with a
  // portrait joystick layout doesn't make sense, so we lock to landscape
  // from the very first frame instead of leaving it up to device rotation.
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const DroneControlApp());
}

class DroneControlApp extends StatefulWidget {
  const DroneControlApp({super.key});

  @override
  State<DroneControlApp> createState() => _DroneControlAppState();
}

class _DroneControlAppState extends State<DroneControlApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android kicks the app back out of immersive mode whenever it's
    // backgrounded and resumed (e.g. the pilot switches apps mid-flight
    // to check something, then comes back). Re-apply it every time we
    // come back to the foreground, or the bars silently reappear.
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeSky Nexus',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashScreen(),
    );
  }
}
