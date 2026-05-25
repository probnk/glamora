// lib/providers/virtual_tryon_provider.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum TryOnState {
  idle,
  pickingImage,
  generatingImage,
  imageReady,
  generatingVideo,
  videoReady,
  error,
}

class VirtualTryOnProvider extends ChangeNotifier {
  TryOnState _state = TryOnState.idle;
  TryOnState get state => _state;

  File? _userImage;
  File? get userImage => _userImage;

  Uint8List? _generatedImage;
  Uint8List? get generatedImage => _generatedImage;

  Uint8List? _videoBytes;
  Uint8List? get videoBytes => _videoBytes;

  String? _generatedVideoUrl;
  String? get generatedVideoUrl => _generatedVideoUrl;

  String _processingStage = '';
  String get processingStage => _processingStage;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  double _videoProgress = 0.0;
  double get videoProgress => _videoProgress;

  bool get isGeneratingImage => _state == TryOnState.generatingImage;
  bool get isGeneratingVideo => _state == TryOnState.generatingVideo;
  bool get isProcessing =>
      _state == TryOnState.generatingImage ||
          _state == TryOnState.generatingVideo;
  bool get hasImage => _generatedImage != null;
  bool get hasVideo => _state == TryOnState.videoReady;

  final ImagePicker _picker = ImagePicker();

  void reset() {
    _state = TryOnState.idle;
    _userImage = null;
    _generatedImage = null;
    _generatedVideoUrl = null;
    _videoBytes = null;
    _processingStage = '';
    _errorMessage = '';
    _videoProgress = 0.0;
    notifyListeners();
  }

  void resetToImageReady() {
    _state = TryOnState.imageReady;
    _generatedVideoUrl = null;
    _videoBytes = null;
    _videoProgress = 0.0;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  Future<void> pickImage({
    required ImageSource source,
    required String clothImageUrl,
    required String category,
  }) async {
    try {
      _state = TryOnState.pickingImage;
      notifyListeners();

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        _state = TryOnState.idle;
        notifyListeners();
        return;
      }

      _userImage = File(pickedFile.path);
      _generatedImage = null;
      _generatedVideoUrl = null;
      _videoBytes = null;
      notifyListeners();

      await generateImage(clothImageUrl: clothImageUrl, category: category);
    } catch (e) {
      _setError('Failed to pick image: $e');
    }
  }

  Future<void> generateImage({
    required String clothImageUrl,
    required String category,
  }) async {
    if (_userImage == null) {
      _setError('Please select your photo first');
      return;
    }

    _state = TryOnState.generatingImage;
    _processingStage = 'Initializing FASHN AI...';
    notifyListeners();

    try {
      _setStage('Loading your photo...');
      await Future.delayed(const Duration(milliseconds: 500));

      final userImageBytes = await _userImage!.readAsBytes();
      final userBase64 =
          'data:image/jpeg;base64,${base64Encode(userImageBytes)}';

      _setStage('Preparing clothing item...');
      await Future.delayed(const Duration(milliseconds: 500));

      _setStage('AI analyzing your body shape...');
      await Future.delayed(const Duration(milliseconds: 700));

      _setStage('Fitting clothing precisely...\n(5–17 seconds)');

      final String mappedCategory =
      (category == "T-Shirt" || category == "Hoodie") ? "tops" : "bottoms";

      final response = await Supabase.instance.client.functions.invoke(
        'tryon',
        body: {
          "userImage": userBase64,
          "clothImage": clothImageUrl,
          "category": mappedCategory,
          "prompt": "",
        },
      );

      if (response.status != 200) {
        final errData = response.data;
        final errMsg = (errData is Map ? errData['error'] : null) ??
            'Server error ${response.status}';
        throw Exception(errMsg);
      }

      _setStage('Finalizing your look...');
      await Future.delayed(const Duration(milliseconds: 300));

      final Map<String, dynamic> responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      final String? imageData = responseData['image'] as String?;
      if (imageData == null || imageData.isEmpty) {
        throw Exception('No image was generated. Please try again.');
      }

      Uint8List imageBytes;
      if (imageData.startsWith('data:')) {
        imageBytes = base64Decode(imageData.split(',').last);
      } else {
        imageBytes = base64Decode(imageData);
      }

      _generatedImage = imageBytes;
      _state = TryOnState.imageReady;
      _processingStage = '';
      notifyListeners();
    } on FunctionException catch (e) {
      _setError(
          'Image generation failed: ${e.reasonPhrase ?? e.details?.toString() ?? e.toString()}');
    } catch (e) {
      _setError('AI image generation failed: $e');
    }
  }

