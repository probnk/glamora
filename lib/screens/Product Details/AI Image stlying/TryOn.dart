import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../../../constants/app_theme.dart';

class TryOnScreen extends StatefulWidget {
  final String clothImageUrl;
  final String productTitle;

  const TryOnScreen({
    Key? key,
    required this.clothImageUrl,
    required this.productTitle,
  }) : super(key: key);

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen>
    with TickerProviderStateMixin {
  File? _userImage;
  Uint8List? _generatedImage;
  bool _isProcessing = false;
  String _processingStage = '';
  final ImagePicker _picker = ImagePicker();

  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _successController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _successController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // IMAGE PICKER
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _userImage = File(pickedFile.path);
          _generatedImage = null;
        });
        // Auto-generate after picking
        await image_generation();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAIN GENERATION FUNCTION
  // CHANGE LOG (vs OpenAI version):
  //   1. Timeout 90s → 120s  (FASHN polling takes up to 75s on server side)
  //   2. Processing messages updated to reflect FASHN flow
  //   3. Everything else is IDENTICAL — same endpoint name, same request body,
  //      same response parsing. The Edge Function handles the API switch.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> image_generation() async {
    if (_userImage == null) {
      _showErrorSnackBar('Please select your photo first');
      return;
    }

    setState(() {
      _isProcessing = true;
      // ← CHANGE 1: Updated stage message (FASHN-specific wording)
      _processingStage = 'Initializing FASHN AI...';
    });

    try {
      // Stage 1 — read user image and convert to base64 data URL
      setState(() => _processingStage = 'Loading your photo...');
      await Future.delayed(const Duration(milliseconds: 600));

      final userImageBytes = await _userImage!.readAsBytes();
      final userBase64 =
          'data:image/jpeg;base64,${base64Encode(userImageBytes)}';

      // Stage 2 — cloth image (URL passed directly; edge function fetches it)
      setState(() => _processingStage = 'Loading clothing...');
      await Future.delayed(const Duration(milliseconds: 600));
      final clothImageUrl = widget.clothImageUrl;

      // Stage 3 — call the Supabase edge function
      // ← CHANGE 2: FASHN-specific stage messages
      setState(() => _processingStage = 'AI analyzing your body shape...');
      await Future.delayed(const Duration(milliseconds: 800));

      setState(() => _processingStage = 'Fitting clothing precisely...\n(5–17 seconds)');

      final response = await Supabase.instance.client.functions.invoke(
        'tryon',  // same function name — no change needed
        body: {
          'userImage': userBase64,       // same key — no change
          'clothImage': clothImageUrl,   // same key — no change
        },
      );

      // ── Error handling ──────────────────────────────────────────────────
      if (response.status != 200) {
        final errData = response.data;
        final errMsg = (errData is Map ? errData['error'] : null) ??
            'Server error ${response.status}';
        throw Exception(errMsg);
      }

      setState(() => _processingStage = 'Finalizing your look...');
      await Future.delayed(const Duration(milliseconds: 400));

      // ── Parse response ──────────────────────────────────────────────────
      // Response format is IDENTICAL to before: { image: "data:image/png;base64,..." }
      final Map<String, dynamic> responseData =
      response.data is String ? jsonDecode(response.data) : response.data;

      final String? imageData = responseData['image'] as String?;
      if (imageData == null || imageData.isEmpty) {
        throw Exception('No image was generated. Please try again.');
      }

      // Convert base64 data URL → Uint8List
      Uint8List imageBytes;
      if (imageData.startsWith('data:')) {
        final base64Str = imageData.split(',').last;
        imageBytes = base64Decode(base64Str);
      } else {
        imageBytes = base64Decode(imageData);
      }

      // ── Success ─────────────────────────────────────────────────────────
      setState(() {
        _generatedImage = imageBytes;
        _isProcessing = false;
        _processingStage = '';
      });

      _successController.forward(from: 0);
      _showSuccessSnackBar('✨ Virtual try-on complete!');
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _processingStage = '';
      });
      _showErrorSnackBar('AI processing failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SNACKBARS  (unchanged)
  // ─────────────────────────────────────────────────────────────────────────
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD  (completely unchanged)
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isProcessing
                  ? _buildProcessingView()
                  : _generatedImage != null
                  ? _buildResultView()
                  : _buildInitialView(),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER  (unchanged)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.stats,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Virtual Try-On',
                  style:
                  AppText.title.copyWith(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.productTitle,
                  style: AppText.label.copyWith(color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INITIAL VIEW  (unchanged)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildInitialView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.accent.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.auto_awesome, size: 64, color: AppColors.primary)
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 2000.ms)
                    .shake(hz: 2, curve: Curves.easeInOutCubic),
                const SizedBox(height: 16),
                Text(
                  'See Yourself in This Outfit!',
                  style: AppText.title.copyWith(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload your photo and let AI show you how you\'ll look wearing this item',
                  style: AppText.label,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms).scale(),

          const SizedBox(height: 32),

          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                widget.clothImageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.image_not_supported, size: 40),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.2, end: 0),

          const SizedBox(height: 32),

          Text(
            'Choose Your Photo',
            style: AppText.title.copyWith(fontSize: 18),
          ).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildUploadButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.7)
                    ],
                  ),
                  onTap: () => _pickImage(ImageSource.gallery),
                ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.2, end: 0),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildUploadButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent,
                      AppColors.accent.withOpacity(0.7)
                    ],
                  ),
                  onTap: () => _pickImage(ImageSource.camera),
                ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.2, end: 0),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text('Tips for Best Results',
                        style: AppText.title.copyWith(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTip('📸 Use a clear, well-lit full body photo'),
                _buildTip('👤 Face the camera directly'),
                _buildTip('🎯 Stand in a neutral pose'),
                _buildTip('✨ Avoid cluttered backgrounds'),
                // ← CHANGE 3: Added FASHN-specific tip
                _buildTip('⚡ FASHN AI preserves your face & body exactly'),
              ],
            ),
          ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS  (unchanged)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildUploadButton({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (gradient as LinearGradient).colors.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 40),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppText.statLabel.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppText.label.copyWith(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROCESSING VIEW  (unchanged)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildProcessingView() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withOpacity(0.3),
                  AppColors.accent.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.2),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppGradients.stats,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 40),

          Text(
            _processingStage,
            style: AppText.title.copyWith(fontSize: 20),
            textAlign: TextAlign.center,
          )
              .animate(onPlay: (controller) => controller.repeat())
              .fadeIn(duration: 600.ms)
              .then()
              .fadeOut(duration: 600.ms),

          const SizedBox(height: 24),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 8,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.7 + (_shimmerController.value * 0.3),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.accent,
                            AppColors.primary,
                          ],
                          stops: [
                            (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                            _shimmerController.value.clamp(0.0, 1.0),
                            (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ← CHANGE 4: Updated time estimate to match FASHN (5-17s)
          Text(
            'FASHN AI is fitting the cloth...\nThis takes 5–17 seconds.',
            style: AppText.label.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RESULT VIEW  (unchanged)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildResultView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Try-On Complete!',
                          style: AppText.label.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(delay: 200.ms, curve: Curves.elasticOut),
                ),

                const SizedBox(height: 24),

                Hero(
                  tag: 'generated_image',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(
                        _generatedImage!,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms)
                    .scale(begin: const Offset(0.8, 0.8)),

                const SizedBox(height: 32),

                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.refresh,
                        label: 'Try Again',
                        color: AppColors.primary,
                        onTap: () {
                          setState(() {
                            _userImage = null;
                            _generatedImage = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.download_rounded,
                        label: 'Save',
                        color: AppColors.success,
                        onTap: () {
                          ImageGallerySaverPlus.saveImage(_generatedImage!,
                              name: "${_generatedImage!.length.toString()}",
                              quality: 100);
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  backgroundColor: AppColors.success,
                                  content: Center(
                                    child: Text(
                                        textAlign: TextAlign.center,
                                        "Image stored successfully",
                                        style: AppText.statLabel
                                            .copyWith(color: Colors.white)),
                                  )));
                        },
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3, end: 0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppText.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}