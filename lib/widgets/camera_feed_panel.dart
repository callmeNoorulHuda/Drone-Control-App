import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Live camera feed card for the side panel.
///
/// NOTE: this is a visual placeholder — there's no actual video pipeline
/// wired up yet (no RTSP/WebRTC source from the drone's companion
/// computer). When you're ready to make this real, pub.dev options worth
/// looking at: `flutter_vlc_player` (handles RTSP well) or `video_player`
/// + a companion streaming server if you go the WebRTC/HLS route. Ask me
/// when you get there and I'll wire whichever fits your video source.
class CameraFeedPanel extends StatelessWidget {
  const CameraFeedPanel({super.key, required this.connected, this.compact = false});

  final bool connected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Placeholder "footage" gradient — swap for a real video
              // widget once a stream source is picked.
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF17233D), Color(0xFF0C1122)],
                  ),
                ),
              ),
              Center(
                child: Icon(
                  connected ? Icons.videocam_outlined : Icons.videocam_off_outlined,
                  size: compact ? 20 : 28,
                  color: AppColors.textSecondary,
                ),
              ),
              if (connected)
                Positioned(
                  top: compact ? 6 : 8,
                  left: compact ? 6 : 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 8 : 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              if (!connected)
                Positioned(
                  bottom: compact ? 6 : 8,
                  left: 0,
                  right: 0,
                  child: Text(
                    'NO SIGNAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: compact ? 8 : 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
