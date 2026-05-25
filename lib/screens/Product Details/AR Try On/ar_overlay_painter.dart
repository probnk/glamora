import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'pose_mapper.dart';
import 'ar_tryon_screen.dart';

class AROverlayPainter extends CustomPainter {
  final List<Pose> poses;
  final ui.Image? clothingImage;
  final ClothingCategory category;
  final Size imageSize;
  final Rect? smoothedRect;
  final bool flipX;
  final bool showSkeleton;

  AROverlayPainter({
    required this.poses,
    required this.clothingImage,
    required this.category,
    required this.imageSize,
    this.smoothedRect,
    this.flipX = false,
    this.showSkeleton = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty) return;
    final pose = poses.first;

    // Clothing first (behind skeleton)
    if (clothingImage != null && smoothedRect != null) {
      _drawClothingOverlay(canvas, smoothedRect!);
    }

    // Skeleton only when toggled on
    if (showSkeleton) {
      _drawSkeleton(canvas, pose, size);
    }
  }

  void _drawSkeleton(Canvas canvas, Pose pose, Size size) {
    if (imageSize == Size.zero) return;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    final scale = scaleX > scaleY ? scaleX : scaleY;
    final ox = (size.width - imageSize.width * scale) / 2;
    final oy = (size.height - imageSize.height * scale) / 2;

    Offset? getLandmarkOffset(PoseLandmarkType type) {
      final lm = pose.landmarks[type];
      if (lm == null || lm.likelihood < 0.5) return null;
      final x = flipX ? (imageSize.width - lm.x) : lm.x;
      return Offset(x * scale + ox, lm.y * scale + oy);
    }

    // Lines: green, slightly dark shade
    final linePaint = Paint()
      ..color = const Color(0xFF00C853).withOpacity(0.75) // darker greenAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Dots: slightly darker than lines for differentiation
    final pointPaint = Paint()
      ..color = const Color(0xFF00E676) // greenAccent[400]
      ..style = PaintingStyle.fill;

    for (final connection in PoseMapper.skeletonConnections) {
      final from = getLandmarkOffset(connection[0]);
      final to = getLandmarkOffset(connection[1]);
      if (from != null && to != null) canvas.drawLine(from, to, linePaint);
    }

    for (final type in PoseMapper.bodyOnlyLandmarks) {
      final offset = getLandmarkOffset(type);
      if (offset != null) canvas.drawCircle(offset, 5, pointPaint);
    }
  }

  void _drawClothingOverlay(Canvas canvas, Rect dst) {
    final src = Rect.fromLTWH(
      0,
      0,
      clothingImage!.width.toDouble(),
      clothingImage!.height.toDouble(),
    );
    canvas.drawImageRect(
      clothingImage!,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(AROverlayPainter old) =>
      old.smoothedRect != smoothedRect ||
          old.clothingImage != clothingImage ||
          old.poses != poses ||
          old.flipX != flipX ||
          old.showSkeleton != showSkeleton;
}