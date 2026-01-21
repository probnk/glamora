import 'dart:async';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../constants/ar_constants.dart';

class PoseDetectionService {
  late PoseDetector _poseDetector;
  bool _isInitialized = false;

  final List<Completer<Pose>> _pendingRequests = [];
  bool _isProcessing = false;
  DateTime? _lastDetectionTime;
  int _consecutiveFailures = 0;

  // Performance tracking
  final List<int> _processingTimes = [];
  double _avgProcessingTime = 0.0;

  PoseDetector initializeDetector() {
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    );

    _poseDetector = PoseDetector(options: options);
    _isInitialized = true;

    return _poseDetector;
  }

  InputImage cameraImageToInputImage(
      CameraImage cameraImage,
      CameraDescription cameraDescription,
      ) {
    final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw);

    if (format == null) {
      throw Exception('Unsupported camera image format');
    }

    final plane = cameraImage.planes.first;
    final inputImageData = InputImageMetadata(
      size: ui.Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
      rotation: _imageRotation(cameraDescription.sensorOrientation),
      format: format,
      bytesPerRow: plane.bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: inputImageData,
    );
  }

  InputImageRotation _imageRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Map<int, Vector2> extractLandmarks(Pose pose) {
    final landmarks = <int, Vector2>{};

    for (final entry in pose.landmarks.entries) {
      final landmark = entry.value;

      if (landmark.likelihood >= ARConstants.minLandmarkConfidence) {
        landmarks[entry.key.index] = Vector2(
          landmark.x,
          landmark.y,
        );
      }
    }

    return landmarks;
  }

  Future<Pose?> detectPose(InputImage inputImage) async {
    if (!_isInitialized) {
      throw Exception('Pose detector not initialized');
    }

    // Throttle detection if processing is too slow
    final now = DateTime.now();
    if (_lastDetectionTime != null) {
      final elapsed = now.difference(_lastDetectionTime!).inMilliseconds;
      if (elapsed < 16 && _consecutiveFailures < 3) { // ~60 FPS max
        return null;
      }
    }

    _lastDetectionTime = now;

    try {
      final startTime = DateTime.now();

      final poses = await _poseDetector.processImage(inputImage);

      final processingTime = DateTime.now().difference(startTime).inMilliseconds;
      _recordProcessingTime(processingTime);

      if (poses.isNotEmpty) {
        _consecutiveFailures = 0;
        return poses.first;
      } else {
        _consecutiveFailures++;
        return null;
      }
    } catch (e) {
      _consecutiveFailures++;

      if (_consecutiveFailures > 5) {
        // Reset detector if too many consecutive failures
        await _poseDetector.close();
        initializeDetector();
        _consecutiveFailures = 0;
      }

      rethrow;
    }
  }

  void _recordProcessingTime(int timeMs) {
    _processingTimes.add(timeMs);

    if (_processingTimes.length > 10) {
      _processingTimes.removeAt(0);
    }

    _avgProcessingTime = _processingTimes.reduce((a, b) => a + b) / _processingTimes.length;

    if (_avgProcessingTime > 50) {
      // Slow processing detected
      if (_consecutiveFailures > 0) {
        _consecutiveFailures = 0; // Reset failures since we're processing
      }
    }
  }

  double get averageProcessingTime => _avgProcessingTime;
  bool get isPerformingWell => _avgProcessingTime < 50 && _consecutiveFailures < 3;

  Future<void> dispose() async {
    if (_isInitialized) {
      await _poseDetector.close();
      _isInitialized = false;
    }
  }
}