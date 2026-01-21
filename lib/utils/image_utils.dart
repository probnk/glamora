import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ImageUtils {
  /// Convert image bytes to UI Image
  static Future<ui.Image> bytesToUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Convert UI Image to bytes
  static Future<Uint8List> uiImageToBytes(ui.Image image, {ui.ImageByteFormat format = ui.ImageByteFormat.png}) async {
    final byteData = await image.toByteData(format: format);
    return byteData!.buffer.asUint8List();
  }

  /// Resize image maintaining aspect ratio
  static Future<ui.Image> resizeImage(
      ui.Image originalImage,
      int targetWidth,
      int targetHeight, {
        double quality = 0.9,
      }) async {
    // Convert UI Image to bytes
    final originalBytes = await uiImageToBytes(originalImage);

    // Decode using image package
    final decodedImage = img.decodeImage(originalBytes);
    if (decodedImage == null) throw Exception('Failed to decode image');

    // Calculate aspect ratio preserving dimensions
    final aspectRatio = originalImage.width / originalImage.height;
    int newWidth, newHeight;

    if (targetWidth / aspectRatio <= targetHeight) {
      newWidth = targetWidth;
      newHeight = (targetWidth / aspectRatio).toInt();
    } else {
      newHeight = targetHeight;
      newWidth = (targetHeight * aspectRatio).toInt();
    }

    // Resize image
    final resizedImage = img.copyResize(
      decodedImage,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.cubic,
    );

    // Apply compression if needed
    if (quality < 1.0) {
      final compressedBytes = img.encodeJpg(resizedImage, quality: (quality * 100).toInt());
      return bytesToUiImage(Uint8List.fromList(compressedBytes));
    }

    final pngBytes = img.encodePng(resizedImage);
    return bytesToUiImage(Uint8List.fromList(pngBytes));
  }

  /// Crop image to specific region
  static Future<ui.Image> cropImage(
      ui.Image originalImage,
      Rect cropRect,
      ) async {
    final originalBytes = await uiImageToBytes(originalImage);
    final decodedImage = img.decodeImage(originalBytes);
    if (decodedImage == null) throw Exception('Failed to decode image');

    // Ensure crop rect is within image bounds
    final x = cropRect.left.toInt().clamp(0, originalImage.width);
    final y = cropRect.top.toInt().clamp(0, originalImage.height);
    final width = cropRect.width.toInt().clamp(1, originalImage.width - x);
    final height = cropRect.height.toInt().clamp(1, originalImage.height - y);

    final croppedImage = img.copyCrop(
      decodedImage,
      x: x,
      y: y,
      width: width,
      height: height,
    );

    final croppedBytes = img.encodePng(croppedImage);
    return bytesToUiImage(Uint8List.fromList(croppedBytes));
  }

  /// Apply transparency to PNG image
  static Future<ui.Image> applyTransparency(
      ui.Image originalImage,
      double transparency,
      ) async {
    final originalBytes = await uiImageToBytes(originalImage);
    final decodedImage = img.decodeImage(originalBytes);
    if (decodedImage == null) throw Exception('Failed to decode image');

    // Apply transparency to each pixel
    for (int y = 0; y < decodedImage.height; y++) {
      for (int x = 0; x < decodedImage.width; x++) {
        final pixel = decodedImage.getPixel(x, y);
        final alpha = (img.uint32ToAlpha(pixel as int) * transparency).toInt();
        decodedImage.setPixel(x, y, pixel);
      }
    }

    final transparentBytes = img.encodePng(decodedImage);
    return bytesToUiImage(Uint8List.fromList(transparentBytes));
  }

  /// Blend two images together
  static Future<ui.Image> blendImages(
      ui.Image backgroundImage,
      ui.Image foregroundImage,
      double blendOpacity,
      Offset position,
      ) async {
    // Create a recorder to draw both images
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Draw background
    canvas.drawImage(
      backgroundImage,
      Offset.zero,
      Paint(),
    );

    // Draw foreground with opacity
    canvas.drawImage(
      foregroundImage,
      position,
      Paint()..colorFilter = ColorFilter.mode(
        Colors.white.withOpacity(blendOpacity),
        BlendMode.modulate,
      ),
    );

    final picture = recorder.endRecording();
    return await picture.toImage(
      backgroundImage.width,
      backgroundImage.height,
    );
  }

  /// Create image with rounded corners
  static Future<ui.Image> createRoundedImage(
      ui.Image originalImage,
      double borderRadius,
      ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final size = Size(originalImage.width.toDouble(), originalImage.height.toDouble());

    // Create rounded rectangle clip
    final clipPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(borderRadius),
        ),
      );

    canvas.clipPath(clipPath);
    canvas.drawImage(originalImage, Offset.zero, Paint());

    final picture = recorder.endRecording();
    return await picture.toImage(
      originalImage.width,
      originalImage.height,
    );
  }

  /// Apply color filter to image
  static Future<ui.Image> applyColorFilter(
      ui.Image originalImage,
      Color color,
      double intensity,
      ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Create color filter
    final colorFilter = ColorFilter.matrix([
      1, 0, 0, 0, color.red * intensity,
      0, 1, 0, 0, color.green * intensity,
      0, 0, 1, 0, color.blue * intensity,
      0, 0, 0, 1, 0,
    ]);

    canvas.drawImage(
      originalImage,
      Offset.zero,
      Paint()..colorFilter = colorFilter,
    );

    final picture = recorder.endRecording();
    return await picture.toImage(
      originalImage.width,
      originalImage.height,
    );
  }

  /// Create shadow effect for image
  static Future<ui.Image> addShadow(
      ui.Image originalImage,
      {
        double blurRadius = 10.0,
        Color shadowColor = Colors.black,
        double opacity = 0.5,
        Offset offset = const Offset(0, 4),
      }
      ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final size = Size(originalImage.width.toDouble(), originalImage.height.toDouble());

    // Draw shadow first
    final shadowPaint = Paint()
      ..color = shadowColor.withOpacity(opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);

    canvas.drawImage(
      originalImage,
      offset,
      shadowPaint,
    );

    // Draw original image on top
    canvas.drawImage(originalImage, Offset.zero, Paint());

    final picture = recorder.endRecording();
    return await picture.toImage(
      originalImage.width,
      originalImage.height,
    );
  }

  /// Extract dominant color from image
  static Future<Color> getDominantColor(ui.Image image) async {
    final bytes = await uiImageToBytes(image);
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) return Colors.grey;

    // Simple color sampling
    int totalR = 0, totalG = 0, totalB = 0;
    int sampleCount = 0;
    final sampleStep = math.max(1, decodedImage.width ~/ 20);

    for (int y = 0; y < decodedImage.height; y += sampleStep) {
      for (int x = 0; x < decodedImage.width; x += sampleStep) {
        final pixel = decodedImage.getPixel(x, y);
        totalR += img.uint32ToRed(pixel as int);
        totalG += img.uint32ToGreen(pixel as int);
        totalB += img.uint32ToBlue(pixel as int);
        sampleCount++;
      }
    }

    if (sampleCount == 0) return Colors.grey;

    return Color.fromRGBO(
      totalR ~/ sampleCount,
      totalG ~/ sampleCount,
      totalB ~/ sampleCount,
      1.0,
    );
  }

  /// Create gradient overlay
  static Future<ui.Image> addGradientOverlay(
      ui.Image originalImage,
      List<Color> gradientColors,
      AlignmentGeometry begin,
      AlignmentGeometry end,
      double opacity,
      ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final size = Size(originalImage.width.toDouble(), originalImage.height.toDouble());

    // Draw original image
    canvas.drawImage(originalImage, Offset.zero, Paint());

    // Draw gradient overlay
    final gradient = LinearGradient(
      colors: gradientColors,
      begin: begin,
      end: end,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = gradient
        ..blendMode = BlendMode.overlay
        ..color = Colors.white.withOpacity(opacity),
    );

    final picture = recorder.endRecording();
    return await picture.toImage(
      originalImage.width,
      originalImage.height,
    );
  }

  /// Compress image for network transmission
  static Future<Uint8List> compressImageForUpload(
      Uint8List originalBytes, {
        int maxWidth = 1024,
        int maxHeight = 1024,
        int quality = 85,
      }) async {
    final decodedImage = img.decodeImage(originalBytes);
    if (decodedImage == null) return originalBytes;

    // Calculate new dimensions maintaining aspect ratio
    final aspectRatio = decodedImage.width / decodedImage.height;
    int newWidth = decodedImage.width;
    int newHeight = decodedImage.height;

    if (newWidth > maxWidth) {
      newWidth = maxWidth;
      newHeight = (newWidth / aspectRatio).toInt();
    }

    if (newHeight > maxHeight) {
      newHeight = maxHeight;
      newWidth = (newHeight * aspectRatio).toInt();
    }

    // Resize if needed
    img.Image resizedImage = decodedImage;
    if (newWidth != decodedImage.width || newHeight != decodedImage.height) {
      resizedImage = img.copyResize(
        decodedImage,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.cubic,
      );
    }

    // Compress as JPEG
    return Uint8List.fromList(img.encodeJpg(resizedImage, quality: quality));
  }

  /// Create placeholder image with text
  static Future<ui.Image> createPlaceholderImage({
    required int width,
    required int height,
    String text = 'Loading...',
    Color backgroundColor = Colors.grey,
    Color textColor = Colors.white,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = backgroundColor,
    );

    // Draw text
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    return await picture.toImage(width, height);
  }

  /// Check if image is mostly transparent
  static Future<bool> isImageMostlyTransparent(ui.Image image) async {
    final bytes = await uiImageToBytes(image);
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) return false;

    int transparentPixels = 0;
    int totalPixels = decodedImage.width * decodedImage.height;
    const sampleStep = 4; // Sample every 4th pixel for performance

    for (int y = 0; y < decodedImage.height; y += sampleStep) {
      for (int x = 0; x < decodedImage.width; x += sampleStep) {
        final pixel = decodedImage.getPixel(x, y);
        if (img.uint32ToAlpha(pixel as int) < 10) {
          transparentPixels++;
        }
      }
    }

    final sampleCount = (totalPixels / (sampleStep * sampleStep)).ceil();
    final transparencyRatio = transparentPixels / sampleCount;

    return transparencyRatio > 0.7;
  }

  /// Calculate image brightness
  static Future<double> calculateImageBrightness(ui.Image image) async {
    final bytes = await uiImageToBytes(image);
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) return 0.5;

    double totalBrightness = 0;
    int sampleCount = 0;
    const sampleStep = 8;

    for (int y = 0; y < decodedImage.height; y += sampleStep) {
      for (int x = 0; x < decodedImage.width; x += sampleStep) {
        final pixel = decodedImage.getPixel(x, y);
        final r = img.uint32ToRed(pixel as int) / 255.0;
        final g = img.uint32ToGreen(pixel as int) / 255.0;
        final b = img.uint32ToBlue(pixel as int) / 255.0;

        // Calculate perceived brightness
        final brightness = 0.299 * r + 0.587 * g + 0.114 * b;
        totalBrightness += brightness;
        sampleCount++;
      }
    }

    return sampleCount > 0 ? totalBrightness / sampleCount : 0.5;
  }
}