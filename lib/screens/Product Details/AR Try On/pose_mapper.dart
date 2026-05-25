import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseMapper {
  static Offset _toScreen(
      double x,
      double y,
      Size imgSize,
      Size screenSize, {
        bool flipX = false,
      }) {
    final scaleX = screenSize.width / imgSize.width;
    final scaleY = screenSize.height / imgSize.height;
    final scale = scaleX > scaleY ? scaleX : scaleY;
    final ox = (screenSize.width - imgSize.width * scale) / 2;
    final oy = (screenSize.height - imgSize.height * scale) / 2;
    final mappedX = flipX ? (imgSize.width - x) : x;
    return Offset(mappedX * scale + ox, y * scale + oy);
  }

  static Rect? getTopClothingRect({
    required Pose pose,
    required Size imageSize,
    required Size previewSize,
    bool flipX = false,
    double clothingAspectRatio = 0.75,
  }) {
    if (previewSize == Size.zero || imageSize == Size.zero) return null;

    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lh = pose.landmarks[PoseLandmarkType.leftHip];
    final rh = pose.landmarks[PoseLandmarkType.rightHip];

    if (ls == null || rs == null || lh == null || rh == null) return null;
    if (ls.likelihood < 0.65 || rs.likelihood < 0.65 ||
        lh.likelihood < 0.45 || rh.likelihood < 0.45) return null;

    final lsS = _toScreen(ls.x, ls.y, imageSize, previewSize, flipX: flipX);
    final rsS = _toScreen(rs.x, rs.y, imageSize, previewSize, flipX: flipX);
    final lhS = _toScreen(lh.x, lh.y, imageSize, previewSize, flipX: flipX);
    final rhS = _toScreen(rh.x, rh.y, imageSize, previewSize, flipX: flipX);

    final shoulderCenterX = (lsS.dx + rsS.dx) / 2;
    final shoulderCenterY = (lsS.dy + rsS.dy) / 2;
    final hipCenterY = (lhS.dy + rhS.dy) / 2;

    final shoulderWidth = (rsS.dx - lsS.dx).abs();
    final torsoHeight = hipCenterY - shoulderCenterY;

    // --- WIDTH ---
    // 1.20 matches real shirt sleeve width relative to shoulder landmarks.
    // 1.50 was overshooting — sleeves were hanging far past arms.
    // 1.35: wider than 1.20 — shirt sleeves need to cover upper arm, not just shoulder joint
    final shirtWidth = shoulderWidth * 1.35;

    // 0.32: collar needs to sit at neck base — shoulder landmarks are at joint,
    // not neck, so we go further up
    final topY = shoulderCenterY - torsoHeight * 0.32;

    // Hem: hip + 10% torso below hip for natural shirt drape
    final bottomY = hipCenterY + torsoHeight * 0.10;
    final bodyHeight = bottomY - topY;

    // Body height is primary — it's anchored to actual landmark positions.
    // Aspect height is a fallback only when hips aren't detected well (bodyHeight too small).
    final heightFromAspect = shirtWidth / clothingAspectRatio;
    final finalHeight = bodyHeight > heightFromAspect * 0.6
        ? bodyHeight      // trust body landmarks
        : heightFromAspect; // hips unreliable, fall back to aspect

    final left = shoulderCenterX - shirtWidth / 2;
    final right = shoulderCenterX + shirtWidth / 2;
    final bottom = topY + finalHeight;

    return Rect.fromLTRB(
      left.clamp(0.0, previewSize.width),
      topY.clamp(0.0, previewSize.height),
      right.clamp(0.0, previewSize.width),
      bottom.clamp(0.0, previewSize.height),
    );
  }

  static Rect? getBottomClothingRect({
    required Pose pose,
    required Size imageSize,
    required Size previewSize,
    bool flipX = false,
  }) {
    if (previewSize == Size.zero || imageSize == Size.zero) return null;

    final lh = pose.landmarks[PoseLandmarkType.leftHip];
    final rh = pose.landmarks[PoseLandmarkType.rightHip];
    final la = pose.landmarks[PoseLandmarkType.leftAnkle];
    final ra = pose.landmarks[PoseLandmarkType.rightAnkle];
    final lk = pose.landmarks[PoseLandmarkType.leftKnee];
    final rk = pose.landmarks[PoseLandmarkType.rightKnee];

    if (lh == null || rh == null) return null;
    if (lh.likelihood < 0.5 || rh.likelihood < 0.5) return null;

    final lhS = _toScreen(lh.x, lh.y, imageSize, previewSize, flipX: flipX);
    final rhS = _toScreen(rh.x, rh.y, imageSize, previewSize, flipX: flipX);

    final hipWidth = (rhS.dx - lhS.dx).abs();
    final centerX = (lhS.dx + rhS.dx) / 2;

    // Pant waistband starts slightly above hip center
    final topY = (lhS.dy + rhS.dy) / 2 - hipWidth * 0.08;
    final halfWidth = (hipWidth / 2) * 1.18;

    double bottomY;
    if (la != null && ra != null &&
        la.likelihood > 0.4 && ra.likelihood > 0.4) {
      final laS = _toScreen(la.x, la.y, imageSize, previewSize, flipX: flipX);
      final raS = _toScreen(ra.x, ra.y, imageSize, previewSize, flipX: flipX);
      bottomY = (laS.dy + raS.dy) / 2;
    } else if (lk != null && rk != null &&
        lk.likelihood > 0.4 && rk.likelihood > 0.4) {
      final lkS = _toScreen(lk.x, lk.y, imageSize, previewSize, flipX: flipX);
      final rkS = _toScreen(rk.x, rk.y, imageSize, previewSize, flipX: flipX);
      bottomY = topY + ((lkS.dy + rkS.dy) / 2 - topY) * 2.05;
    } else {
      bottomY = topY + hipWidth * 2.6;
    }

    return Rect.fromLTRB(
      (centerX - halfWidth).clamp(0.0, previewSize.width),
      topY.clamp(0.0, previewSize.height),
      (centerX + halfWidth).clamp(0.0, previewSize.width),
      bottomY.clamp(0.0, previewSize.height),
    );
  }

  static const skeletonConnections = [
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
  ];

  static const bodyOnlyLandmarks = [
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftElbow,
    PoseLandmarkType.rightElbow,
    PoseLandmarkType.leftWrist,
    PoseLandmarkType.rightWrist,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
    PoseLandmarkType.leftKnee,
    PoseLandmarkType.rightKnee,
    PoseLandmarkType.leftAnkle,
    PoseLandmarkType.rightAnkle,
  ];
}