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

import '../../../models/productModel.dart';
import 'GarmentOverlay.dart';

late List<CameraDescription> _cameras;

class PoseDetectorScreen extends StatefulWidget {
  final String gender;
  final String category;

  /// ClothingProductModel list — Firebase se aaye hue products
  final List<ClothingProductModel> products;

  const PoseDetectorScreen({
    Key? key,
    required this.gender,
    required this.category,
    this.products = const [],
  }) : super(key: key);

  @override
  State<PoseDetectorScreen> createState() => _PoseDetectorScreenState();
}

class _PoseDetectorScreenState extends State<PoseDetectorScreen>
    with TickerProviderStateMixin {
  // ── Camera ────────────────────────────────────────────────────────────────
  CameraController? _controller;
  int _cameraIndex = 0;
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    ),
  );
  bool _isBusy = false;
  CustomPaint? _posePaint;
  CustomPaint? _garmentPaint;
  String _text = 'Point camera at a person';
  CameraLensDirection _cameraLensDirection = CameraLensDirection.back;
  FlashMode _flashMode = FlashMode.off;
  bool _isFrontCamera  = false;
  bool _isCapturing    = false;
  bool _showSkeleton   = false;

  // ── Pose smoothing ────────────────────────────────────────────────────────
  final Map<PoseLandmarkType, List<PoseLandmark>> _landmarkBuffers = {};
  static const int    _bufferSize          = 5;
  static const double _confidenceThreshold = 0.8;
  int _noPoseFrameCount = 0;
  static const int _noPoseFrameLimit = 5;
  late Set<PoseLandmarkType> _allowedLandmarks;

  // ── Garment state ─────────────────────────────────────────────────────────
  // Selected product — ClothingProductModel directly
  ClothingProductModel? _selectedProduct;

  // Loaded images from cache
  ui.Image? _frontImage;
  ui.Image? _backImage;

  bool _isLoadingGarment = false;
  GarmentView _activeView = GarmentView.front;
  GarmentWarpConfig _warpConfig = const GarmentWarpConfig();

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double>   _pulseAnim;
  late AnimationController _sheetController;
  late Animation<double>   _sheetAnim;
  late AnimationController _flipController;
  late Animation<double>   _flipAnim;
  bool _isSheetOpen = false;

  // ── Active image getter — front ya back jo selected hai ───────────────────
  ui.Image? get _activeImage =>
      _activeView == GarmentView.front ? _frontImage : _backImage;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _sheetController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _sheetAnim = CurvedAnimation(
        parent: _sheetController, curve: Curves.easeOutCubic);

    _flipController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _flipController, curve: Curves.easeInOut));

    _initializeAllowedLandmarks();
    _initializeCameras();

    // Agar products hain toh pehle wala background mein preload kar do
    if (widget.products.isNotEmpty) {
      _preloadVisibleProducts();
    }
  }

  /// Pehle 3 products background mein preload — user scroll kare toh ready hon
  void _preloadVisibleProducts() {
    final toPreload = widget.products.take(3);
    for (final p in toPreload) {
      if (p.front.isNotEmpty) GarmentLoader.load(p.front);
      if (p.back.isNotEmpty)  GarmentLoader.load(p.back);
    }
  }

  void _initializeAllowedLandmarks() {
    final cat = widget.category.toLowerCase();
    if (cat.contains('t-shirt') || cat.contains('hoodie') || cat.contains('top')
        || cat.contains('shirt') || cat.contains('jacket')) {
      _allowedLandmarks = {
        PoseLandmarkType.nose,
        PoseLandmarkType.leftEyeInner,  PoseLandmarkType.leftEye,
        PoseLandmarkType.leftEyeOuter,  PoseLandmarkType.leftEar,
        PoseLandmarkType.rightEyeInner, PoseLandmarkType.rightEye,
        PoseLandmarkType.rightEyeOuter, PoseLandmarkType.rightEar,
        PoseLandmarkType.leftMouth,     PoseLandmarkType.rightMouth,
        PoseLandmarkType.leftShoulder,  PoseLandmarkType.rightShoulder,
        PoseLandmarkType.leftElbow,     PoseLandmarkType.rightElbow,
        PoseLandmarkType.leftWrist,     PoseLandmarkType.rightWrist,
        PoseLandmarkType.leftPinky,     PoseLandmarkType.rightPinky,
        PoseLandmarkType.leftIndex,     PoseLandmarkType.rightIndex,
        PoseLandmarkType.leftThumb,     PoseLandmarkType.rightThumb,
        PoseLandmarkType.leftHip,       PoseLandmarkType.rightHip,
      };
    } else if (cat.contains('pant') || cat.contains('trouser') || cat.contains('jean')) {
      _allowedLandmarks = {
        PoseLandmarkType.leftHip,       PoseLandmarkType.rightHip,
        PoseLandmarkType.leftKnee,      PoseLandmarkType.rightKnee,
        PoseLandmarkType.leftAnkle,     PoseLandmarkType.rightAnkle,
        PoseLandmarkType.leftHeel,      PoseLandmarkType.rightHeel,
        PoseLandmarkType.leftFootIndex, PoseLandmarkType.rightFootIndex,
      };
    } else {
      _allowedLandmarks = Set.from(PoseLandmarkType.values);
    }
  }

  Future<void> _initializeCameras() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    _cameraIndex = 0;
    for (int i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == CameraLensDirection.back) {
        _cameraIndex = i; break;
      }
    }
    _cameraLensDirection = _cameras[_cameraIndex].lensDirection;
    _isFrontCamera = _cameraLensDirection == CameraLensDirection.front;
    await _startLiveFeed();
  }

  Future<void> _switchCamera() async {
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    _cameraLensDirection = _cameras[_cameraIndex].lensDirection;
    _isFrontCamera = _cameraLensDirection == CameraLensDirection.front;
    if (_isFrontCamera) _flashMode = FlashMode.off;
    _landmarkBuffers.clear();
    _noPoseFrameCount = 0;
    await _startLiveFeed();
  }

  Future<void> _toggleFlash() async {
    if (_isFrontCamera) return;
    _flashMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await _controller?.setFlashMode(_flashMode);
    setState(() {});
  }

  Future<void> _startLiveFeed() async {
    if (_controller != null) {
      await _controller?.stopImageStream();
      await _controller?.dispose();
    }
    final cam = _cameras[_cameraIndex];
    _controller = CameraController(cam, ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888);
    await _controller?.initialize();
    await _controller?.setFlashMode(_flashMode);
    _controller?.startImageStream(_processCameraImage);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sheetController.dispose();
    _flipController.dispose();
    _controller?.stopImageStream();
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Product select — ClothingProductModel.front & .back use karo
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _selectProduct(ClothingProductModel product) async {
    _closeSheet();

    // Already selected same product — skip
    if (_selectedProduct?.id == product.id) return;

    setState(() {
      _selectedProduct  = product;
      _isLoadingGarment = true;
      _activeView       = GarmentView.front;
      // Purani images hata do — naya load hone tak overlay nahi
      _frontImage       = null;
      _backImage        = null;
      _garmentPaint     = null;
    });

    // Cache check — agar pehle se loaded hain toh instant
    final frontCached = GarmentLoader.isCached(product.front);
    final backCached  = GarmentLoader.isCached(product.back);

    if (frontCached && backCached) {
      // Instant — no loading state needed
      final f = await GarmentLoader.load(product.front);
      final b = await GarmentLoader.load(product.back);
      if (mounted) setState(() {
        _frontImage       = f;
        _backImage        = b;
        _isLoadingGarment = false;
      });
      return;
    }

    // Network se load — front pehle (user foran dekhe), back background mein
    final frontImg = await GarmentLoader.load(product.front);
    if (mounted) setState(() {
      _frontImage       = frontImg;
      _isLoadingGarment = frontImg == null; // Agar front loaded ho gaya toh loading hatao
    });

    // Back image background mein load karo
    final backImg = await GarmentLoader.load(product.back);
    if (mounted) setState(() {
      _backImage        = backImg;
      _isLoadingGarment = false;
    });
  }

  void _removeProduct() => setState(() {
    _selectedProduct  = null;
    _frontImage       = null;
    _backImage        = null;
    _garmentPaint     = null;
    _isLoadingGarment = false;
  });

  /// Front/Back toggle with flip animation
  void _toggleView() {
    if (_selectedProduct == null) return;
    // Back image loaded hai? Check karo
    if (_activeView == GarmentView.front && _backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Back image load ho rahi hai...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    _flipController.forward(from: 0).then((_) {
      if (mounted) setState(() {
        _activeView = _activeView == GarmentView.front
            ? GarmentView.back
            : GarmentView.front;
      });
    });
  }

  void _openSheet()  { setState(() => _isSheetOpen = true); _sheetController.forward(); }
  void _closeSheet() {
    _sheetController.reverse().then((_) {
      if (mounted) setState(() => _isSheetOpen = false);
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Camera frame processing
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isEmpty) { _handleNoPose(); return; }

      final pose = poses.first;
      final newLandmarks = <PoseLandmarkType, PoseLandmark>{};
      bool hasHighConf = false;

      for (var type in PoseLandmarkType.values) {
        final lm = pose.landmarks[type];
        if (lm != null && lm.likelihood > _confidenceThreshold &&
            _allowedLandmarks.contains(type)) {
          hasHighConf = true;
          _landmarkBuffers.putIfAbsent(type, () => []);
          _landmarkBuffers[type]!.add(lm);
          if (_landmarkBuffers[type]!.length > _bufferSize)
            _landmarkBuffers[type]!.removeAt(0);
          final buf = _landmarkBuffers[type]!;
          double ax = 0, ay = 0, az = 0, al = 0;
          for (var b in buf) { ax += b.x; ay += b.y; az += b.z; al += b.likelihood; }
          final n = buf.length;
          newLandmarks[type] = PoseLandmark(
              type: type, x: ax/n, y: ay/n, z: az/n, likelihood: al/n);
        }
      }

      if (!hasHighConf || newLandmarks.length < 4) { _handleNoPose(); return; }

      _noPoseFrameCount = 0;
      final smoothedPose = Pose(landmarks: newLandmarks);
      final imgSize = Size(image.width.toDouble(), image.height.toDouble());

      final skeletonPainter = ExpertPosePainter(
          [smoothedPose], imgSize, inputImage.metadata!.rotation, _cameraLensDirection);

      // ── Garment overlay — activeImage (front ya back) use karo ────────
      CustomPaint? newGarmentPaint;
      final activeImg = _activeImage;
      if (activeImg != null) {
        newGarmentPaint = CustomPaint(
          painter: GarmentOverlayPainter(
            poses:               [smoothedPose],
            garmentImage:        activeImg,
            imageSize:           imgSize,
            rotation:            inputImage.metadata!.rotation,
            cameraLensDirection: _cameraLensDirection,
            config:              _warpConfig,
          ),
        );
      }

      if (mounted) setState(() {
        _posePaint    = CustomPaint(painter: skeletonPainter);
        _garmentPaint = newGarmentPaint;
        _text = '${newLandmarks.length} points detected';
      });
    } finally {
      _isBusy = false;
    }
  }

  void _handleNoPose() {
    _noPoseFrameCount++;
    if (_noPoseFrameCount >= _noPoseFrameLimit) {
      _landmarkBuffers.clear();
      _noPoseFrameCount = 0;
      if (mounted) setState(() {
        _posePaint = null; _garmentPaint = null;
        _text = 'No person detected';
      });
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;
    final cam = _cameras[_cameraIndex];
    final rotation = InputImageRotationValue.fromRawValue(cam.sensorOrientation);
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS    && format != InputImageFormat.bgra8888)) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, format: format, bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Capture
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final XFile file  = await _controller!.takePicture();
      final Uint8List b = await file.readAsBytes();
      final drawn = await _drawOnImage(b);
      if (mounted) _showPreviewDialog(drawn);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Capture failed: $e')));
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<Uint8List> _drawOnImage(Uint8List bytes) async {
    final codec   = await ui.instantiateImageCodec(bytes);
    final frame   = await codec.getNextFrame();
    final bgImage = frame.image;
    final imgSize = Size(bgImage.width.toDouble(), bgImage.height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder, Rect.fromLTWH(0, 0, imgSize.width, imgSize.height));
    canvas.drawImage(bgImage, Offset.zero, Paint());

    final tmp   = await _saveTemp(bytes);
    final poses = await _poseDetector.processImage(InputImage.fromFilePath(tmp.path));

    // Garment pehle (under skeleton)
    final activeImg = _activeImage;
    if (activeImg != null && poses.isNotEmpty) {
      GarmentOverlayPainter(
        poses: poses, garmentImage: activeImg, imageSize: imgSize,
        rotation: InputImageRotation.rotation0deg,
        cameraLensDirection: _cameraLensDirection, config: _warpConfig,
      ).paint(canvas, imgSize);
    }

    if (_showSkeleton && poses.isNotEmpty) {
      ExpertPosePainter(poses, imgSize,
          InputImageRotation.rotation0deg, _cameraLensDirection)
          .paint(canvas, imgSize);
    }

    final pic  = recorder.endRecording();
    final img  = await pic.toImage(imgSize.width.toInt(), imgSize.height.toInt());
    final png  = await img.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  }

  Future<File> _saveTemp(Uint8List bytes) async {
    final dir  = await Directory.systemTemp.createTemp('garment_');
    final file = File('${dir.path}/img.jpg');
    await file.writeAsBytes(bytes);
    return file;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final ready = _controller != null && _controller!.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (ready) _buildCameraPreview() else _buildLoading(),
        if (_garmentPaint != null) Positioned.fill(child: _garmentPaint!),
        if (_showSkeleton && _posePaint != null) Positioned.fill(child: _posePaint!),
        if (_isLoadingGarment)
          Container(color: Colors.black26,
              child: const Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00D4FF)),
                  SizedBox(height: 10),
                  Text('Loading garment...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ))),
        _buildTopBar(),
        if (_isSheetOpen) _buildGarmentSheet(),
        if (!_isSheetOpen) Positioned(
          left: 0, right: 0, bottom: 0,
          child: _buildBottomControls(),
        ),
      ]),
    );
  }

  Widget _buildLoading() => Container(
    color: const Color(0xFF0A0A1A),
    child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: Color(0xFF00D4FF)),
      SizedBox(height: 16),
      Text('Initialising camera...', style: TextStyle(color: Color(0xFF9090B0), fontSize: 14)),
    ])),
  );

  Widget _buildCameraPreview() {
    final size  = MediaQuery.of(context).size;
    var   scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    Widget preview = Transform.scale(scale: scale, child: Center(child: CameraPreview(_controller!)));
    if (_isFrontCamera) preview = Transform.scale(scaleX: -1, child: preview);
    return preview;
  }

  Widget _buildTopBar() => Positioned(
    top: 0, left: 0, right: 0,
    child: Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Colors.transparent])),
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16, right: 16, bottom: 16),
      child: Row(children: [
        GestureDetector(onTap: () => Navigator.pop(context),
            child: _iconBtn(Icons.arrow_back_ios_new_rounded)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.category, style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w700, fontSize: 18), overflow: TextOverflow.ellipsis),
          Text(widget.gender, style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 12)),
        ])),
        GestureDetector(onTap: () => setState(() => _showSkeleton = !_showSkeleton),
            child: _iconBtn(Icons.accessibility_new_rounded, active: _showSkeleton)),
        const SizedBox(width: 8),
        if (!_isFrontCamera)
          GestureDetector(onTap: _toggleFlash,
              child: _iconBtn(
                  _flashMode == FlashMode.torch ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  active: _flashMode == FlashMode.torch, activeColor: const Color(0xFFFFD700))),
      ]),
    ),
  );

  Widget _iconBtn(IconData icon, {bool active = false, Color activeColor = const Color(0xFF00D4FF)}) =>
      Container(width: 40, height: 40,
          decoration: BoxDecoration(
              color: active ? activeColor.withOpacity(0.25) : Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: active ? activeColor.withOpacity(0.6) : Colors.white.withOpacity(0.3), width: 1)),
          child: Icon(icon, color: active ? activeColor : Colors.white, size: 20));

  Widget _buildBottomControls() => Container(
    decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [Color(0xEE000000), Colors.transparent])),
    padding: EdgeInsets.only(
        left: 24, right: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24, top: 20),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (_selectedProduct != null) ...[
        _buildProductChip(),
        const SizedBox(height: 14),
      ],
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildStatusPill(),
      ),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _ControlButton(icon: Icons.flip_camera_ios_rounded, label: 'Flip', onTap: _switchCamera),
        // Capture button
        ScaleTransition(scale: _pulseAnim, child: GestureDetector(
          onTap: _capturePhoto,
          child: Container(width: 76, height: 76,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF00D4FF), Color(0xFF0077FF)]),
                  boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withOpacity(0.45),
                      blurRadius: 20, spreadRadius: 2)]),
              child: _isCapturing
                  ? const Padding(padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 32)),
        )),
        _ControlButton(icon: Icons.checkroom_rounded, label: 'Garments', onTap: _openSheet),
      ]),
    ]),
  );

  // ── Product chip — name + price + front/back toggle + remove ──────────────
  Widget _buildProductChip() {
    final isFront = _activeView == GarmentView.front;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8, runSpacing: 8,
      children: [
        // Product info chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.4), width: 1)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.checkroom_rounded, color: Color(0xFF00D4FF), size: 16),
            const SizedBox(width: 8),
            Text(_selectedProduct!.title,
                style: const TextStyle(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            // Price with discount
            Text(
              _selectedProduct!.discount > 0
                  ? 'Rs ${(_selectedProduct!.price * (1 - _selectedProduct!.discount / 100)).toInt()}'
                  : 'Rs ${_selectedProduct!.price}',
              style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            GestureDetector(onTap: _removeProduct,
                child: const Icon(Icons.close_rounded, color: Color(0xFF9090B0), size: 16)),
          ]),
        ),

        // Front / Back toggle button
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: isFront
                      ? [const Color(0xFF0077FF), const Color(0xFF00D4FF)]
                      : [const Color(0xFF7B2FFF), const Color(0xFFBB6BFF)]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(
                      color: (isFront ? const Color(0xFF00D4FF) : const Color(0xFF7B2FFF))
                          .withOpacity(0.35),
                      blurRadius: 10)]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                // Back image load indicator
                if (_activeView == GarmentView.front && _backImage == null)
                  const SizedBox(width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5,
                          color: Colors.white70))
                else
                  Icon(isFront ? Icons.flip_to_front_rounded : Icons.flip_to_back_rounded,
                      color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(isFront ? 'Front' : 'Back',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPill() => Container(
    key: ValueKey(_text),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    decoration: BoxDecoration(
        color: _posePaint != null
            ? const Color(0xFF00D4FF).withOpacity(0.18) : Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _posePaint != null ? const Color(0xFF00D4FF).withOpacity(0.5)
                : Colors.white.withOpacity(0.2), width: 1)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle,
          color: _posePaint != null ? const Color(0xFF00FF88) : const Color(0xFFFF6B6B))),
      const SizedBox(width: 8),
      Text(_text, style: TextStyle(
          color: _posePaint != null ? Colors.white : const Color(0xFFAAAAAA),
          fontSize: 13, fontWeight: FontWeight.w500)),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // Garment Sheet — ClothingProductModel cards
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildGarmentSheet() => Positioned.fill(
    child: GestureDetector(
      onTap: _closeSheet,
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: SizeTransition(
              sizeFactor: _sheetAnim, axisAlignment: -1,
              child: Container(
                decoration: const BoxDecoration(
                    color: Color(0xFF111111),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(top: BorderSide(color: Color(0xFF333333), width: 1))),
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.white24,
                          borderRadius: BorderRadius.circular(2))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(children: [
                      Icon(Icons.checkroom_rounded, color: Color(0xFF00D4FF), size: 20),
                      SizedBox(width: 10),
                      Text('Select Garment', style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 18)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  widget.products.isEmpty
                      ? const Padding(padding: EdgeInsets.all(32),
                      child: Text('No products available',
                          style: TextStyle(color: Colors.white38)))
                      : SizedBox(
                      height: 230,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.products.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => _buildProductCard(widget.products[i]),
                      )),
                ]),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildProductCard(ClothingProductModel product) {
    final isSelected = _selectedProduct?.id == product.id;
    // Thumbnail — images list ka pehla item ya front URL
    final thumbnail = product.images.isNotEmpty ? product.images.first : product.front;

    return GestureDetector(
      onTap: () => _selectProduct(product),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isSelected ? const Color(0xFF00D4FF) : const Color(0xFF333333),
                width: isSelected ? 2 : 1),
            boxShadow: isSelected ? [BoxShadow(
                color: const Color(0xFF00D4FF).withOpacity(0.25), blurRadius: 12)] : []),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Product image (thumbnail)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: thumbnail.isNotEmpty
                ? Image.network(thumbnail,
                height: 140, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _imgPlaceholder(),
                loadingBuilder: (_, child, p) =>
                p == null ? child : _imgLoading())
                : _imgPlaceholder(),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(product.category,
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
                // Price with discount
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (product.discount > 0)
                    Text('Rs ${product.price}',
                        style: const TextStyle(color: Color(0xFF666666),
                            fontSize: 10, decoration: TextDecoration.lineThrough)),
                  Text(
                    product.discount > 0
                        ? 'Rs ${(product.price * (1 - product.discount / 100)).toInt()}'
                        : 'Rs ${product.price}',
                    style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ]),
              ]),
              // Cache indicator — agar already loaded hai
              if (GarmentLoader.isCached(product.front))
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Row(children: [
                    Icon(Icons.check_circle_rounded,
                        color: Color(0xFF00FF88), size: 10),
                    SizedBox(width: 4),
                    Text('Ready', style: TextStyle(
                        color: Color(0xFF00FF88), fontSize: 10)),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(height: 140, color: const Color(0xFF222222),
      child: const Icon(Icons.checkroom_rounded, color: Colors.white24, size: 36));
  Widget _imgLoading() => Container(height: 140, color: const Color(0xFF1A1A1A),
      child: const Center(child: CircularProgressIndicator(
          color: Color(0xFF00D4FF), strokeWidth: 2)));

  // ── Preview dialog (unchanged) ────────────────────────────────────────────
  void _showPreviewDialog(Uint8List imageBytes) {
    showDialog(
      context: context, barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            color: const Color(0xFF1A1A2E),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF16213E), Color(0xFF0F3460)])),
                child: Row(children: const [
                  Icon(Icons.photo_camera_rounded, color: Color(0xFF00D4FF), size: 22),
                  SizedBox(width: 10),
                  Text('Captured Look', style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w600, fontSize: 17)),
                ]),
              ),
              Padding(padding: const EdgeInsets.all(12),
                  child: ClipRRect(borderRadius: BorderRadius.circular(12),
                      child: Image.memory(imageBytes))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(children: [
                  Expanded(child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFF404060)))),
                    child: const Text('Discard', style: TextStyle(color: Color(0xFF9090B0))),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_alt_rounded, size: 18),
                    label: const Text('Save to Gallery'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D4FF), foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    onPressed: () async {
                      var status = await Permission.photos.request();
                      if (!status.isGranted) {
                        if (status.isPermanentlyDenied) openAppSettings();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Photos permission denied')));
                        Navigator.pop(ctx); return;
                      }
                      final result = await ImageGallerySaverPlus.saveImage(imageBytes);
                      final ok = result != null && result is String && result.isNotEmpty;
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? '✅ Saved!' : '❌ Failed to save')));
                      Navigator.pop(ctx);
                    },
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── _ControlButton (unchanged) ────────────────────────────────────────────────
class _ControlButton extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _ControlButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 52, height: 52,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
              border: Border.all(color: Colors.white.withOpacity(0.25), width: 1)),
          child: Icon(icon, color: Colors.white, size: 24)),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 11)),
    ]),
  );
}

