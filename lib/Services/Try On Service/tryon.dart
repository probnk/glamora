// lib/Services/TryOnService/tryon.dart  ← NO SPACES IN FOLDER NAME!

import 'dart:async';
import 'dart:io';  // For Platform.isAndroid
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class TryOnScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const TryOnScreen({required this.cameras, super.key});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  Pose? _lastPose;

  // Your Firebase URLs
  String frontImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/glamora-c4094.appspot.com/o/Blue%20Lightning%20Wolf%20Power%20Hoodie%2FChatGPT%20Image%20Oct%2025%2C%202025%2C%2008_49_46%20PM.png?alt=media&token=f5ae10ea-cac8-4c60-8bc0-657c9db85573';
  String backImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/glamora-c4094.appspot.com/o/Blue%20Lightning%20Wolf%20Power%20Hoodie%2FChatGPT%20Image%20Oct%2025%2C%202025%2C%2008_49_46%20PM.png?alt=media&token=f5ae10ea-cac8-4c60-8bc0-657c9db85573';

  bool _showFront = true;
  ui.Image? _shirtImage;
  Size? _cameraPreviewSize;
  int _cameraRotation = 0;

  final BaseCacheManager _cacheManager = DefaultCacheManager();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Delay fixes CameraX race on Android 13/14
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _initializeCamera();
        _loadShirtImage();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_cameraController != null) return;

    final camera = widget.cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,  // ← Docs: Explicit NV21 for Android
    );

    try {
      await _cameraController!.initialize();
      _cameraPreviewSize = _cameraController!.value.previewSize;
      _cameraRotation = _cameraController!.description.sensorOrientation;

      await _cameraController!.startImageStream(_processCameraImage);

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  // EXACT SYNTAX FROM PUB.DEV DOCS (Android: single plane, no bytesPerRow/format)
  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || !mounted) return;
    _isProcessing = true;

    try {
      // Docs: Check for single plane (NV21 on Android)
      if (image.planes.length != 1) {
        debugPrint("Multi-plane image rejected (expected 1 for NV21)");
        return;
      }
      final plane = image.planes.first;
      final format = InputImageFormatValue.fromRawValue(image.format.raw);

      // Docs: Validate Android NV21
      if (Platform.isAndroid && format != InputImageFormat.nv21) {
        debugPrint("Invalid format for Android: $format (expected nv21)");
        return;
      }

      final inputImage = InputImage.fromBytes(
        bytes: plane.bytes,  // ← Docs: Use plane.bytes directly (no concat!)
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),  // Required
          rotation: _rotationIntToImageRotation(_cameraRotation),  // Optional, but used on Android
          bytesPerRow: plane.bytesPerRow, // used only in iOS
          format: InputImageFormat.nv21, // used only in iOS
          // bytesPerRow: null,  // Optional/ignored on Android – omitted (fixes your error!)
        ),
      );

      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isNotEmpty) {
        _lastPose = poses.first;
      } else {
        _lastPose = null;
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Pose detection error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    return switch (rotation) {
      0 => InputImageRotation.rotation0deg,
      90 => InputImageRotation.rotation90deg,
      180 => InputImageRotation.rotation180deg,
      _ => InputImageRotation.rotation270deg,
    };
  }

  Future<void> _loadShirtImage() async {
    final url = _showFront ? frontImageUrl : backImageUrl;
    try {
      final file = await _cacheManager.getSingleFile(url);
      final data = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      _shirtImage = frame.image;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Shirt load error: $e");
    }
  }

  void _toggleFrontBack() async {
    setState(() => _showFront = !_showFront);
    await _loadShirtImage();
  }

  Offset _cameraPointToScreen(Offset point, Size preview, Size screen) {
    final scale = max(
      screen.width / preview.width,
      screen.height / preview.height,
    );
    final scaledW = preview.width * scale;
    final scaledH = preview.height * scale;
    final dx = (screen.width - scaledW) / 2;
    final dy = (screen.height - scaledH) / 2;
    return Offset(point.dx * scale + dx, point.dy * scale + dy);
  }

  _ShirtTransform? _computeShirtTransform(Size screenSize) {
    final pose = _lastPose;
    if (pose == null) return null;

    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lh = pose.landmarks[PoseLandmarkType.leftHip];
    final rh = pose.landmarks[PoseLandmarkType.rightHip];

    if (ls == null || rs == null || lh == null || rh == null) return null;

    final preview = _cameraPreviewSize ?? const Size(1280, 720);

    final leftS = _cameraPointToScreen(Offset(ls.x, ls.y), preview, screenSize);
    final rightS = _cameraPointToScreen(Offset(rs.x, rs.y), preview, screenSize);
    final leftH = _cameraPointToScreen(Offset(lh.x, lh.y), preview, screenSize);
    final rightH = _cameraPointToScreen(Offset(rh.x, rh.y), preview, screenSize);

    final shoulderCenter = Offset((leftS.dx + rightS.dx) / 2, (leftS.dy + rightS.dy) / 2);
    final hipCenter = Offset((leftH.dx + rightH.dx) / 2, (leftH.dy + rightH.dy) / 2);
    final shoulderWidth = (rightS - leftS).distance;

    const targetShoulderPx = 800.0;
    final scale = shoulderWidth / targetShoulderPx;
    final angle = atan2(rightS.dy - leftS.dy, rightS.dx - leftS.dx);
    final centerY = shoulderCenter.dy + (hipCenter.dy - shoulderCenter.dy) * 0.45;

    return _ShirtTransform(
      center: Offset(shoulderCenter.dx, centerY),
      scale: scale,
      rotation: angle,
      shoulderWidth: shoulderWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isCameraInitialized
          ? SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreviewWidget(controller: _cameraController!),
            LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final transform = _computeShirtTransform(size);

                return Stack(
                  children: [
                    if (_shirtImage != null && transform != null)
                      Positioned(
                        left: transform.center.dx - (_shirtImage!.width * transform.scale) / 2,
                        top: transform.center.dy - (_shirtImage!.height * transform.scale) / 2,
                        child: Transform.rotate(
                          angle: transform.rotation,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: _shirtImage!.width * transform.scale,
                            height: _shirtImage!.height * transform.scale,
                            child: RawImage(image: _shirtImage!, fit: BoxFit.fill),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        left: size.width / 2 - 120,
                        top: size.height / 2 - 160,
                        child: Opacity(
                          opacity: 0.25,
                          child: Image.network(
                            _showFront ? frontImageUrl : backImageUrl,
                            width: 240,
                            height: 320,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => const SizedBox(),
                          ),
                        ),
                      ),

                    // Debug keypoints
                    if (_lastPose != null)
                      CustomPaint(
                        painter: DebugPosePainter(pose: _lastPose!, previewSize: _cameraPreviewSize),
                        size: size,
                      ),

                    // Controls
                    Positioned(
                      right: 16,
                      bottom: 30,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'switch',
                            onPressed: _toggleFrontBack,
                            child: const Icon(Icons.swap_horiz),
                          ),
                          const SizedBox(height: 12),
                          FloatingActionButton.small(
                            heroTag: 'snapshot',
                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Snapshot coming soon!')),
                            ),
                            child: const Icon(Icons.photo_camera),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

class _ShirtTransform {
  final Offset center;
  final double scale;
  final double rotation;
  final double shoulderWidth;
  const _ShirtTransform({
    required this.center,
    required this.scale,
    required this.rotation,
    required this.shoulderWidth,
  });
}

class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;
  const CameraPreviewWidget({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: _calculateScale(context),
      child: Center(child: CameraPreview(controller)),
    );
  }

  double _calculateScale(BuildContext context) {
    if (!controller.value.isInitialized || controller.value.previewSize == null) return 1.0;
    final previewSize = controller.value.previewSize!;
    final screenSize = MediaQuery.of(context).size;
    return max(screenSize.width / previewSize.height, screenSize.height / previewSize.width);
  }
}

class DebugPosePainter extends CustomPainter {
  final Pose pose;
  final Size? previewSize;
  const DebugPosePainter({required this.pose, required this.previewSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0;

    void drawPoint(PoseLandmark? lm, Color color) {
      if (lm == null || previewSize == null) return;
      final scaleX = size.width / previewSize!.width;
      final scaleY = size.height / previewSize!.height;
      final scale = max(scaleX, scaleY);
      final dx = (size.width - previewSize!.width * scale) / 2;
      final dy = (size.height - previewSize!.height * scale) / 2;
      final pt = Offset(lm.x.toDouble() * scale + dx, lm.y.toDouble() * scale + dy);
      paint.color = color;
      canvas.drawCircle(pt, 6.0, paint);
    }

    drawPoint(pose.landmarks[PoseLandmarkType.leftShoulder], Colors.yellow);
    drawPoint(pose.landmarks[PoseLandmarkType.rightShoulder], Colors.yellow);
    drawPoint(pose.landmarks[PoseLandmarkType.leftHip], Colors.cyan);
    drawPoint(pose.landmarks[PoseLandmarkType.rightHip], Colors.cyan);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// CameraHelper (keep this in a separate file: lib/utils/camera_helper.dart)
class CameraHelper {
  static List<CameraDescription>? _cameras;
  static bool _isInitializing = false;

  static Future<List<CameraDescription>> getCameras() async {
    if (_cameras != null) return _cameras!;
    if (_isInitializing) {
      while (_isInitializing) await Future.delayed(const Duration(milliseconds: 50));
      return _cameras ?? [];
    }
    _isInitializing = true;
    try {
      _cameras = await availableCameras();
      return _cameras!;
    } catch (e) {
      debugPrint("CameraHelper Error: $e");
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  static void clearCache() => _cameras = null;
}