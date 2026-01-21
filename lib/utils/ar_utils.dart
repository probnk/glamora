import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import '../models/ar_pose.dart';
import 'image_utils.dart';

class ARUtils {
  // Constants
  static const double optimalDistance = 1.5; // meters
  static const double minDetectionConfidence = 0.5;
  static const double minLandmarkConfidence = 0.3;

  // Body measurement constants (in meters)
  static const double avgShoulderWidth = 0.4;
  static const double avgTorsoHeight = 0.6;
  static const double avgArmLength = 0.6;

  // Cloth fitting parameters
  static const double shirtWidthMultiplier = 1.8;
  static const double shirtHeightMultiplier = 2.4;
  static const double pantsWidthMultiplier = 1.2;
  static const double pantsHeightMultiplier = 2.0;

  // Performance optimization
  static const int maxFrameSkip = 3;
  static const int calibrationFramesRequired = 30;
  static const double calibrationConfidenceThreshold = 0.7;

  /// Calculate user distance from camera using shoulder width
  static double calculateDistanceFromCamera(double shoulderWidthPixels, double focalLength) {
    if (shoulderWidthPixels <= 0) return optimalDistance;

    // Using similar triangles: realWidth / distance = pixelWidth / focalLength
    final distance = (avgShoulderWidth * focalLength) / shoulderWidthPixels;
    return distance.clamp(0.5, 5.0); // Clamp to reasonable range
  }

  /// Calculate scale factor based on distance
  static double calculateScaleFactor(double distance) {
    if (distance <= 0) return 1.0;

    final scale = optimalDistance / distance;
    return scale.clamp(0.3, 3.0); // Prevent extreme scaling
  }

  /// Calculate shirt position on body
  static Offset calculateShirtPosition(ARPose pose, ui.Size screenSize) {
    if (!pose.isValidForAR) {
      return Offset(screenSize.width / 2, screenSize.height / 3);
    }

    final shoulderCenter = pose.shoulderCenter;
    final verticalOffset = pose.torsoHeight * 0.3;

    return Offset(
      shoulderCenter.x.clamp(0, screenSize.width),
      (shoulderCenter.y + verticalOffset).clamp(0, screenSize.height),
    );
  }

  /// Calculate shirt size based on body measurements
  static Size calculateShirtSize(ARPose pose, double scaleFactor) {
    if (!pose.isValidForAR) {
      return const Size(200, 300);
    }

    final baseWidth = pose.shoulderDistance * shirtWidthMultiplier;
    final baseHeight = pose.torsoHeight * shirtHeightMultiplier;

    return Size(
      (baseWidth * scaleFactor).clamp(100, 800),
      (baseHeight * scaleFactor).clamp(150, 1000),
    );
  }

  /// Calculate rotation angle for shirt
  static double calculateShirtRotation(ARPose pose) {
    if (!pose.isValidForAR) return 0.0;

    // Use shoulder angle as base rotation
    double rotation = pose.shoulderAngle;

    // Adjust for torso tilt
    if (pose.torsoHeight > 0) {
      final torsoAngle = pose.torsoAngle;
      rotation += torsoAngle * 0.3; // Dampen torso influence
    }

    return rotation;
  }

  /// Determine if user is facing front or back
  static bool isFacingFront(ARPose pose) {
    // Check if ears are visible (front view)
    final earsVisible = (pose.leftEar != null && pose.leftEar!.length2 > 0) ||
        (pose.rightEar != null && pose.rightEar!.length2 > 0);

    // Check if eyes are visible (front view)
    final eyesVisible = (pose.leftEye != null && pose.leftEye!.length2 > 0) ||
        (pose.rightEye != null && pose.rightEye!.length2 > 0);

    // If either ears or eyes are visible, user is facing front
    return earsVisible || eyesVisible;
  }

  /// Calculate perspective transformation for side views
  static Matrix4 calculatePerspectiveMatrix(double angle, double distance) {
    final matrix = Matrix4.identity();

    // Apply rotation based on angle
    matrix.rotateY(angle);

    // Apply perspective based on distance
    final perspective = 0.001 * (distance / optimalDistance);
    matrix.setEntry(3, 2, perspective.clamp(0.0005, 0.005));

    return matrix;
  }

