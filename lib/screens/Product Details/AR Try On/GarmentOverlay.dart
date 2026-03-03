import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:http/http.dart' as http;

// GarmentView enum — front ya back
enum GarmentView { front, back }

// ══════════════════════════════════════════════════════════════════════════════
// GarmentLoader
// Firebase Storage URLs cache mein store hote hain —
// ek baar load hone ke baad dobara network call nahi hogi
// ══════════════════════════════════════════════════════════════════════════════
class GarmentLoader {
  // ── In-memory cache: URL → ui.Image ───────────────────────────────────────
  static final Map<String, ui.Image> _cache = {};

  // ── In-flight tracker: agar already load ho raha hai toh same Future return
  static final Map<String, Future<ui.Image?>> _inFlight = {};

  /// URL se image load karo.
  /// - Agar cache mein hai → foran return (no network)
  /// - Agar already load ho raha hai → same Future await karo (no duplicate call)
  /// - Warna → fetch karo aur cache mein store karo
  static Future<ui.Image?> load(String url) async {
    if (url.isEmpty) return null;

    // 1. Cache hit — foran return
    if (_cache.containsKey(url)) return _cache[url];

    // 2. Already in-flight — same future
    if (_inFlight.containsKey(url)) return _inFlight[url];

    // 3. Fresh fetch
    final future = _fetchAndDecode(url);
    _inFlight[url] = future;

    final img = await future;
    _inFlight.remove(url);

    if (img != null) _cache[url] = img; // cache mein daal do
    return img;
  }

  /// Product select hone par front + back dono background mein preload karo
  /// Taaki toggle karte waqt delay na aaye
  static Future<void> preloadProduct(String frontUrl, String backUrl) {
    return Future.wait([
      load(frontUrl),
      load(backUrl),
    ]);
  }

  /// Cache se check karo — agar loaded hai toh true
  static bool isCached(String url) => _cache.containsKey(url);

  /// Specific URL cache se hatao (force reload ke liye)
  static void evict(String url) => _cache.remove(url);

  /// Poora cache clear karo (memory pressure pe call karo)
  static void clearAll() {
    _cache.clear();
    _inFlight.clear();
  }

  // ── Private: Firebase Storage URL se fetch + decode ───────────────────────
  static Future<ui.Image?> _fetchAndDecode(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          // Firebase Storage CORS ke liye
          'Accept': 'image/*, */*',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        debugPrint('[GarmentLoader] HTTP ${response.statusCode} for $url');
        return null;
      }

      final codec  = await ui.instantiateImageCodec(
        response.bodyBytes,
        // Max size limit — memory save karo
        targetWidth:  1024,
        targetHeight: 1024,
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('[GarmentLoader] Error loading $url: $e');
      return null;
    }
  }

  /// Bytes se load (captured image ke liye)
  static Future<ui.Image?> loadFromBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('[GarmentLoader] Error from bytes: $e');
      return null;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GarmentWarpConfig — overlay fine-tuning
// ══════════════════════════════════════════════════════════════════════════════
class GarmentWarpConfig {
  final double topPaddingFactor;
  final double bottomPaddingFactor;
  final double sidePaddingFactor;
  final double opacity;
  final double verticalOffset;
  final double scale;

  const GarmentWarpConfig({
    this.topPaddingFactor    = 0.18,
    this.bottomPaddingFactor = 0.15,
    this.sidePaddingFactor   = 0.12,
    this.opacity             = 0.92,
    this.verticalOffset      = 0.0,
    this.scale               = 1.0,
  });

  GarmentWarpConfig copyWith({
    double? topPaddingFactor,
    double? bottomPaddingFactor,
    double? sidePaddingFactor,
    double? opacity,
    double? verticalOffset,
    double? scale,
  }) =>
      GarmentWarpConfig(
        topPaddingFactor:    topPaddingFactor    ?? this.topPaddingFactor,
        bottomPaddingFactor: bottomPaddingFactor ?? this.bottomPaddingFactor,
        sidePaddingFactor:   sidePaddingFactor   ?? this.sidePaddingFactor,
        opacity:             opacity             ?? this.opacity,
        verticalOffset:      verticalOffset      ?? this.verticalOffset,
        scale:               scale               ?? this.scale,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// GarmentOverlayPainter
// garmentImage = cached ui.Image (ClothingProductModel.front ya .back se loaded)
// ══════════════════════════════════════════════════════════════════════════════
class GarmentOverlayPainter extends CustomPainter {
  GarmentOverlayPainter({
    required this.poses,
    required this.garmentImage,
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
    this.config = const GarmentWarpConfig(),
  });

  final List<Pose> poses;
  final ui.Image garmentImage;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final GarmentWarpConfig config;

  static const double _kMinConfidence = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty) return;
    final pose = poses.first;

    final ls = _point(pose, PoseLandmarkType.leftShoulder,  size);
    final rs = _point(pose, PoseLandmarkType.rightShoulder, size);
    final lh = _point(pose, PoseLandmarkType.leftHip,       size);
    final rh = _point(pose, PoseLandmarkType.rightHip,      size);

    if (ls == null || rs == null || lh == null || rh == null) return;

    final shoulderWidth = (rs - ls).distance;
    final torsoHeight   = ((lh.dy + rh.dy) / 2) - ((ls.dy + rs.dy) / 2);
    if (shoulderWidth < 20 || torsoHeight < 10) return;

    final topPad  = shoulderWidth * config.topPaddingFactor;
    final botPad  = torsoHeight   * config.bottomPaddingFactor;
    final sidePad = shoulderWidth * config.sidePaddingFactor;
    final vOffset = config.verticalOffset * torsoHeight;

    final mid   = Offset((ls.dx + rs.dx) / 2, (ls.dy + rs.dy) / 2);
    final angle = math.atan2(rs.dy - ls.dy, rs.dx - ls.dx);
    final s     = config.scale;
    final halfW = (shoulderWidth / 2 + sidePad) * s;
    final top   = (-topPad + vOffset) * s;
    final bot   = (torsoHeight + botPad + vOffset) * s;
    final cosA  = math.cos(angle);
    final sinA  = math.sin(angle);

    Offset r(double dx, double dy) => Offset(
      mid.dx + dx * cosA - dy * sinA,
      mid.dy + dx * sinA + dy * cosA,
    );

    _drawWarped(canvas, r(-halfW, top), r(halfW, top), r(-halfW, bot), r(halfW, bot));
  }

