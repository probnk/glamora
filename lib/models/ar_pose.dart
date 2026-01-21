import 'dart:math';
import 'dart:ui' as ui;
import 'package:vector_math/vector_math_64.dart';

class ARPose {
  final Map<int, Vector2> landmarks;
  final double confidence;
  final DateTime timestamp;
  final ui.Size imageSize;
  final bool isFacingFront;
  final Vector2? leftShoulder;
  final Vector2? rightShoulder;
  final Vector2? leftHip;
  final Vector2? rightHip;
  final Vector2? leftEar;
  final Vector2? rightEar;
  final Vector2? leftEye;
  final Vector2? rightEye;
  final Vector2? leftElbow;
  final Vector2? rightElbow;
  final Vector2? leftWrist;
  final Vector2? rightWrist;
  final Vector2? leftKnee;
  final Vector2? rightKnee;
  final Vector2? leftAnkle;
  final Vector2? rightAnkle;

  ARPose({
    required this.landmarks,
    required this.confidence,
    required this.timestamp,
    required this.imageSize,
    this.isFacingFront = true,
    this.leftShoulder,
    this.rightShoulder,
    this.leftHip,
    this.rightHip,
    this.leftEar,
    this.rightEar,
    this.leftEye,
    this.rightEye,
    this.leftElbow,
    this.rightElbow,
    this.leftWrist,
    this.rightWrist,
    this.leftKnee,
    this.rightKnee,
    this.leftAnkle,
    this.rightAnkle,
  });

  factory ARPose.fromLandmarks(
      Map<int, Vector2> landmarks,
      double confidence,
      ui.Size imageSize,
      ) {
    final leftShoulder = landmarks[11];
    final rightShoulder = landmarks[12];
    final leftEar = landmarks[7];
    final rightEar = landmarks[8];
    final leftEye = landmarks[2];
    final rightEye = landmarks[5];

    final isFacingFront = _determineFacingDirection(
      leftEar,
      rightEar,
      leftEye,
      rightEye,
    );

    return ARPose(
      landmarks: landmarks,
      confidence: confidence,
      timestamp: DateTime.now(),
      imageSize: imageSize,
      isFacingFront: isFacingFront,
      leftShoulder: leftShoulder,
      rightShoulder: rightShoulder,
      leftHip: landmarks[23],
      rightHip: landmarks[24],
      leftEar: leftEar,
      rightEar: rightEar,
      leftEye: leftEye,
      rightEye: rightEye,
      leftElbow: landmarks[13],
      rightElbow: landmarks[14],
      leftWrist: landmarks[15],
      rightWrist: landmarks[16],
      leftKnee: landmarks[25],
      rightKnee: landmarks[26],
      leftAnkle: landmarks[27],
      rightAnkle: landmarks[28],
    );
  }

  static bool _determineFacingDirection(
      Vector2? leftEar,
      Vector2? rightEar,
      Vector2? leftEye,
      Vector2? rightEye,
      ) {
    // If ears are visible, user is facing front
    // If ears are not visible but eyes are, still facing front
    // If neither ears nor eyes are visible, assume back view
    final earsVisible = (leftEar != null || rightEar != null);
    final eyesVisible = (leftEye != null || rightEye != null);

    return earsVisible || eyesVisible;
  }

  double get shoulderDistance {
    if (leftShoulder == null || rightShoulder == null) return 0.0;
    return (leftShoulder! - rightShoulder!).length;
  }

  double get torsoHeight {
    if (leftShoulder == null || rightShoulder == null || leftHip == null || rightHip == null) {
      return 0.0;
    }

    final shoulderCenter = (leftShoulder! + rightShoulder!) / 2;
    final hipCenter = (leftHip! + rightHip!) / 2;
    return (shoulderCenter - hipCenter).length;
  }

  Vector2 get shoulderCenter {
    if (leftShoulder == null || rightShoulder == null) {
      return Vector2(imageSize.width / 2, imageSize.height / 3);
    }
    return (leftShoulder! + rightShoulder!) / 2;
  }

  double get shoulderAngle {
    if (leftShoulder == null || rightShoulder == null) return 0.0;
    final delta = rightShoulder! - leftShoulder!;
    return atan2(delta.y, delta.x);
  }

  double get torsoAngle {
    if (leftShoulder == null || rightShoulder == null || leftHip == null || rightHip == null) {
      return 0.0;
    }

    final shoulderCenter = (leftShoulder! + rightShoulder!) / 2;
    final hipCenter = (leftHip! + rightHip!) / 2;
    final delta = hipCenter - shoulderCenter;
    return atan2(delta.y, delta.x);
  }

  bool get isValidForAR {
    return confidence > 0.5 &&
        leftShoulder != null &&
        rightShoulder != null &&
        leftHip != null &&
        rightHip != null;
  }

  bool get hasFullUpperBody {
    return leftShoulder != null &&
        rightShoulder != null &&
        leftElbow != null &&
        rightElbow != null &&
        leftWrist != null &&
        rightWrist != null;
  }

  ARPose scaledToSize(ui.Size newSize) {
    final scaleX = newSize.width / imageSize.width;
    final scaleY = newSize.height / imageSize.height;

    final scaledLandmarks = <int, Vector2>{};
    for (final entry in landmarks.entries) {
      scaledLandmarks[entry.key] = Vector2(
        entry.value.x * scaleX,
        entry.value.y * scaleY,
      );
    }

    return ARPose.fromLandmarks(scaledLandmarks, confidence, newSize);
  }
}