  /// Calculate cloth physics parameters
  static Map<String, double> calculateClothPhysics(ARPose pose, double scaleFactor) {
    return {
      'stretch': _calculateStretchFactor(pose),
      'shear': _calculateShearFactor(pose),
      'opacity': _calculateOpacity(pose),
      'blur': _calculateMotionBlur(pose),
    };
  }

  static double _calculateStretchFactor(ARPose pose) {
    double stretch = 1.0;

    // Increase stretch when arms are raised
    if (pose.leftElbow != null && pose.rightElbow != null) {
      final avgElbowHeight = (pose.leftElbow!.y + pose.rightElbow!.y) / 2;
      final shoulderHeight = pose.shoulderCenter.y;

      if (avgElbowHeight < shoulderHeight) {
        // Arms are raised
        final raiseAmount = (shoulderHeight - avgElbowHeight) / shoulderHeight;
        stretch += raiseAmount * 0.3;
      }
    }

    return stretch.clamp(1.0, 1.5);
  }

  static double _calculateShearFactor(ARPose pose) {
    if (!pose.isValidForAR) return 0.0;

    // Calculate shear based on torso tilt
    return (pose.torsoAngle * 0.5).clamp(-0.3, 0.3);
  }

  static double _calculateOpacity(ARPose pose) {
    double opacity = 1.0;

    // Reduce opacity when body parts overlap
    if (pose.leftElbow != null && pose.rightElbow != null) {
      final elbowDistance = (pose.leftElbow! - pose.rightElbow!).length;
      if (elbowDistance < pose.shoulderDistance * 0.3) {
        // Elbows are close together (might overlap shirt)
        opacity = 0.85;
      }
    }

    return opacity;
  }

  static double _calculateMotionBlur(ARPose pose) {
    // This would normally use velocity calculations
    // Simplified version based on pose confidence
    return (1.0 - pose.confidence).clamp(0.0, 0.3);
  }

  /// Calculate bounding box for pose
  static Rect calculatePoseBoundingBox(ARPose pose) {
    if (!pose.isValidForAR) return Rect.zero;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final landmark in pose.landmarks.values) {
      minX = math.min(minX, landmark.x);
      minY = math.min(minY, landmark.y);
      maxX = math.max(maxX, landmark.x);
      maxY = math.max(maxY, landmark.y);
    }

