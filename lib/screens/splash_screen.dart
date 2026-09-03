import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'main_flight_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _videoController;
  bool _hasNavigated = false;
  bool _videoError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() async {
    final bool isSupported =
        kIsWeb ||
        Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows;

    if (!isSupported) {
      debugPrint('Video splash not supported on this platform. Skipping.');
      _navigateToNextScreen();
      return;
    }

    try {
      _videoController = VideoPlayerController.asset(
        'assets/video/safesky_nexus.mp4',
      );

      await _videoController!.initialize();
      if (!mounted) return;

      setState(() {});
      _videoController!.play();

      _videoController!.addListener(() {
        if (_videoController!.value.isInitialized &&
            !_videoController!.value.isPlaying &&
            _videoController!.value.position >=
                _videoController!.value.duration &&
            !_hasNavigated) {
          _navigateToNextScreen();
        }
      });
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() => _videoError = true);
      }
      // Fallback: navigate after brief delay if error occurs
      Future.delayed(const Duration(seconds: 2), _navigateToNextScreen);
    }
  }

  void _navigateToNextScreen() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, anim, __) =>
            FadeTransition(opacity: anim, child: const MainFlightScreen()),
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child:
            _videoController != null &&
                _videoController!.value.isInitialized &&
                !_videoError
            ? ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 600, // Adjust width to resize the video logo
                  maxHeight: 600, // Adjust height limit
                ),
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              )
            : const SizedBox.shrink(), // Keeps screen pure black until video is ready
      ),
    );
  }
}
