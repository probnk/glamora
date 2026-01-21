class ARConstants {
  // Performance settings
  static const int poseDetectionInterval = 4; // Process every 4th frame
  static const double minPoseConfidence = 0.5;
  static const double minLandmarkConfidence = 0.3;
  static const int maxFrameSkip = 10;

  // Image scaling factors
  static const double shirtWidthMultiplier = 1.6;
  static const double shirtHeightMultiplier = 2.2;
  static const double shirtVerticalOffset = 0.3;

  // AR calibration
  static const double calibrationThreshold = 0.7;
  static const int calibrationFrames = 30;

  // Camera settings
  static const int cameraResolutionPreset = 1; // 0=low, 1=medium, 2=high
  static const bool enableTorchByDefault = false;

  // Cache settings
  static const int maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const Duration cacheDuration = Duration(hours: 24);

  // Debug settings
  static const bool enableDebugMode = false;
  static const bool showPosePoints = false;
  static const bool showPerformanceOverlay = false;

  // UI constants
  static const Duration loadingTimeout = Duration(seconds: 10);
  static const Duration animationDuration = Duration(milliseconds: 300);

  // Error messages
  static const String noPoseDetected = 'Please stand in frame and ensure good lighting';
  static const String loadingImages = 'Preparing AR experience...';
  static const String cameraError = 'Unable to access camera. Please check permissions';
  static const String lowMemoryWarning = 'Low memory detected. Reducing quality...';

  // File extensions
  static const List<String> supportedImageFormats = ['.png', '.jpg', '.jpeg'];
  static const String pngExtension = '.png';
}