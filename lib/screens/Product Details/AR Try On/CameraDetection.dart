import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../models/productModel.dart';
import 'GarmentOverlay.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDER — all mutable state lives here, no setState leaks possible
// ═══════════════════════════════════════════════════════════════════════════════
class ARTryOnProvider extends ChangeNotifier {
  // ── Camera ──────────────────────────────────────────────────────────────────
  CameraController? controller;
  bool cameraReady = false;

  // ── Pose / Garment overlays ──────────────────────────────────────────────────
  CustomPaint? posePaint;
  CustomPaint? garmentPaint;
  String statusText = 'Point camera at yourself';

  // ── Garment state ────────────────────────────────────────────────────────────
  ClothingProductModel? selectedProduct;
  ui.Image? frontImage;
  ui.Image? backImage;
  bool isLoadingGarment = false;
  GarmentView activeView = GarmentView.front;
  GarmentWarpConfig warpConfig = const GarmentWarpConfig();

  // ── UI state ─────────────────────────────────────────────────────────────────
  bool showSkeleton = false;
  bool isSheetOpen = false;
  bool isCapturing = false;

  ui.Image? get activeImage =>
      activeView == GarmentView.front ? frontImage : backImage;

  void toggleSkeleton() {
    showSkeleton = !showSkeleton;
    notifyListeners();
  }

  void toggleSheet() {
    isSheetOpen = !isSheetOpen;
    notifyListeners();
  }

  void openSheet() {
    isSheetOpen = true;
    notifyListeners();
  }

  void closeSheet() {
    isSheetOpen = false;
    notifyListeners();
  }

  void setCapturing(bool v) {
    isCapturing = v;
    notifyListeners();
  }

  void setOverlays({CustomPaint? pose, CustomPaint? garment, String? text}) {
    posePaint = pose;
    garmentPaint = garment;
    if (text != null) statusText = text;
    notifyListeners();
  }

  void clearOverlays(String text) {
    posePaint = null;
    garmentPaint = null;
    statusText = text;
    notifyListeners();
  }

  void setCameraReady(CameraController c) {
    controller = c;
    cameraReady = true;
    notifyListeners();
  }

  void resetGarment() {
    selectedProduct = null;
    frontImage = null;
    backImage = null;
    garmentPaint = null;
    isLoadingGarment = false;
    activeView = GarmentView.front;
    notifyListeners();
  }

  void setLoadingGarment(bool v) {
    isLoadingGarment = v;
    notifyListeners();
  }

  void setGarmentImages({
    ClothingProductModel? product,
    ui.Image? front,
    ui.Image? back,
  }) {
    if (product != null) selectedProduct = product;
    if (front != null) frontImage = front;
    if (back != null) backImage = back;
    isLoadingGarment = false;
    notifyListeners();
  }

