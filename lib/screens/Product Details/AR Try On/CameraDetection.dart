import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

late List<CameraDescription> _cameras;

class PoseDetectorScreen extends StatefulWidget {
  final String gender;
  final String category;

  const PoseDetectorScreen({
    Key? key,
    required this.gender,
    required this.category,
  }) : super(key: key);

  @override
  State<PoseDetectorScreen> createState() => _PoseDetectorScreenState();
}

class _PoseDetectorScreenState extends State<PoseDetectorScreen> {
  CameraController? _controller;
  int _cameraIndex = 0; // Start with back (0 usually back)
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate, // Use accurate model for better detection and less jitter
    ),
  );
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String _text = 'Detecting pose...';
  CameraLensDirection _cameraLensDirection = CameraLensDirection.back;
  FlashMode _flashMode = FlashMode.off;
  bool _isFrontCamera = false;

  // For smoothing landmarks to reduce bouncing/jitter
  final Map<PoseLandmarkType, List<PoseLandmark>> _landmarkBuffers = {};
  static const int _bufferSize = 5; // Average over last 5 frames
  static const double _confidenceThreshold = 0.8; // Increased threshold for clearer visibility and fewer ghosts/false positives

  late Set<PoseLandmarkType> _allowedLandmarks;

  @override
  void initState() {
    super.initState();
    _initializeAllowedLandmarks();
    _initializeCameras();
    // You can use widget.gender and widget.category here if needed, e.g., for custom logic or display
    _text = 'Detecting ${widget.category} pose for ${widget.gender}...';
  }

  void _initializeAllowedLandmarks() {
    final String cat = widget.category.toLowerCase();
    if (cat.contains('t-shirt') || cat.contains('hoodie')) {
      _allowedLandmarks = {
        PoseLandmarkType.nose,
        PoseLandmarkType.leftEyeInner,
        PoseLandmarkType.leftEye,
        PoseLandmarkType.leftEyeOuter,
        PoseLandmarkType.leftEar,
        PoseLandmarkType.rightEyeInner,
        PoseLandmarkType.rightEye,
        PoseLandmarkType.rightEyeOuter,
        PoseLandmarkType.rightEar,
        PoseLandmarkType.leftMouth,
        PoseLandmarkType.rightMouth,
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.leftWrist,
        PoseLandmarkType.rightWrist,
        PoseLandmarkType.leftPinky,
        PoseLandmarkType.rightPinky,
        PoseLandmarkType.leftIndex,
        PoseLandmarkType.rightIndex,
        PoseLandmarkType.leftThumb,
        PoseLandmarkType.rightThumb,
        PoseLandmarkType.leftHip,
        PoseLandmarkType.rightHip,
      };
    } else if (cat.contains('pant')) {
      _allowedLandmarks = {
        PoseLandmarkType.leftHip,
        PoseLandmarkType.rightHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.leftAnkle,
        PoseLandmarkType.rightAnkle,
        PoseLandmarkType.leftHeel,
        PoseLandmarkType.rightHeel,
        PoseLandmarkType.leftFootIndex,
        PoseLandmarkType.rightFootIndex,
      };
    } else {
      _allowedLandmarks = Set.from(PoseLandmarkType.values);
    }
  }

  Future _initializeCameras() async {
    _cameras = await availableCameras();
    _switchCamera(); // Initializes to back
  }

  Future _switchCamera() async {
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    _cameraLensDirection = _cameras[_cameraIndex].lensDirection;
    _isFrontCamera = _cameraLensDirection == CameraLensDirection.front;
    _flashMode = _isFrontCamera ? FlashMode.off : _flashMode; // Disable flash for front
    await _startLiveFeed();
  }

  Future _toggleFlash() async {
    if (_isFrontCamera) return; // No flash for front
    _flashMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await _controller?.setFlashMode(_flashMode);
    setState(() {});
  }

  Future _startLiveFeed() async {
    if (_controller != null) {
      await _controller?.stopImageStream();
      await _controller?.dispose();
    }
    final camera = _cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high, // Increased to high for better accuracy, may slightly increase lag but reduces jitter
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    await _controller?.initialize();
    await _controller?.setFlashMode(_flashMode);
    _controller?.startImageStream(_processCameraImage);
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  Future _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isBusy = false;
      return;
    }
    final poses = await _poseDetector.processImage(inputImage);
    if (poses.isNotEmpty) {
      // Assume single main pose for simplicity (common in self-camera use)
      final pose = poses.first;

      // Build smoothed landmarks, filtered by allowed
      final newLandmarks = <PoseLandmarkType, PoseLandmark>{};
      bool hasHighConfidenceLandmark = false;

      for (var type in PoseLandmarkType.values) {
        final lm = pose.landmarks[type];
        if (lm != null && lm.likelihood > _confidenceThreshold && _allowedLandmarks.contains(type)) {
          hasHighConfidenceLandmark = true;
          _landmarkBuffers.putIfAbsent(type, () => []);
          _landmarkBuffers[type]!.add(lm);
          if (_landmarkBuffers[type]!.length > _bufferSize) {
            _landmarkBuffers[type]!.removeAt(0);
          }

          // Calculate average
          double avgX = 0, avgY = 0, avgZ = 0, avgLikelihood = 0;
          final buffer = _landmarkBuffers[type]!;
          for (var b in buffer) {
            avgX += b.x;
            avgY += b.y;
            avgZ += b.z;
            avgLikelihood += b.likelihood;
          }
          avgX /= buffer.length;
          avgY /= buffer.length;
          avgZ /= buffer.length;
          avgLikelihood /= buffer.length;

          newLandmarks[type] = PoseLandmark(
            type: type,
            x: avgX,
            y: avgY,
            z: avgZ,
            likelihood: avgLikelihood,
          );
        }
      }

      if (hasHighConfidenceLandmark && newLandmarks.isNotEmpty) {
        final smoothedPose = Pose(landmarks: newLandmarks);
        setState(() {
          _text = 'User visible! Pose detected: ${newLandmarks.length} points';
        });
        final painter = ExpertPosePainter(
          [smoothedPose],
          Size(image.width.toDouble(), image.height.toDouble()),
          inputImage.metadata!.rotation,
          _cameraLensDirection,
        );
        _customPaint = CustomPaint(painter: painter);
      } else {
        _noPose();
      }
    } else {
      _noPose();
    }
    _isBusy = false;
    if (mounted) setState(() {});
  }

  void _noPose() {
    setState(() {
      _text = 'No user visible in camera';
      _customPaint = null;
    });
    _landmarkBuffers.clear(); // Clear buffers when no pose to reset smoothing
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;
    final camera = _cameras[_cameraIndex];
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final XFile file = await _controller!.takePicture();
    final Uint8List imageBytes = await file.readAsBytes();
    // Process poses on captured image
    final inputImage = InputImage.fromFilePath(file.path);
    final poses = await _poseDetector.processImage(inputImage);
    // Filter poses for captured image as well
    final filteredPoses = _filterPoses(poses);
    // Draw poses on image
    final drawnImageBytes = await _drawPosesOnImage(imageBytes, filteredPoses);
    // Show preview dialog
    _showPreviewDialog(drawnImageBytes);
  }

  List<Pose> _filterPoses(List<Pose> poses) {
    return poses.map((pose) {
      final filteredLandmarks = <PoseLandmarkType, PoseLandmark>{};
      pose.landmarks.forEach((type, lm) {
        if (_allowedLandmarks.contains(type) && lm.likelihood > _confidenceThreshold) {
          filteredLandmarks[type] = lm;
        }
      });
      return Pose(landmarks: filteredLandmarks);
    }).toList();
  }

  Future<Uint8List> _drawPosesOnImage(Uint8List imageBytes, List<Pose> poses) async {
    final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image bgImage = frameInfo.image;
    final Size imgSize = Size(bgImage.width.toDouble(), bgImage.height.toDouble());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, imgSize.width, imgSize.height));

    // Draw the background image
    canvas.drawImage(bgImage, Offset.zero, Paint());

    // Draw poses on top
    final painter = ExpertPosePainter(
      poses,
      imgSize,
      InputImageRotation.rotation0deg, // Captured images are typically upright
      _cameraLensDirection,
    );
    painter.paint(canvas, imgSize);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(imgSize.width.toInt(), imgSize.height.toInt());
    final ByteData? pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return pngBytes!.buffer.asUint8List();
  }

  void _showPreviewDialog(Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Captured Photo'),
        content: Image.memory(imageBytes),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Request photos permission for gallery access
              var status = await Permission.photos.request();
              if (!status.isGranted) {
                if (status.isPermanentlyDenied) {
                  openAppSettings();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Photos permission denied')),
                  );
                }
                Navigator.pop(context);
                return;
              }
              // Save to gallery
              final result = await ImageGallerySaverPlus.saveImage(imageBytes);
              final bool success = result != null && (result is String && result.isNotEmpty);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(success ? 'Saved to gallery!' : 'Failed to save')),
              );
              Navigator.pop(context);
            },
            child: Text('Save to Gallery'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return Scaffold(
      appBar: AppBar(title: Text('Expert Pose Detection')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: scale,
            child: Center(
              child: _isFrontCamera
                  ? Transform.scale(scaleX: -1, child: CameraPreview(_controller!)) // Mirror front camera
                  : CameraPreview(_controller!),
            ),
          ),
          if (_customPaint != null) _customPaint!,
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_text, style: TextStyle(color: Colors.white, fontSize: 18)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: _capturePhoto,
                      ),
                      IconButton(
                        icon: Icon(Icons.switch_camera, color: Colors.white),
                        onPressed: _switchCamera,
                      ),
                      IconButton(
                        icon: Icon(_flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on, color: Colors.white),
                        onPressed: _isFrontCamera ? null : _toggleFlash,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ExpertPosePainter: Enhanced with full connections, arrows, gradients, anti-aliasing
class ExpertPosePainter extends CustomPainter {
  ExpertPosePainter(this.poses, this.imageSize, this.rotation, this.cameraLensDirection);

  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.green
      ..isAntiAlias = true; // Smoother

    for (final pose in poses) {
      // Draw dots only if confidence > threshold
      pose.landmarks.forEach((type, landmark) {
        if (landmark.likelihood > _PoseDetectorScreenState._confidenceThreshold) {
          canvas.drawCircle(
            Offset(
              _translateX(landmark.x, size, imageSize),
              _translateY(landmark.y, size, imageSize),
            ),
            6, // Larger dot
            dotPaint..color = Colors.green.withOpacity(landmark.likelihood), // Opacity based on confidence
          );
        }
      });

      // Full skeleton connections with gradients and arrows
      final connections = [
        // Face
        [PoseLandmarkType.nose, PoseLandmarkType.leftEyeInner],
        [PoseLandmarkType.leftEyeInner, PoseLandmarkType.leftEye],
        [PoseLandmarkType.leftEye, PoseLandmarkType.leftEyeOuter],
        [PoseLandmarkType.leftEyeOuter, PoseLandmarkType.leftEar],
        [PoseLandmarkType.nose, PoseLandmarkType.rightEyeInner],
        [PoseLandmarkType.rightEyeInner, PoseLandmarkType.rightEye],
        [PoseLandmarkType.rightEye, PoseLandmarkType.rightEyeOuter],
        [PoseLandmarkType.rightEyeOuter, PoseLandmarkType.rightEar],
        [PoseLandmarkType.leftMouth, PoseLandmarkType.rightMouth],
        // Arms
        [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
        [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
        [PoseLandmarkType.leftWrist, PoseLandmarkType.leftPinky],
        [PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex],
        [PoseLandmarkType.leftWrist, PoseLandmarkType.leftThumb],
        [PoseLandmarkType.leftPinky, PoseLandmarkType.leftIndex],
        [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
        [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
        [PoseLandmarkType.rightWrist, PoseLandmarkType.rightPinky],
        [PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex],
        [PoseLandmarkType.rightWrist, PoseLandmarkType.rightThumb],
        [PoseLandmarkType.rightPinky, PoseLandmarkType.rightIndex],
        // Body
        [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
        [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
        [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
        [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
        // Legs
        [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
        [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
        [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel],
        [PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex],
        [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex],
        [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
        [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
        [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel],
        [PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex],
        [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex],
      ];

      for (final conn in connections) {
        final type1 = conn[0];
        final type2 = conn[1];
        final lm1 = pose.landmarks[type1];
        final lm2 = pose.landmarks[type2];
        if (lm1 != null &&
            lm2 != null &&
            lm1.likelihood > _PoseDetectorScreenState._confidenceThreshold &&
            lm2.likelihood > _PoseDetectorScreenState._confidenceThreshold) {
          final p1 = Offset(_translateX(lm1.x, size, imageSize), _translateY(lm1.y, size, imageSize));
          final p2 = Offset(_translateX(lm2.x, size, imageSize), _translateY(lm2.y, size, imageSize));
          // Gradient paint
          final gradientPaint = Paint()
            ..shader = ui.Gradient.linear(p1, p2, [Colors.yellow, Colors.blue])
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0
            ..isAntiAlias = true;
          canvas.drawLine(p1, p2, gradientPaint);
          // Draw arrow at end (towards p2)
          final arrowPaint = Paint()
            ..color = Colors.red
            ..style = PaintingStyle.fill
            ..isAntiAlias = true;
          final dx = p2.dx - p1.dx;
          final dy = p2.dy - p1.dy;
          final angle = math.atan2(dy, dx);
          final arrowSize = 10.0;
          final path = Path()
            ..moveTo(p2.dx - arrowSize * math.cos(angle - math.pi / 6), p2.dy - arrowSize * math.sin(angle - math.pi / 6))
            ..lineTo(p2.dx, p2.dy)
            ..lineTo(p2.dx - arrowSize * math.cos(angle + math.pi / 6), p2.dy - arrowSize * math.sin(angle + math.pi / 6));
          canvas.drawPath(path, arrowPaint);
        }
      }
    }
  }

  double _translateX(double x, Size canvasSize, Size imageSize) {
    if (cameraLensDirection == CameraLensDirection.front) {
      x = imageSize.width - x; // Mirror
    }
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return x * canvasSize.width / (Platform.isIOS ? imageSize.width : imageSize.height);
      case InputImageRotation.rotation270deg:
        return canvasSize.width - x * canvasSize.width / (Platform.isIOS ? imageSize.width : imageSize.height);
      default:
        return x * canvasSize.width / imageSize.width;
    }
  }

  double _translateY(double y, Size canvasSize, Size imageSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * canvasSize.height / (Platform.isIOS ? imageSize.height : imageSize.width);
      default:
        return y * canvasSize.height / imageSize.height;
    }
  }

  @override
  bool shouldRepaint(covariant ExpertPosePainter oldDelegate) {
    return oldDelegate.imageSize != imageSize || oldDelegate.poses != poses;
  }
}