    // Add padding
    const padding = 20.0;
    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }

  /// Check if pose is valid for AR
  static bool isPoseValidForAR(ARPose pose) {
    return pose.confidence >= minDetectionConfidence &&
        pose.leftShoulder != null &&
        pose.rightShoulder != null &&
        pose.leftHip != null &&
        pose.rightHip != null &&
        pose.shoulderDistance > 0 &&
        pose.torsoHeight > 0;
  }

  /// Calculate calibration score
  static double calculateCalibrationScore(List<ARPose> poses) {
    if (poses.isEmpty) return 0.0;

    double totalConfidence = 0.0;
    double totalShoulderDistance = 0.0;
    double totalTorsoHeight = 0.0;

    for (final pose in poses) {
      totalConfidence += pose.confidence;
      totalShoulderDistance += pose.shoulderDistance;
      totalTorsoHeight += pose.torsoHeight;
    }

    final avgConfidence = totalConfidence / poses.length;
    final consistency = _calculateConsistency(poses);

    return (avgConfidence * 0.6 + consistency * 0.4).clamp(0.0, 1.0);
  }

  static double _calculateConsistency(List<ARPose> poses) {
    if (poses.length < 2) return 0.0;

    double shoulderVariance = 0.0;
    double torsoVariance = 0.0;

    final avgShoulder = poses.map((p) => p.shoulderDistance).reduce((a, b) => a + b) / poses.length;
    final avgTorso = poses.map((p) => p.torsoHeight).reduce((a, b) => a + b) / poses.length;

    for (final pose in poses) {
      shoulderVariance += math.pow(pose.shoulderDistance - avgShoulder, 2);
      torsoVariance += math.pow(pose.torsoHeight - avgTorso, 2);
    }

    shoulderVariance /= poses.length;
    torsoVariance /= poses.length;

    // Lower variance = higher consistency
    final shoulderConsistency = 1.0 / (1.0 + shoulderVariance);
    final torsoConsistency = 1.0 / (1.0 + torsoVariance);

    return (shoulderConsistency + torsoConsistency) / 2;
  }

  /// Calculate FPS based on frame processing times
  static double calculateFPS(List<int> processingTimes) {
    if (processingTimes.isEmpty) return 0.0;

    final totalTime = processingTimes.reduce((a, b) => a + b);
    final avgTime = totalTime / processingTimes.length;

    return avgTime > 0 ? 1000 / avgTime : 0.0;
  }

  /// Optimize image for AR display
  static Future<ui.Image> optimizeImageForAR(
      ui.Image originalImage,
      double scaleFactor,
      bool isLowMemory,
      ) async {
    final targetWidth = (originalImage.width * scaleFactor).toInt();
    final targetHeight = (originalImage.height * scaleFactor).toInt();

    // For low memory devices, use lower quality
    final quality = isLowMemory ? 0.7 : 0.9;

    return await ImageUtils.resizeImage(
      originalImage,
      targetWidth,
      targetHeight,
      quality: quality,
    );
  }

  /// Create transformation matrix for AR overlay
  static Matrix4 createTransformationMatrix({
    required Offset position,
    required Size size,
    required double rotation,
    required double scale,
    double shearX = 0.0,
    double shearY = 0.0,
  }) {
    final matrix = Matrix4.identity();

    // Translate to position
    matrix.translate(position.dx, position.dy);

    // Apply rotation
    matrix.rotateZ(rotation);

    // Apply scale
    matrix.scale(scale, scale);

    // Apply shear
    if (shearX != 0.0 || shearY != 0.0) {
      final shearMatrix = Matrix4.identity();
      shearMatrix.setRow(0, Vector4(1.0, shearX, 0.0, 0.0));
      shearMatrix.setRow(1, Vector4(shearY, 1.0, 0.0, 0.0));
      matrix.multiply(shearMatrix);
    }

    // Center the image
    matrix.translate(-size.width / 2, -size.height / 2);

    return matrix;
  }

  /// Calculate lighting adjustment
  static double calculateLightingAdjustment(double avgPixelBrightness) {
    // Normalize brightness (0-1 range)
    final normalizedBrightness = avgPixelBrightness.clamp(0.0, 1.0);

    // Calculate adjustment factor
    // Dark images (< 0.3) need more boost
    if (normalizedBrightness < 0.3) {
      return 1.0 + (0.3 - normalizedBrightness) * 2;
    }
    // Bright images (> 0.7) need reduction
    else if (normalizedBrightness > 0.7) {
      return 1.0 - (normalizedBrightness - 0.7) * 0.5;
    }

    return 1.0;
  }

  /// Generate debug information string
  static String generateDebugInfo(ARPose pose, double processingTime, int fps) {
    return '''
AR Debug Info:
├─ Pose Confidence: ${(pose.confidence * 100).toStringAsFixed(1)}%
├─ Shoulder Distance: ${pose.shoulderDistance.toStringAsFixed(1)}px
├─ Torso Height: ${pose.torsoHeight.toStringAsFixed(1)}px
├─ Rotation: ${(pose.shoulderAngle * 180 / math.pi).toStringAsFixed(1)}°
├─ View: ${pose.isFacingFront ? 'Front' : 'Back'}
├─ Processing Time: ${processingTime.toStringAsFixed(1)}ms
├─ FPS: ${fps.toStringAsFixed(1)}
├─ Landmarks Detected: ${pose.landmarks.length}
└─ Valid for AR: ${isPoseValidForAR(pose)}
''';
  }
}