  void setActiveView(GarmentView v) {
    activeView = v;
    notifyListeners();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN — thin widget, all logic delegated
// ═══════════════════════════════════════════════════════════════════════════════
class PoseDetectorScreen extends StatelessWidget {
  final String gender;
  final String category;
  final List<ClothingProductModel> products;

  const PoseDetectorScreen({
    Key? key,
    required this.gender,
    required this.category,
    this.products = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ARTryOnProvider(),
      child: _ARTryOnBody(
        gender: gender,
        category: category,
        products: products,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BODY — statefull only for init/dispose of camera + detector
// ═══════════════════════════════════════════════════════════════════════════════
class _ARTryOnBody extends StatefulWidget {
  final String gender;
  final String category;
  final List<ClothingProductModel> products;

  const _ARTryOnBody({
    required this.gender,
    required this.category,
    required this.products,
  });

  @override
  State<_ARTryOnBody> createState() => _ARTryOnBodyState();
}

class _ARTryOnBodyState extends State<_ARTryOnBody>
    with TickerProviderStateMixin {
  // ── Detector (owns its lifecycle, never touches setState) ─────────────────
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    ),
  );

  // ── Frame processing guards ───────────────────────────────────────────────
  bool _isBusy = false;
  int _noPoseFrameCount = 0;
  static const int _noPoseFrameLimit = 6;
  static const double _confidenceThreshold = 0.75;
  static const int _bufferSize = 4;
  final Map<PoseLandmarkType, List<PoseLandmark>> _landmarkBuffers = {};
  late Set<PoseLandmarkType> _allowedLandmarks;

  // ── Animations (UI only) ──────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _sheetCtrl;
  late Animation<double> _sheetAnim;
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();
    _initAllowedLandmarks();
    _initAnimations();
    // defer camera init so provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCamera();
      if (widget.products.isNotEmpty) _preload();
    });
  }

  void _initAnimations() {
    _pulseCtrl =
    AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _sheetCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _sheetAnim =
        CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOutCubic);

    _flipCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _flipAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut));
  }

  void _initAllowedLandmarks() {
    final cat = widget.category.toLowerCase();
    if (cat.contains('t-shirt') ||
        cat.contains('hoodie') ||
        cat.contains('top') ||
        cat.contains('shirt') ||
        cat.contains('jacket')) {
      _allowedLandmarks = {
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.leftWrist,
        PoseLandmarkType.rightWrist,
        PoseLandmarkType.leftHip,
        PoseLandmarkType.rightHip,
      };
    } else if (cat.contains('pant') ||
        cat.contains('trouser') ||
        cat.contains('jean')) {
      _allowedLandmarks = {
        PoseLandmarkType.leftHip,
        PoseLandmarkType.rightHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.leftAnkle,
        PoseLandmarkType.rightAnkle,
      };
    } else {
      _allowedLandmarks = Set.from(PoseLandmarkType.values);
    }
  }

  void _preload() {
    for (final p in widget.products.take(3)) {
      if (p.front.isNotEmpty) GarmentLoader.load(p.front);
      if (p.back.isNotEmpty) GarmentLoader.load(p.back);
    }
  }

  // ── Camera init — FRONT only ───────────────────────────────────────────────
  Future<void> _initCamera() async {
    if (!mounted) return;
    final provider = context.read<ARTryOnProvider>();

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Front camera only
      final frontCam = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final ctrl = CameraController(
        frontCam,
        ResolutionPreset.medium, // medium = faster processing, less memory
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      provider.setCameraReady(ctrl);
      ctrl.startImageStream(_processFrame);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _sheetCtrl.dispose();
    _flipCtrl.dispose();
    // Camera stream stop karo pehle, phir detector close
    final ctrl = context.read<ARTryOnProvider>().controller;
    ctrl?.stopImageStream().then((_) {
      ctrl.dispose();
      _poseDetector.close();
    }).catchError((_) {
      _poseDetector.close();
    });
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // FRAME PROCESSING — tight, no leaks
  // ═════════════════════════════════════════════════════════════════════════
  Future<void> _processFrame(CameraImage image) async {
    // Guard: busy ya widget disposed
    if (_isBusy || !mounted) return;
    _isBusy = true;

    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector.processImage(inputImage);

      // mounted check after async gap
      if (!mounted) return;

      if (poses.isEmpty) {
        _handleNoPose();
        return;
      }

      final smoothed = _smoothPose(poses.first);
      if (smoothed == null) {
        _handleNoPose();
        return;
      }

      _noPoseFrameCount = 0;

      final bool rotated =
          inputImage.metadata!.rotation == InputImageRotation.rotation90deg ||
              inputImage.metadata!.rotation ==
                  InputImageRotation.rotation270deg;
      final imgSize = (!Platform.isIOS && rotated)
          ? Size(image.height.toDouble(), image.width.toDouble())
          : Size(image.width.toDouble(), image.height.toDouble());

      final skeletonPainter = ExpertPosePainter(
        [smoothed],
        imgSize,
        inputImage.metadata!.rotation,
        CameraLensDirection.front, // always front
      );

      CustomPaint? garmentOverlay;
      // Safe read — provider might be disposing
      if (mounted) {
        final activeImg = context.read<ARTryOnProvider>().activeImage;
        if (activeImg != null) {
          garmentOverlay = CustomPaint(
            painter: GarmentOverlayPainter(
              poses: [smoothed],
              garmentImage: activeImg,
              imageSize: imgSize,
              rotation: inputImage.metadata!.rotation,
              cameraLensDirection: CameraLensDirection.front,
              config: context.read<ARTryOnProvider>().warpConfig,
            ),
          );
        }
      }

      if (mounted) {
        context.read<ARTryOnProvider>().setOverlays(
          pose: CustomPaint(painter: skeletonPainter),
          garment: garmentOverlay,
          text: '${smoothed.landmarks.length} pts',
        );
      }
    } catch (e) {
      debugPrint('Frame processing error: $e');
    } finally {
      _isBusy = false;
    }
  }

  Pose? _smoothPose(Pose raw) {
    final newLandmarks = <PoseLandmarkType, PoseLandmark>{};
    bool hasHighConf = false;

    for (var type in _allowedLandmarks) {
      final lm = raw.landmarks[type];
      if (lm == null || lm.likelihood <= _confidenceThreshold) continue;
      hasHighConf = true;

      final buf = _landmarkBuffers.putIfAbsent(type, () => []);
      buf.add(lm);
      if (buf.length > _bufferSize) buf.removeAt(0);

      double ax = 0, ay = 0, az = 0, al = 0;
      for (final b in buf) {
        ax += b.x;
        ay += b.y;
        az += b.z;
        al += b.likelihood;
      }
      final n = buf.length;
      newLandmarks[type] = PoseLandmark(
        type: type,
        x: ax / n,
        y: ay / n,
        z: az / n,
        likelihood: al / n,
      );
    }

    if (!hasHighConf || newLandmarks.length < 3) return null;
    return Pose(landmarks: newLandmarks);
  }

  void _handleNoPose() {
    _noPoseFrameCount++;
    if (_noPoseFrameCount >= _noPoseFrameLimit) {
      _landmarkBuffers.clear();
      _noPoseFrameCount = 0;
      if (mounted) {
        context.read<ARTryOnProvider>().clearOverlays('No person detected');
      }
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final ctrl = context.read<ARTryOnProvider>().controller;
    if (ctrl == null) return null;

    // front camera sensor orientation
    const sensorOrientation = 270; // typical front cam
    final rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation) ??
            InputImageRotation.rotation270deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;

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

  // ═════════════════════════════════════════════════════════════════════════
  // GARMENT SELECTION
  // ═════════════════════════════════════════════════════════════════════════
  Future<void> _selectProduct(ClothingProductModel product) async {
    final provider = context.read<ARTryOnProvider>();
    provider.closeSheet();
    _sheetCtrl.reverse();

    if (provider.selectedProduct?.id == product.id) return;

    provider
      ..selectedProduct = product
      ..frontImage = null
      ..backImage = null
      ..garmentPaint = null
      ..activeView = GarmentView.front
      ..isLoadingGarment = true;
    provider.notifyListeners();

    // Front first — show ASAP
    final front = await GarmentLoader.load(product.front);
    if (!mounted) return;
    provider.setGarmentImages(front: front);

    // Back in background
    final back = await GarmentLoader.load(product.back);
    if (!mounted) return;
    provider.setGarmentImages(back: back);
  }

  void _toggleView() {
    final provider = context.read<ARTryOnProvider>();
    if (provider.selectedProduct == null) return;
    if (provider.activeView == GarmentView.front &&
        provider.backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Back image loading...'),
        duration: Duration(seconds: 1),
      ));
      return;
    }
    _flipCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      final p = context.read<ARTryOnProvider>();
      p.setActiveView(
        p.activeView == GarmentView.front ? GarmentView.back : GarmentView.front,
      );
    });
  }

  // ═════════════════════════════════════════════════════════════════════════
  // CAPTURE
  // ═════════════════════════════════════════════════════════════════════════
  Future<void> _capturePhoto() async {
    final provider = context.read<ARTryOnProvider>();
    if (provider.controller == null ||
        !provider.controller!.value.isInitialized ||
        provider.isCapturing) return;

    provider.setCapturing(true);
    try {
      final file = await provider.controller!.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final drawn = await _drawOnImage(bytes);
      if (mounted) _showPreviewDialog(drawn);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Capture failed: $e')));
      }
    } finally {
      if (mounted) provider.setCapturing(false);
    }
  }

  Future<Uint8List> _drawOnImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final bgImage = frame.image;
    final imgSize =
    Size(bgImage.width.toDouble(), bgImage.height.toDouble());

    final recorder = ui.PictureRecorder();
    final canvas =
    Canvas(recorder, Rect.fromLTWH(0, 0, imgSize.width, imgSize.height));
    canvas.drawImage(bgImage, Offset.zero, Paint());

    // Write temp file for pose detection
    final dir = await Directory.systemTemp.createTemp('ar_');
    final tmp = File('${dir.path}/img.jpg');
    await tmp.writeAsBytes(bytes);

    final poses =
    await _poseDetector.processImage(InputImage.fromFilePath(tmp.path));
    await tmp.delete();

    if (!mounted) {
      final pic = recorder.endRecording();
      final img = await pic.toImage(imgSize.width.toInt(), imgSize.height.toInt());
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      return png!.buffer.asUint8List();
    }

    final provider = context.read<ARTryOnProvider>();
    final activeImg = provider.activeImage;

    if (activeImg != null && poses.isNotEmpty) {
      GarmentOverlayPainter(
        poses: poses,
        garmentImage: activeImg,
        imageSize: imgSize,
        rotation: InputImageRotation.rotation0deg,
        cameraLensDirection: CameraLensDirection.front,
        config: provider.warpConfig,
      ).paint(canvas, imgSize);
    }

    if (provider.showSkeleton && poses.isNotEmpty) {
      ExpertPosePainter(
        poses,
        imgSize,
        InputImageRotation.rotation0deg,
        CameraLensDirection.front,
      ).paint(canvas, imgSize);
    }

    final pic = recorder.endRecording();
    final img =
    await pic.toImage(imgSize.width.toInt(), imgSize.height.toInt());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        // ── Camera preview ──────────────────────────────────────────────────
        Consumer<ARTryOnProvider>(builder: (_, p, __) {
          if (!p.cameraReady || p.controller == null) return _buildLoading();
          final size = MediaQuery.of(context).size;
          var scale = size.aspectRatio * p.controller!.value.aspectRatio;
          if (scale < 1) scale = 1 / scale;
          // Mirror for front camera
          return Transform.scale(
            scaleX: -1,
            child: Transform.scale(
              scale: scale,
              child: Center(child: CameraPreview(p.controller!)),
            ),
          );
        }),

        // ── Garment overlay ─────────────────────────────────────────────────
        Consumer<ARTryOnProvider>(builder: (_, p, __) {
          if (p.garmentPaint == null) return const SizedBox.shrink();
          return Positioned.fill(child: p.garmentPaint!);
        }),

        // ── Skeleton overlay ────────────────────────────────────────────────
        Consumer<ARTryOnProvider>(builder: (_, p, __) {
          if (!p.showSkeleton || p.posePaint == null) {
            return const SizedBox.shrink();
          }
          return Positioned.fill(child: p.posePaint!);
        }),

        // ── Garment loading spinner ─────────────────────────────────────────
        Consumer<ARTryOnProvider>(builder: (_, p, __) {
          if (!p.isLoadingGarment) return const SizedBox.shrink();
          return Container(
            color: Colors.black38,
            child: const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(
                    color: Color(0xFF6C63FF), strokeWidth: 2.5),
                SizedBox(height: 10),
                Text('Loading garment...',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
          );
        }),

        // ── Top bar ─────────────────────────────────────────────────────────
        _buildTopBar(),

        // ── Bottom controls / sheet ─────────────────────────────────────────
        Consumer<ARTryOnProvider>(builder: (_, p, __) {
          if (p.isSheetOpen) {
            return _buildGarmentSheet();
          }
          return Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomControls(),
          );
        }),
      ]),
    );
  }

  Widget _buildLoading() => Container(
    color: const Color(0xFF0A0A1A),
    child: const Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(
            color: Color(0xFF6C63FF), strokeWidth: 2.5),
        SizedBox(height: 16),
        Text('Initialising camera...',
            style: TextStyle(color: Color(0xFF9090B0), fontSize: 14)),
      ]),
    ),
  );

  // ── Top Bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 20,
        ),
        child: Consumer<ARTryOnProvider>(builder: (_, p, __) {
          return Row(children: [
            _iconBtn(
              Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.category,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.gender,
                    style: const TextStyle(
                        color: Color(0xFF6C63FF), fontSize: 12),
                  ),
                ],
              ),
            ),
            _iconBtn(
              Icons.accessibility_new_rounded,
              active: p.showSkeleton,
              onTap: () => p.toggleSkeleton(),
            ),
          ]);
        }),
      ),
    );
  }

  Widget _iconBtn(
      IconData icon, {
        bool active = false,
        Color activeColor = const Color(0xFF6C63FF),
        required VoidCallback onTap,
      }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: active
                ? activeColor.withOpacity(0.25)
                : Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? activeColor.withOpacity(0.6)
                  : Colors.white.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Icon(icon,
              color: active ? activeColor : Colors.white, size: 20),
        ),
      );

  // ── Bottom Controls ────────────────────────────────────────────────────────
  Widget _buildBottomControls() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xF0000000), Colors.transparent],
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).padding.bottom + 28,
        top: 20,
      ),
      child: Consumer<ARTryOnProvider>(builder: (_, p, __) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p.selectedProduct != null) ...[
              _buildProductChip(p),
              const SizedBox(height: 14),
            ],
            _buildStatusPill(p),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Skeleton toggle shortcut
                _ControlButton(
                  icon: Icons.accessibility_new_rounded,
                  label: 'Skeleton',
                  active: p.showSkeleton,
                  onTap: p.toggleSkeleton,
                ),

                // Capture button
                ScaleTransition(
                  scale: _pulseAnim,
                  child: GestureDetector(
                    onTap: _capturePhoto,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF6C63FF), Color(0xFFE040FB)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: p.isCapturing
                          ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                          : const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 30),
                    ),
                  ),
                ),

                // Garments sheet
                _ControlButton(
                  icon: Icons.checkroom_rounded,
                  label: 'Outfits',
                  onTap: () {
                    p.openSheet();
                    _sheetCtrl.forward();
                  },
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _buildProductChip(ARTryOnProvider p) {
    final isFront = p.activeView == GarmentView.front;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        // Product info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withOpacity(0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: const Color(0xFF6C63FF).withOpacity(0.4), width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.checkroom_rounded,
                color: Color(0xFF6C63FF), size: 15),
            const SizedBox(width: 7),
            Text(
              p.selectedProduct!.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 6),
            Text(
              p.selectedProduct!.discount > 0
                  ? 'Rs ${(p.selectedProduct!.price * (1 - p.selectedProduct!.discount / 100)).toInt()}'
                  : 'Rs ${p.selectedProduct!.price}',
              style: const TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: p.resetGarment,
              child: const Icon(Icons.close_rounded,
                  color: Color(0xFF9090B0), size: 15),
            ),
          ]),
        ),

        // Front / Back toggle
        AnimatedBuilder(
          animation: _flipAnim,
          builder: (_, child) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_flipAnim.value * 3.14159),
            child: child,
          ),
          child: GestureDetector(
            onTap: _toggleView,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isFront
                      ? [const Color(0xFF6C63FF), const Color(0xFFE040FB)]
                      : [const Color(0xFF7B2FFF), const Color(0xFFBB6BFF)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.35),
                    blurRadius: 8,
                  )
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (p.activeView == GarmentView.front &&
                    p.backImage == null)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: Colors.white70),
                  )
                else
                  Icon(
                    isFront
                        ? Icons.flip_to_front_rounded
                        : Icons.flip_to_back_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                const SizedBox(width: 6),
                Text(
                  isFront ? 'Front' : 'Back',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPill(ARTryOnProvider p) {
    final detected = p.posePaint != null;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(p.statusText),
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: detected
              ? const Color(0xFF6C63FF).withOpacity(0.18)
              : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: detected
                ? const Color(0xFF6C63FF).withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: detected
                  ? const Color(0xFF00FF88)
                  : const Color(0xFFFF6B6B),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            p.statusText,
            style: TextStyle(
              color: detected ? Colors.white : const Color(0xFFAAAAAA),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]),
      ),
    );
  }

  // ── Garment Sheet ──────────────────────────────────────────────────────────
  Widget _buildGarmentSheet() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          _sheetCtrl.reverse().then((_) {
            if (mounted) context.read<ARTryOnProvider>().closeSheet();
          });
        },
        child: Container(
          color: Colors.black54,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {}, // prevent close on sheet tap
              child: SizeTransition(
                sizeFactor: _sheetAnim,
                axisAlignment: -1,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F0F1A),
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(
                        top: BorderSide(
                            color: Color(0xFF2A2A3A), width: 1)),
                  ),
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        child: Row(children: [
                          Icon(Icons.checkroom_rounded,
                              color: Color(0xFF6C63FF), size: 20),
                          SizedBox(width: 10),
                          Text('Select Outfit',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18)),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      widget.products.isEmpty
                          ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No products available',
                            style:
                            TextStyle(color: Colors.white38)),
                      )
                          : SizedBox(
                        height: 230,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.products.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(width: 12),
                          itemBuilder: (_, i) =>
                              _buildProductCard(widget.products[i]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(ClothingProductModel product) {
    return Consumer<ARTryOnProvider>(builder: (_, p, __) {
      final isSelected = p.selectedProduct?.id == product.id;
      final thumbnail =
      product.images.isNotEmpty ? product.images.first : product.front;

      return GestureDetector(
        onTap: () => _selectProduct(product),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 140,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6C63FF)
                  : const Color(0xFF2A2A3A),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                  blurRadius: 12)
            ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(15)),
                child: thumbnail.isNotEmpty
                    ? Image.network(
                  thumbnail,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imgPlaceholder(),
                  loadingBuilder: (_, child, progress) =>
                  progress == null ? child : _imgLoading(),
                )
                    : _imgPlaceholder(),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Text(product.category,
                            style: const TextStyle(
                                color: Color(0xFF888888), fontSize: 10)),
                        Text(
                          product.discount > 0
                              ? 'Rs ${(product.price * (1 - product.discount / 100)).toInt()}'
                              : 'Rs ${product.price}',
                          style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    if (GarmentLoader.isCached(product.front))
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Row(children: [
                          Icon(Icons.check_circle_rounded,
                              color: Color(0xFF00FF88), size: 10),
                          SizedBox(width: 4),
                          Text('Ready',
                              style: TextStyle(
                                  color: Color(0xFF00FF88),
                                  fontSize: 10)),
                        ]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _imgPlaceholder() => Container(
    height: 140,
    color: const Color(0xFF1A1A2A),
    child: const Icon(Icons.checkroom_rounded,
        color: Colors.white24, size: 36),
  );

  Widget _imgLoading() => Container(
    height: 140,
    color: const Color(0xFF111120),
    child: const Center(
      child: CircularProgressIndicator(
          color: Color(0xFF6C63FF), strokeWidth: 2),
    ),
  );

  // ── Preview Dialog ─────────────────────────────────────────────────────────
  void _showPreviewDialog(Uint8List imageBytes) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            color: const Color(0xFF0F0F1A),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF2A1A3E)],
                  ),
                ),
                child: const Row(children: [
                  Icon(Icons.photo_camera_rounded,
                      color: Color(0xFF6C63FF), size: 22),
                  SizedBox(width: 10),
                  Text('Captured Look',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 17)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(imageBytes),
                ),
              ),
              Padding(
                padding:
                const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(
                              color: Color(0xFF2A2A3A)),
                        ),
                      ),
                      child: const Text('Discard',
                          style: TextStyle(
                              color: Color(0xFF9090B0))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_alt_rounded,
                          size: 18),
                      label: const Text('Save to Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(10)),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                      onPressed: () async {
                        var status =
                        await Permission.photos.request();
                        if (!status.isGranted) {
                          if (status.isPermanentlyDenied)
                            openAppSettings();
                          if (mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Text(
                                  'Photos permission denied'),
                            ));
                          }
                          Navigator.pop(ctx);
                          return;
                        }
                        final result =
                        await ImageGallerySaverPlus.saveImage(
                            imageBytes);
                        final ok = result != null &&
                            result is String &&
                            result.isNotEmpty;
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: Text(
                                ok ? '✅ Saved!' : '❌ Failed to save'),
                            backgroundColor: ok
                                ? const Color(0xFF6C63FF)
                                : const Color(0xFFE53935),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12)),
                          ));
                        }
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _ControlButton
// ═══════════════════════════════════════════════════════════════════════════════
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? const Color(0xFF6C63FF).withOpacity(0.25)
                : Colors.white.withOpacity(0.12),
            border: Border.all(
              color: active
                  ? const Color(0xFF6C63FF).withOpacity(0.6)
                  : Colors.white.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Icon(icon,
              color: active ? const Color(0xFF6C63FF) : Colors.white,
              size: 24),
        ),
        const SizedBox(height: 6),
        Text(label,
            style:
            const TextStyle(color: Color(0xAAFFFFFF), fontSize: 11)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ExpertPosePainter — unchanged logic, only color updated to match theme
// ═══════════════════════════════════════════════════════════════════════════════
class ExpertPosePainter extends CustomPainter {
  ExpertPosePainter(
      this.poses,
      this.imageSize,
      this.rotation,
      this.cameraLensDirection,
      );

  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;

  static const double _confidenceThreshold = 0.75;

  static const List<List<PoseLandmarkType>> _connections = [
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    [PoseLandmarkType.leftWrist, PoseLandmarkType.leftPinky],
    [PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex],
    [PoseLandmarkType.leftPinky, PoseLandmarkType.leftIndex],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    [PoseLandmarkType.rightWrist, PoseLandmarkType.rightPinky],
    [PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex],
    [PoseLandmarkType.rightWrist, PoseLandmarkType.rightThumb],
    [PoseLandmarkType.rightPinky, PoseLandmarkType.rightIndex],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
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

  @override
  void paint(Canvas canvas, Size size) {
    for (final pose in poses) {
      for (final conn in _connections) {
        final lm1 = pose.landmarks[conn[0]];
        final lm2 = pose.landmarks[conn[1]];
        if (lm1 == null ||
            lm2 == null ||
            lm1.likelihood <= _confidenceThreshold ||
            lm2.likelihood <= _confidenceThreshold) continue;

        final p1 = Offset(_tx(lm1.x, size), _ty(lm1.y, size));
        final p2 = Offset(_tx(lm2.x, size), _ty(lm2.y, size));

        // Glow layer
        canvas.drawLine(
            p1,
            p2,
            Paint()
              ..shader = ui.Gradient.linear(p1, p2, [
                const Color(0xFF6C63FF).withOpacity(0.2),
                const Color(0xFFE040FB).withOpacity(0.2),
              ])
              ..style = PaintingStyle.stroke
              ..strokeWidth = 9.0
              ..strokeCap = StrokeCap.round
              ..isAntiAlias = true);

        // Line
        canvas.drawLine(
            p1,
            p2,
            Paint()
              ..shader = ui.Gradient.linear(p1, p2, [
                const Color(0xFF6C63FF),
                const Color(0xFFE040FB),
              ])
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.0
              ..strokeCap = StrokeCap.round
              ..isAntiAlias = true);
      }

      pose.landmarks.forEach((type, lm) {
        if (lm.likelihood <= _confidenceThreshold) return;
        final c = Offset(_tx(lm.x, size), _ty(lm.y, size));
        final o = lm.likelihood.clamp(0.0, 1.0);

        canvas.drawCircle(
            c,
            9,
            Paint()
              ..color = const Color(0xFF6C63FF).withOpacity(o * 0.3)
              ..isAntiAlias = true);
        canvas.drawCircle(
            c,
            6,
            Paint()
              ..color = Colors.white.withOpacity(o * 0.9)
              ..isAntiAlias = true);
        canvas.drawCircle(
            c,
            4,
            Paint()
              ..color = Color.lerp(
                  const Color(0xFF6C63FF),
                  const Color(0xFF00FF88),
                  ((lm.likelihood - _confidenceThreshold) /
                      (1.0 - _confidenceThreshold))
                      .clamp(0.0, 1.0))!
                  .withOpacity(o)
              ..isAntiAlias = true);
      });
    }
  }

  double _tx(double x, Size cs) {
    // Front camera: always mirror
    x = imageSize.width - x;
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return x * cs.width / (Platform.isIOS ? imageSize.width : imageSize.height);
      case InputImageRotation.rotation270deg:
        return cs.width -
            x * cs.width / (Platform.isIOS ? imageSize.width : imageSize.height);
      default:
        return x * cs.width / imageSize.width;
    }
  }

  double _ty(double y, Size cs) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * cs.height / (Platform.isIOS ? imageSize.height : imageSize.width);
      default:
        return y * cs.height / imageSize.height;
    }
  }

  @override
  bool shouldRepaint(covariant ExpertPosePainter old) =>
      old.imageSize != imageSize || old.poses != poses;
}