import 'dart:async';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:glamora/models/productModel.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../constants/ar_constants.dart';
import '../../models/ar_pose.dart';
import 'pose_detection_service.dart';
import 'image_cache_service.dart';
import 'performance_monitor.dart';

class ARService {
  CameraController? _cameraController;
  late PoseDetector _poseDetector;
  final PoseDetectionService _poseDetectionService = PoseDetectionService();
  final ImageCacheService _imageCacheService = ImageCacheService();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();

  StreamController<ARPose?> _poseStreamController = StreamController<ARPose?>.broadcast();
  StreamController<ui.Image?> _arOverlayController = StreamController<ui.Image?>.broadcast();
  StreamController<double> _performanceStreamController = StreamController<double>.broadcast();

  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  int _frameCounter = 0;
  int _successfulFrames = 0;
  int _failedFrames = 0;
  DateTime? _lastProcessTime;
  ARPose? _lastValidPose;
  ClothingProductModel? _currentProduct;
  ui.Image? _currentFrontImage;
  ui.Image? _currentBackImage;
  ui.Size _screenSize = ui.Size.zero;

  // Calibration data
  double _avgShoulderDistance = 0.0;
  double _avgTorsoHeight = 0.0;
  List<double> _calibrationData = [];
  bool _isCalibrated = false;

  // Performance optimization flags
  bool _useLowResProcessing = false;
  bool _enableFrameSkipping = true;
  int _processedFrames = 0;

  Stream<ARPose?> get poseStream => _poseStreamController.stream;
  Stream<ui.Image?> get arOverlayStream => _arOverlayController.stream;
  Stream<double> get performanceStream => _performanceStreamController.stream;

  bool get isInitialized => _isInitialized;
  bool get isCalibrated => _isCalibrated;
  double get successRate => _processedFrames > 0 ? (_successfulFrames / _processedFrames) * 100 : 0.0;

  CameraController? get cameraController => _cameraController;
  List<CameraDescription>? get cameras => _cameras;

  Future<void> switchCamera(CameraDescription newCamera) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      newCamera,
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();