// ── ExpertPosePainter (UNCHANGED) ─────────────────────────────────────────────
class ExpertPosePainter extends CustomPainter {
  ExpertPosePainter(this.poses, this.imageSize, this.rotation, this.cameraLensDirection);
  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  static const double _confidenceThreshold = 0.8;
  static const List<List<PoseLandmarkType>> _connections = [
    [PoseLandmarkType.nose, PoseLandmarkType.leftEyeInner],
    [PoseLandmarkType.leftEyeInner, PoseLandmarkType.leftEye],
    [PoseLandmarkType.leftEye, PoseLandmarkType.leftEyeOuter],
    [PoseLandmarkType.leftEyeOuter, PoseLandmarkType.leftEar],
    [PoseLandmarkType.nose, PoseLandmarkType.rightEyeInner],
    [PoseLandmarkType.rightEyeInner, PoseLandmarkType.rightEye],
    [PoseLandmarkType.rightEye, PoseLandmarkType.rightEyeOuter],
    [PoseLandmarkType.rightEyeOuter, PoseLandmarkType.rightEar],
    [PoseLandmarkType.leftMouth, PoseLandmarkType.rightMouth],
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
        final lm1 = pose.landmarks[conn[0]]; final lm2 = pose.landmarks[conn[1]];
        if (lm1 == null || lm2 == null || lm1.likelihood <= _confidenceThreshold
            || lm2.likelihood <= _confidenceThreshold) continue;
        final p1 = Offset(_tx(lm1.x, size), _ty(lm1.y, size));
        final p2 = Offset(_tx(lm2.x, size), _ty(lm2.y, size));
        canvas.drawLine(p1, p2, Paint()
          ..shader = ui.Gradient.linear(p1, p2, [
            const Color(0xFF00D4FF).withOpacity(0.25), const Color(0xFF7B2FFF).withOpacity(0.25)])
          ..style = PaintingStyle.stroke ..strokeWidth = 9.0
          ..strokeCap = StrokeCap.round ..isAntiAlias = true);
        canvas.drawLine(p1, p2, Paint()
          ..shader = ui.Gradient.linear(p1, p2,
              [const Color(0xFF00D4FF), const Color(0xFF7B2FFF)])
          ..style = PaintingStyle.stroke ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round ..isAntiAlias = true);
      }
      pose.landmarks.forEach((type, lm) {
        if (lm.likelihood <= _confidenceThreshold) return;
        final c = Offset(_tx(lm.x, size), _ty(lm.y, size));
        final o = lm.likelihood.clamp(0.0, 1.0);
        canvas.drawCircle(c, 10, Paint()..color = const Color(0xFF00D4FF).withOpacity(o * 0.3)..isAntiAlias = true);
        canvas.drawCircle(c, 6.5, Paint()..color = Colors.white.withOpacity(o * 0.9)..isAntiAlias = true);
        canvas.drawCircle(c, 4.5, Paint()..color = Color.lerp(const Color(0xFF00D4FF),
            const Color(0xFF00FF88), ((lm.likelihood - _confidenceThreshold) /
                (1.0 - _confidenceThreshold)).clamp(0.0, 1.0))!.withOpacity(o)..isAntiAlias = true);
      });
    }
  }
  double _tx(double x, Size cs) {
    if (cameraLensDirection == CameraLensDirection.front) x = imageSize.width - x;
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return x * cs.width / (Platform.isIOS ? imageSize.width : imageSize.height);
      case InputImageRotation.rotation270deg:
        return cs.width - x * cs.width / (Platform.isIOS ? imageSize.width : imageSize.height);
      default: return x * cs.width / imageSize.width;
    }
  }
  double _ty(double y, Size cs) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * cs.height / (Platform.isIOS ? imageSize.height : imageSize.width);
      default: return y * cs.height / imageSize.height;
    }
  }
  @override
  bool shouldRepaint(covariant ExpertPosePainter old) =>
      old.imageSize != imageSize || old.poses != poses;
}