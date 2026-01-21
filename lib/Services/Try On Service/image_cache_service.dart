import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/ar_constants.dart';

class ImageCacheService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final BaseCacheManager _cacheManager = DefaultCacheManager();
  final Map<String, ui.Image> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final SharedPreferences? _prefs;

  int _totalCacheSize = 0;
  bool _isLowMemoryMode = false;

  ImageCacheService() : _prefs = null;

  Future<ui.Image> loadImage(
      String url, {
        int? maxWidth,
        int? maxHeight,
        bool forceRefresh = false,
      }) async {
    try {
      // Check memory cache first
      if (!forceRefresh && _memoryCache.containsKey(url)) {
        final cachedImage = _memoryCache[url]!;
        _updateCacheTimestamp(url);
        return cachedImage;
      }

      // Check disk cache
      final file = await _cacheManager.getSingleFile(url);
      Uint8List imageBytes;

      if (await file.exists() && !forceRefresh) {
        imageBytes = await file.readAsBytes();
      } else {
        // Download from Firebase Storage
        imageBytes = await _downloadFromFirebase(url);

        // Cache to disk
        await _cacheManager.putFile(url, imageBytes);
      }

      // Decode and resize image
      final decodedImage = await _decodeAndResizeImage(
        imageBytes,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      // Cache in memory
      await _cacheInMemory(url, decodedImage);

      return decodedImage;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading image $url: $e');
      }
      rethrow;
    }
  }

  Future<Uint8List> _downloadFromFirebase(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      final downloadTask = ref.getData();

      // Add timeout
      final imageBytes = await downloadTask.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Image download timed out');
        },
      );

      if (imageBytes == null || imageBytes.isEmpty) {
        throw Exception('Downloaded image is empty');
      }

      return imageBytes;
    } catch (e) {
      if (kDebugMode) {
        print('Firebase download error: $e');
      }
      rethrow;
    }
  }

  Future<ui.Image> _decodeAndResizeImage(
      Uint8List bytes, {
        int? maxWidth,
        int? maxHeight,
      }) async {
    // Decode using image package first for resizing
    final decodedImage = img.decodeImage(bytes);

    if (decodedImage == null) {
      throw Exception('Failed to decode image');
    }

    // Resize if needed
    img.Image? resizedImage = decodedImage;

    if (maxWidth != null || maxHeight != null) {
      final targetWidth = maxWidth ?? decodedImage.width;
      final targetHeight = maxHeight ?? decodedImage.height;

      // Calculate aspect ratio preserving dimensions
      final aspectRatio = decodedImage.width / decodedImage.height;
      int newWidth, newHeight;

      if (targetWidth! / aspectRatio <= targetHeight!) {
        newWidth = targetWidth;
        newHeight = (targetWidth / aspectRatio).toInt();
      } else {
        newHeight = targetHeight;
        newWidth = (targetHeight * aspectRatio).toInt();
      }

      // Only resize if significantly smaller
      if (newWidth < decodedImage.width * 0.9 || newHeight < decodedImage.height * 0.9) {
        resizedImage = img.copyResize(
          decodedImage,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // Convert to UI Image
    final codec = await ui.instantiateImageCodec(
      Uint8List.fromList(img.encodePng(resizedImage)),
    );

    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<void> _cacheInMemory(String url, ui.Image image) async {
    final imageSize = _estimateImageSize(image);

    // Check if we need to clear cache due to memory constraints
    if (_totalCacheSize + imageSize > ARConstants.maxCacheSize || _isLowMemoryMode) {
      _clearOldestCacheItems();
    }

    // Add to cache
    _memoryCache[url] = image;
    _cacheTimestamps[url] = DateTime.now();
    _totalCacheSize += imageSize;

    if (kDebugMode) {
      print('Cached image: $url (${imageSize / 1024}KB)');
      print('Total cache size: ${_totalCacheSize / 1024 / 1024}MB');
    }
  }

  int _estimateImageSize(ui.Image image) {
    return image.width * image.height * 4; // RGBA = 4 bytes per pixel
  }

  void _clearOldestCacheItems() {
    if (_memoryCache.isEmpty) return;

    // Sort by timestamp
    final sortedEntries = _cacheTimestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Remove oldest items until we're under limit
    final targetSize = ARConstants.maxCacheSize * 0.7; // Clear down to 70%

    while (_totalCacheSize > targetSize && sortedEntries.isNotEmpty) {
      final oldest = sortedEntries.removeAt(0);
      final image = _memoryCache[oldest.key];

      if (image != null) {
        final imageSize = _estimateImageSize(image);
        _memoryCache.remove(oldest.key);
        _cacheTimestamps.remove(oldest.key);
        _totalCacheSize -= imageSize;

        if (kDebugMode) {
          print('Removed from cache: ${oldest.key}');
        }
      }
    }
  }

  void _updateCacheTimestamp(String url) {
    _cacheTimestamps[url] = DateTime.now();
  }

  void setLowMemoryMode(bool enabled) {
    _isLowMemoryMode = enabled;
    if (enabled) {
      clearCache();
    }
  }

  void clearCache() {
    _memoryCache.clear();
    _cacheTimestamps.clear();
    _totalCacheSize = 0;

    // Clear disk cache
    _cacheManager.emptyCache();

    if (kDebugMode) {
      print('Image cache cleared');
    }
  }

  Future<void> preloadImages(List<String> urls) async {
    try {
      final futures = urls.map((url) => loadImage(
        url,
        maxWidth: 512,
        maxHeight: 512,
      ));

      await Future.wait(futures, eagerError: true);

      if (kDebugMode) {
        print('Preloaded ${urls.length} images');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading images: $e');
      }
    }
  }

  Future<void> dispose() async {
    clearCache();
  }
}