  void _drawWarped(Canvas canvas, Offset tl, Offset tr, Offset bl, Offset br) {
    final srcW = garmentImage.width.toDouble();
    final srcH = garmentImage.height.toDouble();

    canvas.drawVertices(
      ui.Vertices(
        ui.VertexMode.triangles,
        [tl, tr, bl, tr, br, bl],
        textureCoordinates: [
          Offset(0,    0),    Offset(srcW, 0),    Offset(0,    srcH),
          Offset(srcW, 0),    Offset(srcW, srcH), Offset(0,    srcH),
        ],
      ),
      BlendMode.srcOver,
      Paint()
        ..shader = ImageShader(
            garmentImage, TileMode.clamp, TileMode.clamp,
            Matrix4.identity().storage)
        ..isAntiAlias   = true
        ..filterQuality = FilterQuality.high
        ..color         = Colors.white.withOpacity(config.opacity),
    );

    _edgeLighting(canvas, tl, tr, bl, br);
  }

  void _edgeLighting(Canvas canvas, Offset tl, Offset tr, Offset bl, Offset br) {
    // Left shadow
    canvas.drawPath(
      Path()..moveTo(tl.dx, tl.dy)..lineTo(bl.dx, bl.dy)
        ..lineTo(bl.dx + 18, bl.dy)..lineTo(tl.dx + 18, tl.dy)..close(),
      Paint()..shader = ui.Gradient.linear(tl, Offset(tl.dx + 18, tl.dy),
          [Colors.black.withOpacity(0.10), Colors.transparent])..isAntiAlias = true,
    );
    // Right highlight
    canvas.drawPath(
      Path()..moveTo(tr.dx, tr.dy)..lineTo(br.dx, br.dy)
        ..lineTo(br.dx - 18, br.dy)..lineTo(tr.dx - 18, tr.dy)..close(),
      Paint()..shader = ui.Gradient.linear(tr, Offset(tr.dx - 18, tr.dy),
          [Colors.white.withOpacity(0.08), Colors.transparent])..isAntiAlias = true,
    );
    // Top collar fade
    canvas.drawPath(
      Path()..moveTo(tl.dx, tl.dy)..lineTo(tr.dx, tr.dy)
        ..lineTo(tr.dx, tr.dy + 12)..lineTo(tl.dx, tl.dy + 12)..close(),
      Paint()..shader = ui.Gradient.linear(tl, Offset(tl.dx, tl.dy + 12),
          [Colors.black.withOpacity(0.06), Colors.transparent])..isAntiAlias = true,
    );
  }

  Offset? _point(Pose pose, PoseLandmarkType type, Size canvasSize) {
    final lm = pose.landmarks[type];
    if (lm == null || lm.likelihood < _kMinConfidence) return null;
    return Offset(_tx(lm.x, canvasSize), _ty(lm.y, canvasSize));
  }

  double _tx(double x, Size cs) {
    if (cameraLensDirection == CameraLensDirection.front) x = imageSize.width - x;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return x * cs.width / (isIOS ? imageSize.width : imageSize.height);
      case InputImageRotation.rotation270deg:
        return cs.width - x * cs.width / (isIOS ? imageSize.width : imageSize.height);
      default:
        return x * cs.width / imageSize.width;
    }
  }

  double _ty(double y, Size cs) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * cs.height / (isIOS ? imageSize.height : imageSize.width);
      default:
        return y * cs.height / imageSize.height;
    }
  }

  @override
  bool shouldRepaint(covariant GarmentOverlayPainter old) =>
      old.poses != poses || old.garmentImage != garmentImage || old.config != config;
}