  // ── Generate Video ────────────────────────────────────────────────────────
  // NO STORAGE NEEDED.
  // The generated try-on image (Uint8List) is sent as base64 directly
  // to the edge function. Edge function passes it to FASHN image-to-video.
  Future<void> generateVideo({
    required String clothImageUrl,
    required String productTitle,
    required String category,
  }) async {
    if (_generatedImage == null) {
      _setError('Generate try-on image first');
      return;
    }

    _state = TryOnState.generatingVideo;
    _videoProgress = 0.0;
    _errorMessage = '';
    _setStage('Preparing video...');
    notifyListeners();

    try {
      // Encode the generated try-on image as base64 data URL
      _setStage('Encoding image...');
      _updateProgress(0.08);

      final String imageBase64 =
          'data:image/png;base64,${base64Encode(_generatedImage!)}';

      debugPrint('[TryOn-Video] Base64 length: ${imageBase64.length}');

      final String mappedCategory =
      (category == "T-Shirt" || category == "Hoodie") ? "tops" : "bottoms";

      _setStage('Sending to FASHN Video AI...\n(~30–60 seconds)');
      _updateProgress(0.15);
      _startFakeProgress();

      debugPrint('[TryOn-Video] Invoking tryon-video edge function...');

      final response = await Supabase.instance.client.functions
          .invoke(
        'tryon_video',
        body: {
          "modelImage": imageBase64,
          "category": mappedCategory,
          "productTitle": productTitle,
          "resolution": "720p",
          "duration": 5,
        },
      )
          .timeout(
        const Duration(seconds: 210),
        onTimeout: () =>
        throw Exception('Timed out after 210s. Please retry.'),
      );

      debugPrint('[TryOn-Video] Status: ${response.status}');

      if (response.status != 200) {
        String errMsg = 'Server error ${response.status}';
        try {
          final d = response.data;
          if (d is Map) {
            errMsg =
                d['error']?.toString() ?? d['message']?.toString() ?? errMsg;
          } else if (d is String && d.isNotEmpty) {
            errMsg =
                (jsonDecode(d) as Map)['error']?.toString() ?? errMsg;
          }
        } catch (_) {}
        throw Exception(errMsg);
      }

      // Parse response
      Map<String, dynamic> responseData;
      if (response.data is String) {
        responseData = jsonDecode(response.data as String);
      } else if (response.data is Map) {
        responseData = Map<String, dynamic>.from(response.data as Map);
      } else {
        throw Exception(
            'Unexpected response type: ${response.data.runtimeType}');
      }

      final String? videoUrl = responseData['videoUrl'] as String?;
      final String? videoBase64 = responseData['videoBase64'] as String?;

      debugPrint('[TryOn-Video] videoUrl: $videoUrl');

      if ((videoUrl == null || videoUrl.isEmpty) &&
          (videoBase64 == null || videoBase64.isEmpty)) {
        throw Exception(
            'No video returned. Keys: ${responseData.keys.toList()}');
      }

      if (videoBase64 != null && videoBase64.isNotEmpty) {
        final base64Str = videoBase64.startsWith('data:')
            ? videoBase64.split(',').last
            : videoBase64;
        _videoBytes = base64Decode(base64Str);
      }

      _generatedVideoUrl = videoUrl;
      _videoProgress = 1.0;
      _state = TryOnState.videoReady;
      _processingStage = '';

      debugPrint('[TryOn-Video] ✅ Video ready: $videoUrl');
      notifyListeners();
    } on FunctionException catch (e) {
      debugPrint(
          '[TryOn-Video] ❌ FunctionException: ${e.status} | ${e.reasonPhrase} | ${e.details}');

      String errorMsg = 'Video failed.';
      if (e.reasonPhrase != null && e.reasonPhrase!.isNotEmpty) {
        errorMsg = e.reasonPhrase!;
      } else if (e.details != null) {
        try {
          final d = e.details;
          errorMsg = (d is Map)
              ? (d['error']?.toString() ??
              d['message']?.toString() ??
              errorMsg)
              : d.toString();
        } catch (_) {
          errorMsg = e.details.toString();
        }
      }

      _state = TryOnState.imageReady;
      _processingStage = '';
      _errorMessage = 'Video error: $errorMsg';
      notifyListeners();
    } catch (e) {
      debugPrint('[TryOn-Video] ❌ Error: $e');
      _state = TryOnState.imageReady;
      _processingStage = '';
      _errorMessage =
      'Video failed: ${e.toString().replaceAll('Exception: ', '')}';
      notifyListeners();
    }
  }

  // ── Smooth progress animation while edge function polls FASHN ─────────────
  void _startFakeProgress() {
    Future.doWhile(() async {
      if (_state != TryOnState.generatingVideo) return false;
      if (_videoProgress >= 0.88) return false;
      await Future.delayed(const Duration(seconds: 3));
      if (_state != TryOnState.generatingVideo) return false;
      _videoProgress = (_videoProgress + 0.035).clamp(0.0, 0.88);

      if (_videoProgress < 0.35) {
        _processingStage = 'FASHN AI processing...\n(~30–60 seconds)';
      } else if (_videoProgress < 0.65) {
        _processingStage = 'Generating video frames...';
      } else {
        _processingStage = 'Almost ready...';
      }

      notifyListeners();
      return true;
    });
  }

  void _setStage(String stage) {
    _processingStage = stage;
    notifyListeners();
  }

  void _updateProgress(double value) {
    _videoProgress = value;
    notifyListeners();
  }

  void _setError(String message) {
    _state = TryOnState.error;
    _errorMessage = message;
    _processingStage = '';
    notifyListeners();
  }
}