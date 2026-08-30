import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import '../theme/app_theme.dart';

class CameraDetailScreen extends StatefulWidget {
  const CameraDetailScreen({super.key, required this.connected});
  final bool connected;

  @override
  State<CameraDetailScreen> createState() => _CameraDetailScreenState();
}

class _CameraDetailScreenState extends State<CameraDetailScreen> {
  final YOLOViewController _yoloController = YOLOViewController();
  int _detectionCount = 0;

  // Fires continuously as frames are processed — we just use it to show
  // a live "N OBJECTS" counter. The bounding boxes themselves are drawn
  // natively by YOLOView, so no manual drawing code is needed here.
  void _onResult(List<YOLOResult> results) {
    if (!mounted) return;
    setState(() => _detectionCount = results.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.connected)
            YOLOView(
              // Official pretrained model — downloads once on first run, then
              // caches locally. No internet needed after that (including mid-flight).
              modelPath: 'yolo26n',
              controller: _yoloController,
              onResult: _onResult,
            )
          else
            Container(
              color: AppColors.bg,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.videocam_off_outlined,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'NO SIGNAL',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Close button
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          if (widget.connected) ...[
            Positioned(
              top: 45,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            // Live object-count readout
            Positioned(
              top: 45,
              left: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$_detectionCount OBJECTS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
