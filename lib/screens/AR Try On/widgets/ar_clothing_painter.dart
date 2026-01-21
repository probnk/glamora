import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../../models/ar_pose.dart';

class ARClothingPainter extends CustomPainter {
  final ARPose? pose;
  final ui.Image? overlayImage;
  final bool showDebug;
  final double opacity;

  ARClothingPainter({
    this.pose,
    this.overlayImage,
    this.showDebug = false,
    this.opacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (overlayImage == null) return;

    final paint = ui.Paint()
      ..color = ui.Color.fromRGBO(255, 255, 255, opacity)
      ..filterQuality = ui.FilterQuality.high
      ..isAntiAlias = true;

    // Draw the AR overlay
    canvas.drawImageRect(
      overlayImage!,
      ui.Rect.fromLTWH(0, 0, overlayImage!.width.toDouble(), overlayImage!.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );

    // Draw debug information if enabled
    if (showDebug && pose != null) {
      _drawDebugInfo(canvas, size, pose!);
    }
  }

  void _drawDebugInfo(Canvas canvas, Size size, ARPose pose) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw pose points
    final pointPaint = ui.Paint()
      ..color = Colors.red
      ..strokeWidth = 4
      ..style = ui.PaintingStyle.fill;

    final linePaint = ui.Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = ui.PaintingStyle.stroke;

    // Draw shoulder line
    if (pose.leftShoulder != null && pose.rightShoulder != null) {
      canvas.drawLine(
        Offset(pose.leftShoulder!.x, pose.leftShoulder!.y),
        Offset(pose.rightShoulder!.x, pose.rightShoulder!.y),
        linePaint,
      );
    }

    // Draw torso line
    if (pose.leftShoulder != null && pose.rightShoulder != null &&
        pose.leftHip != null && pose.rightHip != null) {
      final shoulderCenter = pose.shoulderCenter;
      final hipCenter = Offset(
        (pose.leftHip!.x + pose.rightHip!.x) / 2,
        (pose.leftHip!.y + pose.rightHip!.y) / 2,
      );

      canvas.drawLine(
        Offset(shoulderCenter.x, shoulderCenter.y),
        hipCenter,
        linePaint,
      );
    }

    // Draw key points
    final landmarks = [
      pose.leftShoulder,
      pose.rightShoulder,
      pose.leftHip,
      pose.rightHip,
      pose.leftEar,
      pose.rightEar,
    ];

    for (final landmark in landmarks) {
      if (landmark != null) {
        canvas.drawCircle(
          Offset(landmark.x, landmark.y),
          4,
          pointPaint,
        );
      }
    }

    // Draw info text
    final info = '''
Pose Confidence: ${(pose.confidence * 100).toStringAsFixed(1)}%
Shoulder Distance: ${pose.shoulderDistance.toStringAsFixed(1)}
Torso Height: ${pose.torsoHeight.toStringAsFixed(1)}
Angle: ${(pose.shoulderAngle * 180 / 3.14159).toStringAsFixed(1)}°
View: ${pose.isFacingFront ? 'Front' : 'Back'}
    ''';

    textPainter.text = TextSpan(
      text: info,
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        backgroundColor: Colors.black.withOpacity(0.5),
      ),
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(10, 10));
  }

  @override
  bool shouldRepaint(ARClothingPainter oldDelegate) {
    return pose != oldDelegate.pose ||
        overlayImage != oldDelegate.overlayImage ||
        showDebug != oldDelegate.showDebug ||
        opacity != oldDelegate.opacity;
  }
}