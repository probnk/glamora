import 'dart:math' as MathUtils;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as Vector2;
import '../../../models/ar_pose.dart';


class PoseDebugOverlay extends CustomPainter {
  final ARPose pose;
  final ui.Size screenSize;
  final bool showLandmarks;
  final bool showSkeleton;
  final bool showMetrics;
  final bool showAngles;
  final Color landmarkColor;
  final Color skeletonColor;
  final Color metricsColor;

  PoseDebugOverlay({
    required this.pose,
    required this.screenSize,
    this.showLandmarks = true,
    this.showSkeleton = true,
    this.showMetrics = true,
    this.showAngles = false,
    this.landmarkColor = Colors.red,
    this.skeletonColor = Colors.blue,
    this.metricsColor = Colors.green,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final landmarkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = landmarkColor;

    // Draw skeleton connections
    if (showSkeleton) {
      _drawSkeleton(canvas, paint);
    }

    // Draw landmarks
    if (showLandmarks) {
      _drawLandmarks(canvas, landmarkPaint);
    }

    // Draw angles
    if (showAngles) {
      _drawAngles(canvas, textPainter);
    }

    // Draw metrics
    if (showMetrics) {
      _drawMetrics(canvas, textPainter);
    }

    // Draw shoulder line
    _drawShoulderLine(canvas);

    // Draw torso line
    _drawTorsoLine(canvas);

    // Draw coordinate system
    _drawCoordinateSystem(canvas);
  }

  void _drawSkeleton(Canvas canvas, Paint paint) {
    final connections = [
      // Left arm
      if (pose.leftShoulder != null && pose.leftElbow != null)
        _drawLine(canvas, pose.leftShoulder!, pose.leftElbow!, paint
          ..color = skeletonColor
          ..strokeWidth = paint.strokeWidth
          ..style = paint.style
          ..strokeCap = paint.strokeCap,),
      if (pose.leftElbow != null && pose.leftWrist != null)
        _drawLine(canvas, pose.leftElbow!, pose.leftWrist!,paint
          ..color = skeletonColor
          ..strokeWidth = paint.strokeWidth
          ..style = paint.style
          ..strokeCap = paint.strokeCap,),

      // Right arm
      if (pose.rightShoulder != null && pose.rightElbow != null)
        _drawLine(canvas, pose.rightShoulder!, pose.rightElbow!, paint
          ..color = skeletonColor
          ..strokeWidth = paint.strokeWidth
          ..style = paint.style
          ..strokeCap = paint.strokeCap,),
      if (pose.rightElbow != null && pose.rightWrist != null)
        _drawLine(canvas, pose.rightElbow!, pose.rightWrist!, paint
          ..color = skeletonColor
          ..strokeWidth = paint.strokeWidth
          ..style = paint.style
          ..strokeCap = paint.strokeCap,),

      // Torso
      if (pose.leftShoulder != null && pose.rightShoulder != null)
        _drawLine(canvas, pose.leftShoulder!, pose.rightShoulder!, paint
          ..color = Colors.purple
          ..strokeWidth = paint.strokeWidth
          ..style = paint.style
          ..strokeCap = paint.strokeCap,),
      if (pose.leftShoulder != null && pose.leftHip != null)
        _drawLine(canvas, pose.leftShoulder!, pose.leftHip!, paint
          ..color = Colors.green
          ..strokeWidth = paint.strokeWidth
          ..style = paint.style
          ..strokeCap = paint.strokeCap,),
      if (pose.rightShoulder != null && pose.rightHip != null)
        _drawLine(canvas, pose.rightShoulder!, pose.rightHip!, paint
          ..color = Colors.green
          ..strokeWidth = paint.strokeWidth
          ..style = paint.style
          ..strokeCap = paint.strokeCap,),
      if (pose.leftHip != null && pose.rightHip != null)
        _drawLine(canvas, pose.leftHip!, pose.rightHip!, paint
          ..color = Colors.orange
          ..strokeWidth = paint.strokeWidth
          ..style = paint.style
          ..strokeCap = paint.strokeCap,),

      // Legs
      if (pose.leftHip != null && pose.leftKnee != null)
        _drawLine(canvas, pose.leftHip!, pose.leftKnee!, paint
          ..color = skeletonColor
          ..strokeWidth = paint.strokeWidth
          ..style = paint.style
          ..strokeCap = paint.strokeCap,),
      if (pose.leftKnee != null && pose.leftAnkle != null)
        _drawLine(canvas, pose.leftKnee!, pose.leftAnkle!, paint
          ..color = skeletonColor
          ..strokeWidth = paint.strokeWidth
          ..style = paint.style
          ..strokeCap = paint.strokeCap,),
      if (pose.rightHip != null && pose.rightKnee != null)
        _drawLine(canvas, pose.rightHip!, pose.rightKnee!, paint
          ..color = skeletonColor
          ..strokeWidth = paint.strokeWidth
          ..style = paint.style
          ..strokeCap = paint.strokeCap,),
      if (pose.rightKnee != null && pose.rightAnkle != null)
        _drawLine(canvas, pose.rightKnee!, pose.rightAnkle!,paint
          ..color = skeletonColor
          ..strokeWidth = paint.strokeWidth
          ..style = paint.style
          ..strokeCap = paint.strokeCap,),

      // Face connections
      if (pose.leftEar != null && pose.leftEye != null)
        _drawLine(canvas, pose.leftEar!, pose.leftEye!, paint
          ..color = Colors.cyan
          ..strokeWidth = paint.strokeWidth
          ..style = paint.style
          ..strokeCap = paint.strokeCap,),
      if (pose.rightEar != null && pose.rightEye != null)
        _drawLine(canvas, pose.rightEar!, pose.rightEye!, paint
          ..color = Colors.cyan
          ..strokeWidth = paint.strokeWidth
          ..style = paint.style
          ..strokeCap = paint.strokeCap,),
      if (pose.leftEye != null && pose.rightEye != null)
        _drawLine(canvas, pose.leftEye!, pose.rightEye!, paint
          ..color = Colors.cyan
          ..strokeWidth = paint.strokeWidth
          ..style = paint.style
          ..strokeCap = paint.strokeCap,),
    ];
  }

  void _drawLandmarks(Canvas canvas, Paint paint) {
    // Define landmark colors based on type
    final Map<String, Color> landmarkColors = {
      'shoulder': Colors.red,
      'hip': Colors.green,
      'elbow': Colors.orange,
      'wrist': Colors.yellow,
      'knee': Colors.blue,
      'ankle': Colors.purple,
      'ear': Colors.cyan,
      'eye': Colors.pink,
    };

    // Draw all landmarks
    for (final entry in pose.landmarks.entries) {
      final landmark = entry.value;
      final type = _getLandmarkType(entry.key);
      final color = landmarkColors[type] ?? Colors.white;

      // Draw landmark point
      canvas.drawCircle(
        Offset(landmark.x, landmark.y),
        4,
        paint..color = color,
      );

      // Draw landmark ID for debugging
      if (pose.landmarks.length <= 20) { // Only show IDs for key landmarks
        final textSpan = TextSpan(
          text: entry.key.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            backgroundColor: Colors.black.withOpacity(0.5),
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(landmark.x + 6, landmark.y - 6),
        );

      }
    }
  }

  String _getLandmarkType(int key) {
    if (key >= 11 && key <= 12) return 'shoulder';
    if (key >= 13 && key <= 14) return 'elbow';
    if (key >= 15 && key <= 16) return 'wrist';
    if (key >= 23 && key <= 24) return 'hip';
    if (key >= 25 && key <= 26) return 'knee';
    if (key >= 27 && key <= 28) return 'ankle';
    if (key >= 7 && key <= 8) return 'ear';
    if (key >= 2 && key <= 5) return 'eye';
    return 'unknown';
  }

  void _drawAngles(Canvas canvas, TextPainter textPainter) {
    // Draw shoulder angle
    if (pose.leftShoulder != null && pose.rightShoulder != null) {
      final angle = pose.shoulderAngle;
      final center = pose.shoulderCenter;

      // Draw angle arc
      final rect = Rect.fromCircle(
        center: Offset(center.x, center.y),
        radius: 30,
      );

      canvas.drawArc(
        rect,
        0,
        angle,
        false,
        Paint()
          ..color = Colors.yellow.withOpacity(0.3)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

      // Draw angle text
      final angleText = TextSpan(
        text: '${(angle * 180 / MathUtils.pi).toStringAsFixed(1)}°',
        style: TextStyle(
          color: Colors.yellow,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black.withOpacity(0.5),
        ),
      );

      textPainter.text = angleText;
      textPainter.layout();

      final textOffset = Offset(
        center.x - textPainter.width / 2,
        center.y - 40,
      );

      textPainter.paint(canvas, textOffset);
    }

    // Draw torso angle
    if (pose.leftShoulder != null && pose.rightShoulder != null &&
        pose.leftHip != null && pose.rightHip != null) {
      final angle = pose.torsoAngle;
      final shoulderCenter = pose.shoulderCenter;
      final hipCenter = Offset(
        (pose.leftHip!.x + pose.rightHip!.x) / 2,
        (pose.leftHip!.y + pose.rightHip!.y) / 2,
      );

      // Draw angle indicator
      final midPoint = Offset(
        (shoulderCenter.x + hipCenter.dx) / 2,
        (shoulderCenter.y + hipCenter.dy) / 2,
      );

      final torsoAngleText = TextSpan(
        text: '${(angle * 180 / MathUtils.pi).toStringAsFixed(1)}°',
        style: TextStyle(
          color: Colors.cyan,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black.withOpacity(0.5),
        ),
      );

      textPainter.text = torsoAngleText;
      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(
          midPoint.dx - textPainter.width / 2,
          midPoint.dy - 20,
        ),
      );
    }
  }

  void _drawMetrics(Canvas canvas, TextPainter textPainter) {
    final metrics = [
      'Confidence: ${(pose.confidence * 100).toStringAsFixed(1)}%',
      'Shoulder Dist: ${pose.shoulderDistance.toStringAsFixed(1)}px',
      'Torso Height: ${pose.torsoHeight.toStringAsFixed(1)}px',
      'View: ${pose.isFacingFront ? 'Front' : 'Back'}',
      if (pose.leftEar != null || pose.rightEar != null)
        'Ears Visible: ✓',
      if (pose.leftEye != null || pose.rightEye != null)
        'Eyes Visible: ✓',
    ];

    // Draw metrics box
    final boxPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    const boxPadding = 8.0;
    const lineHeight = 14.0;
    const boxWidth = 180.0;
    final boxHeight = (metrics.length * lineHeight) + (boxPadding * 2);

    final boxRect = Rect.fromLTWH(
      10,
      10,
      boxWidth,
      boxHeight,
    );

    canvas.drawRect(boxRect, boxPaint);

    // Draw border
    canvas.drawRect(
      boxRect,
      Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Draw metrics text
    for (int i = 0; i < metrics.length; i++) {
      final metricText = TextSpan(
        text: metrics[i],
        style: TextStyle(
          color: _getMetricColor(metrics[i]),
          fontSize: 11,
          fontFamily: 'Monospace',
        ),
      );

      textPainter.text = metricText;
      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(
          boxRect.left + boxPadding,
          boxRect.top + boxPadding + (i * lineHeight),
        ),
      );
    }
  }

  Color _getMetricColor(String metric) {
    if (metric.contains('Confidence')) {
      final value = double.parse(metric.split(': ')[1].replaceAll('%', ''));
      if (value >= 80) return Colors.green;
      if (value >= 60) return Colors.yellow;
      return Colors.red;
    }

    if (metric.contains('✓')) return Colors.green;
    return Colors.white;
  }

  void _drawShoulderLine(Canvas canvas) {
    if (pose.leftShoulder != null && pose.rightShoulder != null) {
      final leftShoulder = pose.leftShoulder!;
      final rightShoulder = pose.rightShoulder!;

      // Draw shoulder line
      canvas.drawLine(
        Offset(leftShoulder.x, leftShoulder.y),
        Offset(rightShoulder.x, rightShoulder.y),
        Paint()
          ..color = Colors.purple.withOpacity(0.5)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );

      // Draw shoulder points
      canvas.drawCircle(
        Offset(leftShoulder.x, leftShoulder.y),
        6,
        Paint()
          ..color = Colors.purple
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        Offset(rightShoulder.x, rightShoulder.y),
        6,
        Paint()
          ..color = Colors.purple
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawTorsoLine(Canvas canvas) {
    if (pose.leftShoulder != null && pose.rightShoulder != null &&
        pose.leftHip != null && pose.rightHip != null) {
      final shoulderCenter = pose.shoulderCenter;
      final hipCenter = Offset(
        (pose.leftHip!.x + pose.rightHip!.x) / 2,
        (pose.leftHip!.y + pose.rightHip!.y) / 2,
      );

      // Draw torso center line
      canvas.drawLine(
        Offset(shoulderCenter.x, shoulderCenter.y),
        hipCenter,
        Paint()
          ..color = Colors.green.withOpacity(0.5)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

      // Draw hip points
      canvas.drawCircle(
        Offset(pose.leftHip!.x, pose.leftHip!.y),
        5,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        Offset(pose.rightHip!.x, pose.rightHip!.y),
        5,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawCoordinateSystem(Canvas canvas) {
    // Draw coordinate system in bottom right
    const systemSize = 60.0;
    const padding = 20.0;

    final origin = Offset(
      screenSize.width - padding - systemSize,
      screenSize.height - padding - systemSize,
    );

    // Draw axes
    canvas.drawLine(
      origin,
      Offset(origin.dx + systemSize, origin.dy),
      Paint()
        ..color = Colors.red
        ..strokeWidth = 2,
    );

    canvas.drawLine(
      origin,
      Offset(origin.dx, origin.dy - systemSize),
      Paint()
        ..color = Colors.green
        ..strokeWidth = 2,
    );

    // Draw labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // X axis label
    textPainter.text = const TextSpan(
      text: 'X',
      style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(origin.dx + systemSize + 5, origin.dy - 5));

    // Y axis label
    textPainter.text = const TextSpan(
      text: 'Y',
      style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(origin.dx - 10, origin.dy - systemSize - 10));
  }

  void _drawLine(Canvas canvas, Vector2.Vector2 start, Vector2.Vector2 end, Paint paint) {
    canvas.drawLine(
      Offset(start.x, start.y),
      Offset(end.x, end.y),
      paint,
    );
  }

  @override
  bool shouldRepaint(PoseDebugOverlay oldDelegate) {
    return pose != oldDelegate.pose ||
        showLandmarks != oldDelegate.showLandmarks ||
        showSkeleton != oldDelegate.showSkeleton ||
        showMetrics != oldDelegate.showMetrics ||
        showAngles != oldDelegate.showAngles;
  }
}