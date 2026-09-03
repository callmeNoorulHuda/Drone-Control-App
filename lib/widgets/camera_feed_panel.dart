import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../screens/camera_detail_screen.dart';

/// Live camera feed card for the side panel.
///
/// UPDATED: now uses the `camera` package to show the device's local camera
/// as a functional placeholder for the future drone video stream.
class CameraFeedPanel extends StatefulWidget {
  const CameraFeedPanel({
    super.key,
    required this.connected,
    this.compact = false,
  });

  final bool connected;
  final bool compact;

  @override
  State<CameraFeedPanel> createState() => _CameraFeedPanelState();
}

class _CameraFeedPanelState extends State<CameraFeedPanel> {
  CameraController? _controller;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Use the first available camera (usually the back camera on phones,
      // or the webcam on laptops).
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CameraDetailScreen(connected: widget.connected),
        ),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.compact ? 12 : 16),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Base Layer: Static Gradient (Fallback if camera fails)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: scheme.brightness == Brightness.dark
                          ? const [Color(0xFF17233D), Color(0xFF0C1122)]
                          : const [Color(0xFFE0E4F0), Color(0xFFF4F6FB)],
                    ),
                  ),
                ),

                // 2. Camera Preview: Only active when "connected" to simulate
                // drone signal.
                if (widget.connected && _isCameraInitialized)
                  CameraPreview(_controller!),

                // 3. Status Icons (visible if disconnected or camera loading)
                if (!widget.connected || !_isCameraInitialized)
                  Center(
                    child: Icon(
                      widget.connected
                          ? Icons.videocam_outlined
                          : Icons.videocam_off_outlined,
                      size: widget.compact ? 20 : 28,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),

                // 4. Overlay Labels
                if (widget.connected)
                  Positioned(
                    top: widget.compact ? 6 : 8,
                    left: widget.compact ? 6 : 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.compact ? 5 : 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'live'.tr().toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.compact ? 8 : 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                if (!widget.connected)
                  Positioned(
                    bottom: widget.compact ? 6 : 8,
                    left: 0,
                    right: 0,
                    child: Text(
                      'no_signal'.tr().toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: widget.compact ? 8 : 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
