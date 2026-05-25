// lib/screens/virtual_tryon/virtual_tryon_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import '../../../constants/app_theme.dart';
import '../../../providers/VirtualTryOnProvider.dart';

class VirtualTryOnScreen extends StatefulWidget {
  final String clothImageUrl;
  final String productTitle;
  final String category;

  const VirtualTryOnScreen({
    Key? key,
    required this.clothImageUrl,
    required this.productTitle,
    required this.category,
  }) : super(key: key);

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _successController;
  late AnimationController _videoProgressController;

  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

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

    _videoProgressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 75),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _successController.dispose();
    _videoProgressController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ── Init video player from bytes or URL ──────────────────────────────────
  Future<void> _initVideoPlayer(VirtualTryOnProvider provider) async {
    _videoController?.dispose();
    _videoInitialized = false;

    try {
      VideoPlayerController controller;

      if (provider.videoBytes != null) {
        // Save bytes to temp file and play from file
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/tryon_video.mp4');
        await tempFile.writeAsBytes(provider.videoBytes!);
        controller = VideoPlayerController.file(tempFile);
      } else if (provider.generatedVideoUrl != null) {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(provider.generatedVideoUrl!),
        );
      } else {
        return;
      }

      _videoController = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();

      setState(() => _videoInitialized = true);
    } catch (e) {
      debugPrint('Video player init error: $e');
    }
  }

  // ── Save video to gallery ─────────────────────────────────────────────────
  Future<void> _saveVideo(VirtualTryOnProvider provider) async {
    try {
      if (provider.videoBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
            '${tempDir.path}/tryon_360_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await tempFile.writeAsBytes(provider.videoBytes!);
        await ImageGallerySaverPlus.saveFile(tempFile.path);
        _showSuccessSnackBar('✨ 360° video saved to gallery!');
      } else if (provider.generatedVideoUrl != null) {
        // Download video from URL then save
        _showErrorSnackBar('Please wait — downloading video for save...');
        final httpClient = HttpClient();
        final request =
        await httpClient.getUrl(Uri.parse(provider.generatedVideoUrl!));
        final response = await request.close();
        final bytes = await response.fold<List<int>>(
          [],
              (acc, chunk) => acc..addAll(chunk),
        );
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
            '${tempDir.path}/tryon_360_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await tempFile.writeAsBytes(bytes);
        await ImageGallerySaverPlus.saveFile(tempFile.path);
        _showSuccessSnackBar('✨ 360° video saved to gallery!');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save video: $e');
    }
  }

  // ── Snackbars ─────────────────────────────────────────────────────────────
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VirtualTryOnProvider(),
      child: Consumer<VirtualTryOnProvider>(
        builder: (context, provider, _) {
          // Listen for video ready to init player
          if (provider.hasVideo && !_videoInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _initVideoPlayer(provider);
            });
          }

          // Show error as snackbar when video fails but state returns to imageReady
          // (errorMessage is set but state is imageReady — video failed silently before)
          if (provider.state == TryOnState.imageReady &&
              provider.errorMessage.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showErrorSnackBar(provider.errorMessage);
              provider.clearError(); // resets errorMessage only
            });
          }

          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(provider),
                  Expanded(
                    child: _buildBody(provider),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(VirtualTryOnProvider provider) {
    if (provider.isGeneratingImage) return _buildImageProcessingView(provider);
    if (provider.isGeneratingVideo) return _buildVideoProcessingView(provider);
    if (provider.hasVideo) return _buildVideoResultView(provider);
    if (provider.hasImage) return _buildImageResultView(provider);
    if (provider.state == TryOnState.error) return _buildErrorView(provider);
    return _buildInitialView(provider);
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(VirtualTryOnProvider provider) {
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
                  provider.hasVideo
                      ? 'AI 360° Virtual Try-On'
                      : 'AI Virtual Try-On',
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
            child: Icon(
              provider.hasVideo ? Icons.videocam : Icons.auto_awesome,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  // ── Initial View ──────────────────────────────────────────────────────────
  Widget _buildInitialView(VirtualTryOnProvider provider) {
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
                    .animate(onPlay: (c) => c.repeat())
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
                  'Upload your photo → Get AI try-on image → Create 360° video!',
                  style: AppText.label,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms).scale(),
          const SizedBox(height: 24),
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
                errorBuilder: (_, __, ___) =>
                const Center(child: Icon(Icons.image_not_supported, size: 40)),
              ),
            ),
          ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.2, end: 0),
          const SizedBox(height: 32),
          Text('Choose Your Photo',
              style: AppText.title.copyWith(fontSize: 18))
              .animate()
              .fadeIn(delay: 400.ms),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildUploadButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  gradient: LinearGradient(colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.7)
                  ]),
                  onTap: () => provider.pickImage(
                    source: ImageSource.gallery,
                    clothImageUrl: widget.clothImageUrl,
                    category: widget.category,
                  ),
                ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.2, end: 0),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildUploadButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  gradient: LinearGradient(colors: [
                    AppColors.accent,
                    AppColors.accent.withOpacity(0.7)
                  ]),
                  onTap: () => provider.pickImage(
                    source: ImageSource.camera,
                    clothImageUrl: widget.clothImageUrl,
                    category: widget.category,
                  ),
                ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.2, end: 0),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Steps guide
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
                Row(children: [
                  Icon(Icons.videocam_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('How It Works',
                      style: AppText.title.copyWith(fontSize: 16)),
                ]),
                const SizedBox(height: 12),
                _buildStep('1', 'Upload your full-body photo', AppColors.primary),
                _buildStep(
                    '2', 'AI generates your try-on image', AppColors.accent),
                _buildStep(
                    '3', 'Tap "Create 360° Video" button', Colors.purple),
                _buildStep(
                    '4', 'Watch yourself rotate in the outfit!', AppColors.success),
                const SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.lightbulb_outline,
                      color: Colors.amber.shade700, size: 18),
                  const SizedBox(width: 8),
                  Text('Tips:', style: AppText.title.copyWith(fontSize: 14)),
                ]),
                const SizedBox(height: 8),
                _buildTip('📸 Clear, well-lit full body photo'),
                _buildTip('👤 Face camera directly, neutral pose'),
                _buildTip('⚡ FASHN AI preserves your face & body exactly'),
              ],
            ),
          ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  // ── Image Processing View ─────────────────────────────────────────────────
  Widget _buildImageProcessingView(VirtualTryOnProvider provider) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPulsingIcon(Icons.auto_awesome),
          const SizedBox(height: 40),
          Text(
            provider.processingStage,
            style: AppText.title.copyWith(fontSize: 20),
            textAlign: TextAlign.center,
          )
              .animate(onPlay: (c) => c.repeat())
              .fadeIn(duration: 600.ms)
              .then()
              .fadeOut(duration: 600.ms),
          const SizedBox(height: 24),
          _buildProgressBar(),
          const SizedBox(height: 32),
          Text(
            'FASHN AI is fitting the cloth...\nThis takes 5–17 seconds.',
            style: AppText.label.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Video Processing View ─────────────────────────────────────────────────
  Widget _buildVideoProcessingView(VirtualTryOnProvider provider) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPulsingIcon(Icons.videocam_rounded, color: Colors.purple),
          const SizedBox(height: 40),
          // 360 rotation animation label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.purple.shade400, Colors.deepPurple]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.cube_box_fill, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Creating 360° Video',
                    style: AppText.label.copyWith(color: Colors.white)),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1500.ms),
          const SizedBox(height: 24),
          Text(
            provider.processingStage,
            style: AppText.title.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          )
              .animate(onPlay: (c) => c.repeat())
              .fadeIn(duration: 600.ms)
              .then()
              .fadeOut(duration: 600.ms),
          const SizedBox(height: 24),
          // Progress bar with percentage
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: provider.videoProgress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(provider.videoProgress * 100).toInt()}%',
                style: AppText.label.copyWith(
                  color: Colors.purple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'AI is creating a 360° fashion video of you\nin this outfit. This takes 45–90 seconds.',
            style: AppText.label.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Image Result View ─────────────────────────────────────────────────────
  Widget _buildImageResultView(VirtualTryOnProvider provider) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Success badge
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

                const SizedBox(height: 24),

                // Generated image
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
                        provider.generatedImage!,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms)
                    .scale(begin: const Offset(0.8, 0.8)),

                const SizedBox(height: 24),

                // 🎥 Create 360° Video Button — MAIN NEW FEATURE
                GestureDetector(
                  onTap: () => provider.generateVideo(
                    clothImageUrl: widget.clothImageUrl,
                    productTitle: widget.productTitle,
                    category: widget.category,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.purple, Colors.deepPurple],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_rounded,
                            color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create 360° Video',
                              style: AppText.label.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              'See yourself rotate in this outfit',
                              style: AppText.label.copyWith(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '360°',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 500.ms)
                    .slideY(begin: 0.3, end: 0)
                    .then(delay: 1000.ms)
                    .shimmer(duration: 1500.ms, color: Colors.white30),

                const SizedBox(height: 16),

                // Try Again + Save row
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.refresh,
                        label: 'Try Again',
                        color: AppColors.primary,
                        onTap: () => provider.reset(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.download_rounded,
                        label: 'Save Image',
                        color: AppColors.success,
                        onTap: () {
                          ImageGallerySaverPlus.saveImage(
                            provider.generatedImage!,
                            name:
                            'tryon_${DateTime.now().millisecondsSinceEpoch}',
                            quality: 100,
                          );
                          _showSuccessSnackBar('Image saved to gallery!');
                        },
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.3, end: 0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Video Result View ─────────────────────────────────────────────────────
  Widget _buildVideoResultView(VirtualTryOnProvider provider) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 360 success badge
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Colors.purple, Colors.deepPurple]),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '360° Video Ready!',
                        style: AppText.label.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ).animate().scale(delay: 200.ms, curve: Curves.elasticOut),

                const SizedBox(height: 24),

                // Video player
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _videoInitialized && _videoController != null
                        ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(_videoController!),
                          // Play/Pause overlay tap
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _videoController!.value.isPlaying
                                    ? _videoController!.pause()
                                    : _videoController!.play();
                              });
                            },
                            child: Container(
                              color: Colors.transparent,
                              child: Center(
                                child: ValueListenableBuilder(
                                  valueListenable: _videoController!,
                                  builder: (_, value, __) {
                                    return AnimatedOpacity(
                                      opacity:
                                      value.isPlaying ? 0.0 : 1.0,
                                      duration:
                                      const Duration(milliseconds: 300),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          // 360 badge overlay
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.threesixty,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    '360°',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                        : Container(
                      height: 300,
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms).scale(
                    begin: const Offset(0.8, 0.8)),

                const SizedBox(height: 8),
                Text(
                  'Tap video to pause/play • Loops automatically',
                  style: AppText.label.copyWith(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.image_outlined,
                        label: 'View Image',
                        color: AppColors.primary,
                        onTap: () {
                          _videoController?.pause();
                          setState(() => _videoInitialized = false);
                          provider.resetToImageReady();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.download_rounded,
                        label: 'Save Video',
                        color: Colors.purple,
                        onTap: () => _saveVideo(provider),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.refresh,
                        label: 'Start Over',
                        color: Colors.grey.shade600,
                        onTap: () {
                          _videoController?.pause();
                          setState(() => _videoInitialized = false);
                          provider.reset();
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

  // ── Error View ────────────────────────────────────────────────────────────
  Widget _buildErrorView(VirtualTryOnProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 64)
                .animate()
                .shake(),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: AppText.title.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage,
              style: AppText.label.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildActionButton(
              icon: Icons.refresh,
              label: 'Try Again',
              color: AppColors.primary,
              onTap: () => provider.reset(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared Widgets ────────────────────────────────────────────────────────
  Widget _buildPulsingIcon(IconData icon, {Color? color}) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            (color ?? AppColors.primary).withOpacity(0.3),
            (color ?? AppColors.accent).withOpacity(0.1),
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
                  gradient: color != null
                      ? LinearGradient(colors: [color, color.withOpacity(0.7)])
                      : AppGradients.stats,
                  boxShadow: [
                    BoxShadow(
                      color: (color ?? AppColors.primary).withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 60),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
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
                      AppColors.primary
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
    );
  }

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
              color:
              (gradient as LinearGradient).colors.first.withOpacity(0.3),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
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
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppText.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppText.label.copyWith(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
              child: Text(text, style: AppText.label.copyWith(fontSize: 13))),
        ],
      ),
    );
  }
}