    // Restart image stream
  }

  Future<void> initialize() async {
    try {
      _performanceMonitor.startMonitoring();

      // Initialize camera
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No cameras available');
      }

      // Choose back camera
      final backCamera = _cameras!.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      // Set resolution based on performance
      final resolutionPreset = _getResolutionPreset();

      _cameraController = CameraController(
        backCamera,
        resolutionPreset,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      // Initialize pose detector
      _poseDetector = _poseDetectionService.initializeDetector();

      // Start performance monitoring
      _startPerformanceMonitoring();

      _isInitialized = true;

      if (kDebugMode) {
        print('AR Service initialized successfully');
        print('Camera resolution: ${_cameraController!.value.previewSize}');
        print('Using low-res processing: $_useLowResProcessing');
      }
    } catch (e) {
      _isInitialized = false;
      if (kDebugMode) {
        print('Camera initialization error: $e');
      }
      rethrow;
    }
  }

  ResolutionPreset _getResolutionPreset() {
    if (_performanceMonitor.isLowMemoryDevice) {
      _useLowResProcessing = true;
      return ResolutionPreset.low;
    }

    switch (ARConstants.cameraResolutionPreset) {
      case 0: return ResolutionPreset.low;
      case 1: return ResolutionPreset.medium;
      case 2: return ResolutionPreset.high;
      default: return ResolutionPreset.medium;
    }
  }

  Future<void> loadProductForAR(ClothingProductModel product) async {
    try {
      _currentProduct = product;

      // Preload images with caching
      final loadStartTime = DateTime.now();

      await Future.wait([
        _loadImage(product.front, true),
        _loadImage(product.back, false),
      ]);

      final loadTime = DateTime.now().difference(loadStartTime).inMilliseconds;

      if (kDebugMode) {
        print('Product images loaded in ${loadTime}ms');
        print('Front image size: ${_currentFrontImage?.width}x${_currentFrontImage?.height}');
        print('Back image size: ${_currentBackImage?.width}x${_currentBackImage?.height}');
      }

      // Reset calibration
      _resetCalibration();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading product for AR: $e');
      }
      rethrow;
    }
  }

  Future<void> _loadImage(String url, bool isFront) async {
    try {
      if (url.isEmpty) {
        throw Exception('Image URL is empty');
      }

      final image = await _imageCacheService.loadImage(
        url,
        maxWidth: _useLowResProcessing ? 512 : 1024,
        maxHeight: _useLowResProcessing ? 512 : 1024,
      );

      if (isFront) {
        _currentFrontImage = image;
      } else {
        _currentBackImage = image;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading ${isFront ? 'front' : 'back'} image: $e');
      }
      rethrow;
    }
  }

  Future<void> startPoseDetection(ui.Size screenSize) async {
    if (!_isInitialized || _cameraController == null) {
      throw Exception('AR Service not initialized');
    }

    _screenSize = screenSize;

    // Start camera preview
    await _cameraController!.startImageStream(_processCameraFrame);

    if (kDebugMode) {
      print('Pose detection started');
      print('Screen size: $screenSize');
    }
  }

  Future<void> _processCameraFrame(CameraImage cameraImage) async {
    if (!_isInitialized || _cameraController == null) {
      return;
    }

    if (_isProcessing && _enableFrameSkipping) {
      return;
    }

    final now = DateTime.now();
    if (_lastProcessTime != null) {
      final elapsed = now.difference(_lastProcessTime!).inMilliseconds;
      if (elapsed < 16) { // Cap at ~60 FPS
        return;
      }
    }

    _frameCounter++;
    if (_frameCounter % ARConstants.poseDetectionInterval != 0) {
      return;
    }

    _isProcessing = true;
    _lastProcessTime = now;
    _processedFrames++;

    try {
      final processStartTime = DateTime.now();

      // Convert camera image to input image
      final inputImage = _poseDetectionService.cameraImageToInputImage(
        cameraImage,
        _cameraController!.description,
      );

      // Detect poses
      final poses = await _poseDetector.processImage(inputImage);

      final processTime = DateTime.now().difference(processStartTime).inMilliseconds;

      if (processTime > 50) {
        _performanceMonitor.recordSlowFrame(processTime);
      }

      ARPose? arPose;

      if (poses.isNotEmpty) {
        final pose = poses.first;
        final landmarks = _poseDetectionService.extractLandmarks(pose);

        if (landmarks.isNotEmpty) {
          arPose = ARPose.fromLandmarks(
            landmarks,
            pose.landmarks.values
                .map((landmark) => landmark.likelihood)
                .reduce((a, b) => a + b) / pose.landmarks.length,
            ui.Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
          );

          if (arPose.isValidForAR) {
            _successfulFrames++;

            // Update calibration data
            _updateCalibration(arPose);

            // Generate AR overlay
            await _generateAROverlay(arPose);

            _lastValidPose = arPose;
          } else {
            _failedFrames++;
          }
        } else {
          _failedFrames++;
        }
      } else {
        _failedFrames++;
      }

      _poseStreamController.add(arPose);

      // Update performance metrics
      final totalTime = DateTime.now().difference(processStartTime).inMilliseconds;
      _performanceStreamController.add(totalTime.toDouble());

      // Adjust processing based on performance
      _adjustProcessingStrategy();

    } catch (e) {
      if (kDebugMode) {
        print('Error processing frame: $e');
      }
      _failedFrames++;
      _poseStreamController.add(null);
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _generateAROverlay(ARPose pose) async {
    if (_currentProduct == null) return;

    final renderStartTime = DateTime.now();

    try {
      final ui.Image? activeImage = pose.isFacingFront ? _currentFrontImage : _currentBackImage;
      if (activeImage == null) return;

      // Calculate shirt transformation
      final transform = _calculateShirtTransform(pose, activeImage);

      // Create AR overlay
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;

      // Draw shirt
      canvas.save();
      canvas.translate(transform.position.dx, transform.position.dy);
      canvas.rotate(transform.rotation);
      canvas.scale(transform.scale, transform.scale);

      canvas.drawImageRect(
        activeImage,
        ui.Rect.fromLTWH(0, 0, activeImage.width.toDouble(), activeImage.height.toDouble()),
        ui.Rect.fromCenter(
          center: ui.Offset.zero,
          width: transform.size.width,
          height: transform.size.height,
        ),
        paint,
      );

      canvas.restore();

      // Convert to image
      final picture = recorder.endRecording();
      final arImage = await picture.toImage(
        _screenSize.width.toInt(),
        _screenSize.height.toInt(),
      );

      final renderTime = DateTime.now().difference(renderStartTime).inMilliseconds;

      if (renderTime > 16) {
        _performanceMonitor.recordSlowRender(renderTime);
      }

      _arOverlayController.add(arImage);
    } catch (e) {
      if (kDebugMode) {
        print('Error generating AR overlay: $e');
      }
    }
  }

  ShirtTransform _calculateShirtTransform(ARPose pose, ui.Image shirtImage) {
    // Get calibrated measurements
    final shoulderDistance = _isCalibrated ? _avgShoulderDistance : pose.shoulderDistance;
    final torsoHeight = _isCalibrated ? _avgTorsoHeight : pose.torsoHeight;

    // Calculate base size
    final baseWidth = shoulderDistance * ARConstants.shirtWidthMultiplier;
    final baseHeight = torsoHeight * ARConstants.shirtHeightMultiplier;

    // Apply product-specific scaling
    final productScale = 1.0;

    // Calculate final size maintaining aspect ratio
    final shirtAspectRatio = shirtImage.width / shirtImage.height;
    final targetWidth = baseWidth * productScale;
    final targetHeight = targetWidth / shirtAspectRatio;

    // Calculate position
    final position = pose.shoulderCenter;
    final verticalOffset = torsoHeight * ARConstants.shirtVerticalOffset;

    // Calculate rotation
    final rotation = pose.shoulderAngle;

    return ShirtTransform(
      position: ui.Offset(position.x, position.y + verticalOffset),
      size: ui.Size(targetWidth, targetHeight),
      rotation: rotation,
      scale: productScale,
    );
  }

  void _updateCalibration(ARPose pose) {
    _calibrationData.add(pose.shoulderDistance);

    if (_calibrationData.length > ARConstants.calibrationFrames) {
      _calibrationData.removeAt(0);
    }

    if (_calibrationData.length >= 10) {
      _avgShoulderDistance = _calibrationData.reduce((a, b) => a + b) / _calibrationData.length;
      _avgTorsoHeight = pose.torsoHeight;
      _isCalibrated = true;
    }
  }

  void _resetCalibration() {
    _calibrationData.clear();
    _avgShoulderDistance = 0.0;
    _avgTorsoHeight = 0.0;
    _isCalibrated = false;
    _successfulFrames = 0;
    _failedFrames = 0;
    _processedFrames = 0;
  }

  void _adjustProcessingStrategy() {
    final successRate = this.successRate;

    if (successRate < 30) {
      // Poor success rate, reduce processing
      _enableFrameSkipping = true;
      if (!_useLowResProcessing) {
        _useLowResProcessing = true;
        // Would need to reinitialize camera with lower resolution
      }
    } else if (successRate > 80) {
      // Good success rate, can increase processing
      _enableFrameSkipping = false;
    }

    // Check memory usage
    if (_performanceMonitor.currentMemoryUsage > 100 * 1024 * 1024) { // 100MB
      _imageCacheService.clearCache();
      if (kDebugMode) {
        print('High memory usage detected, cleared image cache');
      }
    }
  }

  void _startPerformanceMonitoring() {
    Timer.periodic(const Duration(seconds: 5), (_) {
      final metrics = _performanceMonitor.getMetrics();

      if (kDebugMode) {
        print('Performance Metrics:');
        print('  FPS: ${metrics['fps']?.toStringAsFixed(1)}');
        print('  Memory: ${(metrics['memory']! / 1024 / 1024).toStringAsFixed(1)}MB');
        print('  CPU: ${metrics['cpu']?.toStringAsFixed(1)}%');
        print('  Success Rate: ${successRate.toStringAsFixed(1)}%');
        print('  Calibrated: $_isCalibrated');
      }

      // Notify if performance is poor
      if (metrics['fps']! < 20) {
        if (kDebugMode) {
          print('Warning: Low FPS detected');
        }
      }
    });
  }

  Future<Uint8List?> captureARSnapshot() async {
    try {
      if (_lastValidPose == null || _currentProduct == null) {
        return null;
      }

      final activeImage = _lastValidPose!.isFacingFront ? _currentFrontImage : _currentBackImage;
      if (activeImage == null) return null;

      final transform = _calculateShirtTransform(_lastValidPose!, activeImage);

      // Create final image with shirt overlay
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;

      // Draw shirt
      canvas.save();
      canvas.translate(transform.position.dx, transform.position.dy);
      canvas.rotate(transform.rotation);
      canvas.scale(transform.scale, transform.scale);

      canvas.drawImageRect(
        activeImage,
        ui.Rect.fromLTWH(0, 0, activeImage.width.toDouble(), activeImage.height.toDouble()),
        ui.Rect.fromCenter(
          center: ui.Offset.zero,
          width: transform.size.width,
          height: transform.size.height,
        ),
        paint,
      );

      canvas.restore();

      final picture = recorder.endRecording();
      final image = await picture.toImage(
        _screenSize.width.toInt(),
        _screenSize.height.toInt(),
      );

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      if (kDebugMode) {
        print('Error capturing AR snapshot: $e');
      }
      return null;
    }
  }

  void toggleFlash() {
    if (!_isInitialized || _cameraController == null) return;

    final isFlashOn = _cameraController!.value.flashMode == FlashMode.torch;
    _cameraController!.setFlashMode(
      isFlashOn ? FlashMode.off : FlashMode.torch,
    );
  }

  Future<void> stop() async {
    try {
      if (_cameraController != null) {
        await _cameraController!.stopImageStream();
        await _cameraController!.dispose();
        _cameraController = null;
      }

      await _poseDetector.close();
      await _imageCacheService.dispose();

      await _poseStreamController.close();
      await _arOverlayController.close();
      await _performanceStreamController.close();

      _isInitialized = false;

      if (kDebugMode) {
        print('AR Service stopped');
        print('Final Stats:');
        print('  Total Frames: $_processedFrames');
        print('  Successful: $_successfulFrames');
        print('  Failed: $_failedFrames');
        print('  Success Rate: ${successRate.toStringAsFixed(1)}%');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping AR Service: $e');
      }
    }
  }
}

class ShirtTransform {
  final ui.Offset position;
  final ui.Size size;
  final double rotation;
  final double scale;

  ShirtTransform({
    required this.position,
    required this.size,
    required this.rotation,
    required this.scale,
  });
}