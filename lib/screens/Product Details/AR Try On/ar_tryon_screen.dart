import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'ar_overlay_painter.dart';
import 'pose_mapper.dart';

enum ClothingCategory { tshirt, hoodie, pant }

class ARTryOnScreen extends StatefulWidget {
  final String frontImagePath;
  final String backImagePath;
  final ClothingCategory category;

  const ARTryOnScreen({
    Key? key,
    required this.frontImagePath,
    required this.backImagePath,
    required this.category,
  }) : super(key: key);

  @override
  State<ARTryOnScreen> createState() => _ARTryOnScreenState();
}

class _ARTryOnScreenState extends State<ARTryOnScreen> {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  Size _imageSize = Size.zero;
  ui.Image? _clothingImage;
  bool _isFrontCamera = false;
  double _clothingAspectRatio = 1.0;

  final _repaintNotifier = ValueNotifier<int>(0);
  List<Pose> _latestPoses = [];
  Rect? _smoothedRect;
  bool _poseDetected = false;

  // Skeleton toggle
  bool _showSkeleton = false;

  Size _renderSize = Size.zero;

  // Slower smoothing = stabler overlay
  static const double _alpha = 0.15;

  // Dead zone: if rect edges moved less than this many pixels, skip lerp
  static const double _deadZone = 4.0;

  int _frameCount = 0;
  // Process every 4th frame (skip=3) — faster than every 3rd
  static const int _skipFrames = 3;

  @override
  void initState() {
    super.initState();
    _loadClothingImage();
    _initPoseDetector();
    _initCamera();
  }

  Future<void> _loadClothingImage() async {
    final bytes = await File(widget.frontImagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _clothingImage = frame.image;
        _clothingAspectRatio = frame.image.width / frame.image.height;
      });
    }
  }

  void _initPoseDetector() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ),
    );
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final cam = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _isFrontCamera = cam.lensDirection == CameraLensDirection.front;

    _cameraController = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _cameraController!.initialize();
    if (!mounted) return;
    setState(() => _isCameraInitialized = true);
    _cameraController!.startImageStream(_onCameraFrame);
  }

  void _onCameraFrame(CameraImage image) {
    _frameCount++;
    if (_frameCount % (_skipFrames + 1) != 0) return;
    if (_isProcessing) return;
    _isProcessing = true;
    _processFrame(image);
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;

      final sensorOrientation =
          _cameraController!.description.sensorOrientation;
      final swapDims = sensorOrientation == 90 || sensorOrientation == 270;
      _imageSize = swapDims
          ? Size(image.height.toDouble(), image.width.toDouble())
          : Size(image.width.toDouble(), image.height.toDouble());

      final poses = await _poseDetector!.processImage(inputImage);
      _latestPoses = poses;

      bool goodPose = false;
      if (poses.isNotEmpty) {
        final p = poses.first;
        final ls = p.landmarks[PoseLandmarkType.leftShoulder];
        final rs = p.landmarks[PoseLandmarkType.rightShoulder];
        // Raised confidence threshold: 0.65 instead of 0.55
        // Lower-confidence detections cause jitter — better to skip
        goodPose = ls != null &&
            rs != null &&
            ls.likelihood > 0.65 &&
            rs.likelihood > 0.65;
      }
      _poseDetected = goodPose;

      if (goodPose && _imageSize != Size.zero && _renderSize != Size.zero) {
        final raw = widget.category == ClothingCategory.pant
            ? PoseMapper.getBottomClothingRect(
          pose: poses.first,
          imageSize: _imageSize,
          previewSize: _renderSize,
          flipX: _isFrontCamera,
        )
            : PoseMapper.getTopClothingRect(
          pose: poses.first,
          imageSize: _imageSize,
          previewSize: _renderSize,
          flipX: _isFrontCamera,
          clothingAspectRatio: _clothingAspectRatio,
        );

        if (raw != null) {
          _smoothedRect = _smoothRect(_smoothedRect, raw);
        }
      }

      _repaintNotifier.value++;
    } catch (e) {
      debugPrint('Frame error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Dead zone: only lerp if edge moved more than [_deadZone] px.
  /// This kills the micro-jitter that makes clothing look "alive" when
  /// the person is standing still.
  Rect _smoothRect(Rect? prev, Rect next) {
    if (prev == null) return next;
    return Rect.fromLTRB(
      _lerpWithDeadZone(prev.left, next.left),
      _lerpWithDeadZone(prev.top, next.top),
      _lerpWithDeadZone(prev.right, next.right),
      _lerpWithDeadZone(prev.bottom, next.bottom),
    );
  }

  double _lerpWithDeadZone(double a, double b) {
    if ((b - a).abs() < _deadZone) return a; // ignore tiny movement
    return a + (b - a) * _alpha;
  }

  InputImage? _buildInputImage(CameraImage image) {
    if (_cameraController == null) return null;
    final cam = _cameraController!.description;
    final rotation =
    InputImageRotationValue.fromRawValue(cam.sensorOrientation);
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
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

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetector?.close();
    _repaintNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Camera shuru ho raha hai...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          _renderSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_cameraController!),

              RepaintBoundary(
                child: ValueListenableBuilder<int>(
                  valueListenable: _repaintNotifier,
                  builder: (_, __, ___) => CustomPaint(
                    painter: AROverlayPainter(
                      poses: _latestPoses,
                      clothingImage: _clothingImage,
                      category: widget.category,
                      imageSize: _imageSize,
                      smoothedRect: _smoothedRect,
                      flipX: _isFrontCamera,
                      showSkeleton: _showSkeleton,
                    ),
                  ),
                ),
              ),

              // Top-right: status chip
              Positioned(
                top: 56,
                right: 16,
                child: ValueListenableBuilder<int>(
                  valueListenable: _repaintNotifier,
                  builder: (_, __, ___) => _buildStatusChip(),
                ),
              ),

              // Top-left: skeleton toggle
              Positioned(
                top: 56,
                left: 16,
                child: _buildSkeletonToggle(),
              ),

              // Bottom: category label
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      widget.category == ClothingCategory.pant
                          ? '👖 Pant mode'
                          : '👕 ${widget.category.name.toUpperCase()} mode',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSkeletonToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showSkeleton = !_showSkeleton),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _showSkeleton
              ? Colors.greenAccent.withOpacity(0.85)
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _showSkeleton
                ? Colors.greenAccent
                : Colors.white38,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.accessibility_new,
              color: _showSkeleton ? Colors.black : Colors.white70,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              'Skeleton',
              style: TextStyle(
                color: _showSkeleton ? Colors.black : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _poseDetected
            ? Colors.green.withOpacity(0.85)
            : Colors.red.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _poseDetected ? Icons.person : Icons.person_off,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            _poseDetected ? 'Detected' : 'Frame mein aao',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}