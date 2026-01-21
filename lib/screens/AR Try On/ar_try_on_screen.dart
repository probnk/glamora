import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/screens/AR%20Try%20On/widgets/ar_clothing_painter.dart';
import 'package:glamora/screens/AR%20Try%20On/widgets/loading_overlay.dart';
import '../../Services/Try On Service/ar_service.dart';
import '../../constants/ar_constants.dart';
import '../../models/ar_pose.dart';

class ARTryOnScreen extends StatefulWidget {
  final ClothingProductModel product;
  final bool enableDebugMode;

  const ARTryOnScreen({
    Key? key,
    required this.product,
    this.enableDebugMode = false,
  }) : super(key: key);

  @override
  _ARTryOnScreenState createState() => _ARTryOnScreenState();
}

class _ARTryOnScreenState extends State<ARTryOnScreen>
    with WidgetsBindingObserver {
  late ARService _arService;
  ARPose? _currentPose;
  ui.Image? _currentOverlay;
  bool _isLoading = true;
  bool _isCameraReady = false;
  bool _showDebugInfo = false;
  bool _showCalibrationGuide = true;
  bool _isFlashOn = false;
  double _processingTime = 0.0;
  String _statusMessage = ARConstants.loadingImages;
  int _calibrationProgress = 0;
  Timer? _calibrationTimer;
  Timer? _statusTimer;
  StreamSubscription<ARPose?>? _poseSubscription;
  StreamSubscription<ui.Image?>? _overlaySubscription;
  StreamSubscription<double>? _performanceSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAR();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pauseAR();
    } else if (state == AppLifecycleState.resumed) {
      _resumeAR();
    }
  }

  Future<void> _initializeAR() async {
    try {
      _arService = ARService();

      setState(() {
        _statusMessage = 'Initializing AR...';
      });

      // Initialize AR service
      await _arService.initialize(

      );

      // Load product images
      await _arService.loadProductForAR(widget.product);

      // Start listening to pose updates
      _poseSubscription = _arService.poseStream.listen(_onPoseDetected);
      _overlaySubscription =
          _arService.arOverlayStream.listen(_onOverlayGenerated);
      _performanceSubscription =
          _arService.performanceStream.listen(_onPerformanceUpdate);

      setState(() {
        _isLoading = false;
        _isCameraReady = true;
        _statusMessage = 'Ready for AR try-on';
      });

      // Start calibration guide timer
      _startCalibrationGuide();
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to initialize AR: $e';
        _isLoading = false;
      });

      if (ARConstants.enableDebugMode) {
        print('AR initialization error: $e');
      }

      // Show error dialog
      _showErrorDialog('AR Initialization Failed', e.toString());
    }
  }

  void _onPoseDetected(ARPose? pose) {
    if (!mounted) return;

    setState(() {
      _currentPose = pose;

      if (pose != null) {
        _showCalibrationGuide = false;

        // Update calibration progress
        if (_calibrationProgress < 100) {
          _calibrationProgress += 2;
          if (_calibrationProgress > 100) _calibrationProgress = 100;
        }
      } else {
        if (_calibrationProgress > 0) {
          _calibrationProgress -= 1;
          if (_calibrationProgress < 0) _calibrationProgress = 0;
        }
      }
    });
  }

  void _onOverlayGenerated(ui.Image? overlay) {
    if (!mounted) return;

    setState(() {
      _currentOverlay = overlay;
    });
  }

  void _onPerformanceUpdate(double processingTime) {
    if (!mounted) return;

    setState(() {
      _processingTime = processingTime;
    });
  }

  void _startCalibrationGuide() {
    _calibrationTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;

      if (_currentPose != null && _calibrationProgress >= 100) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_currentPose != null && _calibrationProgress < 100) {
          _calibrationProgress += 1;
        } else if (_currentPose == null && _calibrationProgress > 0) {
          _calibrationProgress -= 1;
        }
      });
    });

    // Auto-hide calibration guide after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _showCalibrationGuide) {
        setState(() {
          _showCalibrationGuide = false;
        });
      }
    });
  }

  void _toggleFlash() {
    if (!_arService.isInitialized) return;

    setState(() {
      _isFlashOn = !_isFlashOn;
    });

    _arService.toggleFlash();
  }

  void _toggleDebugInfo() {
    setState(() {
      _showDebugInfo = !_showDebugInfo;
    });
  }

  Future<void> _captureSnapshot() async {
    try {
      setState(() {
        _statusMessage = 'Capturing snapshot...';
      });

      final snapshot = await _arService.captureARSnapshot();

      if (snapshot != null && mounted) {
        // Save or share the snapshot
        await _saveSnapshot(snapshot);

        setState(() {
          _statusMessage = 'Snapshot saved!';
        });

        // Clear status message after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _statusMessage = '';
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to capture snapshot';
      });

      if (ARConstants.enableDebugMode) {
        print('Snapshot capture error: $e');
      }
    }
  }

  Future<void> _saveSnapshot(Uint8List snapshot) async {
    // Implement snapshot saving logic here
    // This could save to gallery, share, or upload to server

    if (ARConstants.enableDebugMode) {
      print('Snapshot captured: ${snapshot.toString()} bytes');
    }

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Snapshot captured successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeAR();
            },
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _pauseAR() {
    _poseSubscription?.pause();
    _overlaySubscription?.pause();
    _performanceSubscription?.pause();
    _calibrationTimer?.cancel();
    _statusTimer?.cancel();
  }

  void _resumeAR() {
    _poseSubscription?.resume();
    _overlaySubscription?.resume();
    _performanceSubscription?.resume();
    _startCalibrationGuide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _poseSubscription?.cancel();
    _overlaySubscription?.cancel();
    _performanceSubscription?.cancel();
    _calibrationTimer?.cancel();
    _statusTimer?.cancel();

    _arService.stop();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview - FIXED: Added camera preview widget
          if (_arService.cameraController != null &&
              _arService.cameraController!.value.isInitialized)
            Positioned.fill(
              child: CameraPreview(_arService.cameraController!),
            ),

          // AR overlay
          if (_currentOverlay != null)
            Positioned.fill(
              child: CustomPaint(
                painter: ARClothingPainter(
                  pose: _currentPose,
                  overlayImage: _currentOverlay,
                  showDebug: _showDebugInfo,
                ),
              ),
            ),

          // Debug overlay
          if (_showDebugInfo && _currentPose != null)
            Positioned.fill(
              child: CustomPaint(
                painter: ARClothingPainter(
                  pose: _currentPose,
                  overlayImage: _currentOverlay,
                  showDebug: _showDebugInfo,
                ),
              ),
            ),

          // Calibration guide
          if (_showCalibrationGuide && _calibrationProgress < 100)
            _buildCalibrationGuide(),

          // Status overlay
          if (_statusMessage.isNotEmpty) _buildStatusOverlay(),

          // Controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _buildTopControls(),
          ),

          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: _buildBottomControls(),
          ),

          // Loading overlay
          if (_isLoading) LoadingOverlay(message: _statusMessage),

          // Performance overlay (debug)
          if (_showDebugInfo) _buildPerformanceOverlay(),
        ],
      ),
    );
  }

  Widget _buildCalibrationGuide() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: _calibrationProgress / 100,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation(Colors.blueAccent),
            ),
            const SizedBox(height: 16),
            Text(
              'Calibrating AR...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ARConstants.noPoseDetected,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '${_calibrationProgress}%',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOverlay() {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_statusMessage.contains('Loading') ||
                  _statusMessage.contains('Preparing'))
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              if (_statusMessage.contains('Loading') ||
                  _statusMessage.contains('Preparing'))
                const SizedBox(width: 12),
              Text(
                _statusMessage,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _switchCamera() async {
    try {
      if (_arService.cameraController == null) return;

      // Get current camera
      final currentDirection = _arService.cameraController!.description.lensDirection;

      // Select opposite camera
      final newCamera = _arService.cameras!.firstWhere(
            (cam) => cam.lensDirection ==
            (currentDirection == CameraLensDirection.back
                ? CameraLensDirection.front
                : CameraLensDirection.back),
      );

      // Restart camera
      await _arService.switchCamera(newCamera);

      setState(() {});
    } catch (e) {
      print("Camera switch error: $e");
    }
  }

  Widget _buildTopControls() {
    return Row(
      children: [
        // Back button
        _buildControlButton(
          icon: Icons.arrow_back_rounded,
          onPressed: () => Navigator.pop(context),
          backgroundColor: Colors.black54,
        ),

        const Spacer(),
        _buildControlButton(
          icon: Icons.cameraswitch_rounded,
          onPressed: _switchCamera,
          backgroundColor: Colors.black54,
        ),
        const Spacer(),
        // Product name
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.product.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const Spacer(),

        // Flash toggle
        _buildControlButton(
          icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
          onPressed: _toggleFlash,
          backgroundColor: Colors.black54,
        ),

        const SizedBox(width: 12),

        // Debug toggle
        if (widget.enableDebugMode)
          _buildControlButton(
            icon: _showDebugInfo ? Icons.visibility : Icons.visibility_off,
            onPressed: _toggleDebugInfo,
            backgroundColor: Colors.black54,
          ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Capture button
        _buildControlButton(
          icon: Icons.camera_alt_rounded,
          onPressed: _captureSnapshot,
          backgroundColor: Colors.blueAccent,
          size: 56,
        ),

        // Calibration status
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _calibrationProgress >= 100 ? Colors.green : Colors.orange,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '${_calibrationProgress}%',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Share button
        _buildControlButton(
          icon: Icons.share_rounded,
          onPressed: () {
            // Implement share functionality
          },
          backgroundColor: Colors.purpleAccent,
        ),
      ],
    );
  }

  Widget _buildPerformanceOverlay() {
    return Positioned(
      top: 100,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildPerformanceMetric(
                'Processing', '${_processingTime.toStringAsFixed(1)}ms'),
            _buildPerformanceMetric(
                'Pose', _currentPose != null ? 'Detected' : 'None'),
            _buildPerformanceMetric('Calibration', '${_calibrationProgress}%'),
            _buildPerformanceMetric(
              'View',
              _currentPose?.isFacingFront == true ? 'Front' : 'Back',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: _getMetricColor(label, value),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getMetricColor(String label, String value) {
    if (label == 'Processing') {
      final time = double.tryParse(value.replaceAll('ms', '')) ?? 0;
      if (time > 50) return Colors.red;
      if (time > 30) return Colors.orange;
      return Colors.green;
    }

    if (label == 'Calibration') {
      final percent = int.tryParse(value.replaceAll('%', '')) ?? 0;
      if (percent >= 100) return Colors.green;
      if (percent >= 70) return Colors.orange;
      return Colors.red;
    }

    return Colors.white;
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color backgroundColor = Colors.black54,
    double size = 48,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
