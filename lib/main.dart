import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
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
