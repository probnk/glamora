import 'dart:async';
import 'package:flutter/material.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import '../../Services/Try On Service/ar_service.dart';
import '../../models/ar_pose.dart';

class ARCalibrationScreen extends StatefulWidget {
  final ARService arService;
  final Function() onCalibrationComplete;
  final Function()? onSkip;

  const ARCalibrationScreen({
    Key? key,
    required this.arService,
    required this.onCalibrationComplete,
    this.onSkip,
  }) : super(key: key);

  @override
  _ARCalibrationScreenState createState() => _ARCalibrationScreenState();
}

class _ARCalibrationScreenState extends State<ARCalibrationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  int _calibrationStep = 0;
  int _framesCollected = 0;
  int _framesRequired = 30;
  double _calibrationProgress = 0.0;
  ARPose? _currentPose;
  bool _isCalibrating = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<String> _calibrationSteps = [
    'Finding your position...',
    'Measuring shoulder width...',
    'Calculating torso height...',
    'Analyzing posture...',
    'Finalizing calibration...',
  ];

  Timer? _calibrationTimer;
  Timer? _poseCheckTimer;
  StreamSubscription<ARPose?>? _poseSubscription;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _startCalibration();
  }

  void _startCalibration() async {
    try {
      // Start listening to pose updates
      _poseSubscription = widget.arService.poseStream.listen(_onPoseUpdate);

      // Start calibration timer
      _calibrationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!_isCalibrating) {
          timer.cancel();
          return;
        }

        setState(() {
          if (_framesCollected < _framesRequired) {
            _calibrationProgress = _framesCollected / _framesRequired;
            _calibrationStep = (_calibrationProgress * (_calibrationSteps.length - 1)).floor();
          } else {
            _calibrationProgress = 1.0;
            _calibrationStep = _calibrationSteps.length - 1;
            _completeCalibration();
          }
        });
      });

      // Start pose check timer
      _poseCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (_currentPose == null && _framesCollected == 0) {
          setState(() {
            _hasError = true;
            _errorMessage = 'No person detected. Please stand in frame.';
          });
        } else if (_currentPose != null && _hasError) {
          setState(() {
            _hasError = false;
            _errorMessage = '';
          });
        }
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Calibration failed: ${e.toString()}';
        _isCalibrating = false;
      });
    }
  }

  void _onPoseUpdate(ARPose? pose) {
    if (!mounted) return;

    setState(() {
      _currentPose = pose;

      if (pose != null && pose.isValidForAR) {
        if (_framesCollected < _framesRequired) {
          _framesCollected++;
        }

        if (_hasError) {
          _hasError = false;
          _errorMessage = '';
        }
      }
    });
  }

  void _completeCalibration() {
    if (!_isCalibrating) return;

    _isCalibrating = false;
    _calibrationTimer?.cancel();
    _poseCheckTimer?.cancel();

    // Show completion animation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        widget.onCalibrationComplete();
      }
    });
  }

  void _skipCalibration() {
    _isCalibrating = false;
    _calibrationTimer?.cancel();
    _poseCheckTimer?.cancel();
    _poseSubscription?.cancel();

    widget.onSkip?.call();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _calibrationTimer?.cancel();
    _poseCheckTimer?.cancel();
    _poseSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [
                  Colors.blueGrey[900]!,
                  Colors.black,
                ],
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                Text(
                  'AR CALIBRATION',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'For accurate virtual try-on',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 40),

                // Calibration animation
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blueAccent.withOpacity(0.3),
                        width: 3,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer ring
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.blueAccent.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                        ),

                        // Middle ring
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.blueAccent.withOpacity(0.7),
                              width: 2,
                            ),
                          ),
                        ),

                        // Inner circle with pose visualization
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blueAccent.withOpacity(0.1),
                          ),
                          child: _buildPoseVisualization(),
                        ),

                        // Progress indicator
                        CircularProgressIndicator(
                          value: _calibrationProgress,
                          backgroundColor: Colors.grey[800],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _hasError ? Colors.red : Colors.blueAccent,
                          ),
                          strokeWidth: 4,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Current step
                AnimatedOpacity(
                  opacity: _opacityAnimation.value,
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _calibrationSteps[_calibrationStep],
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 8),

                // Progress text
                Text(
                  '${_framesCollected}/$_framesRequired frames collected',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white60,
                  ),
                ),

                const SizedBox(height: 24),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blueAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Instructions',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInstructions(),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Error message
                if (_hasError)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Skip button (only visible in first 5 seconds)
                if (_framesCollected < 5)
                  TextButton(
                    onPressed: _skipCalibration,
                    child: Text(
                      'Skip Calibration',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                  ),

                const Spacer(),

                // Tips
                _buildCalibrationTips(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoseVisualization() {
    if (_currentPose == null) {
      return Icon(
        Icons.person_outline,
        color: Colors.white30,
        size: 40,
      );
    }

    return CustomPaint(
      painter: _PoseVisualizationPainter(pose: _currentPose!),
    );
  }

  Widget _buildInstructions() {
    final instructions = [
      'Stand 2-3 meters away from camera',
      'Keep your full body in frame',
      'Stand with arms at your sides',
      'Face the camera directly',
      'Stay still during calibration',
      'Ensure good lighting',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: instructions.map((instruction) {
        return Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle,
                color: _currentPose != null ? Colors.green : Colors.grey,
                size: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: smallFont(text: instruction,color: Colors.white70)
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalibrationTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blueAccent.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Colors.amber,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                mediumFont(text: 'Why calibration is important:',color: white, weight: FontWeight.w600),
                const SizedBox(height: 4),
                mediumFont(text: 'Calibration ensures the virtual clothing fits your body perfectly by measuring your exact proportions.',color: Colors.white70)
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PoseVisualizationPainter extends CustomPainter {
  final ARPose pose;

  _PoseVisualizationPainter({required this.pose});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw body outline
    final bodyPaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Simple body visualization
    if (pose.leftShoulder != null && pose.rightShoulder != null) {
      final shoulderWidth = pose.shoulderDistance;
      final scale = 40 / shoulderWidth; // Scale to fit in 100px circle

      // Draw shoulders
      final leftShoulder = Offset(
        center.dx - (pose.shoulderDistance / 2) * scale,
        center.dy - 10,
      );

      final rightShoulder = Offset(
        center.dx + (pose.shoulderDistance / 2) * scale,
        center.dy - 10,
      );

      canvas.drawLine(leftShoulder, rightShoulder, bodyPaint);

      // Draw torso
      if (pose.torsoHeight > 0) {
        final torsoBottom = Offset(center.dx, center.dy + pose.torsoHeight * scale);
        canvas.drawLine(center, torsoBottom, bodyPaint);
      }

      // Draw hips
      if (pose.leftHip != null && pose.rightHip != null) {
        final leftHip = Offset(leftShoulder.dx, center.dy + pose.torsoHeight * scale);
        final rightHip = Offset(rightShoulder.dx, center.dy + pose.torsoHeight * scale);
        canvas.drawLine(leftHip, rightHip, bodyPaint);
      }
    }

    // Draw success indicator when calibration is good
    if (pose.confidence > 0.7) {
      final successPaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, 4, successPaint);
    }
  }

  @override
  bool shouldRepaint(_PoseVisualizationPainter oldDelegate) {
    return pose != oldDelegate.pose;
  }
}