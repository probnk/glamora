import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:glamora/constants/app_theme.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/models/ReviewsModel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/ReviewProvider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

// ─── Theme ────────────────────────────────────────────────────────────────────
class _C {
  static const primary = Color(0xFF6366F1);
  static const accent = Color(0xFFF97316);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const darkBg = Color(0xFF0D0D0D);
  static const darkCard = Color(0xFF1A1A1A);
  static const darkBorder = Color(0xFF2A2A2A);
  static const muted = Color(0xFF6B7280);
  static const lightBg = Color(0xFFF8FAFC);
  static const lightCard = Colors.white;
}

// ─── Model for which products this review covers ──────────────────────────────
class ReviewProduct {
  final String docId;
  final String gender;
  final String category;
  final String? productName;
  final String imageUrl;
  final double price;
  final Color color;
  final int pieces;

  const ReviewProduct(
      {required this.docId,
      required this.gender,
      required this.category,
      required this.productName,
      required this.imageUrl,
      required this.price,
      required this.color,
      required this.pieces});
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class ReviewScreen extends StatefulWidget {
  /// Pass ONE product normally, or MULTIPLE for a multi-item order
  final List<ReviewProduct> products;

  const ReviewScreen({super.key, required this.products})
      : assert(products.length > 0, 'At least one product required');

  /// Convenience constructor for a single product
  factory ReviewScreen.single(
          {Key? key,
          required String docId,
          required String gender,
          required String category,
          required String productName,
          required String imageUrl,
          required double price,
          required Color color,
          required int pieces}) =>
      ReviewScreen(
        key: key,
        products: [
          ReviewProduct(
              docId: docId,
              gender: gender,
              category: category,
              productName: productName,
              imageUrl: imageUrl,
              price: price,
              color: color,
              pieces: pieces)
        ],
      );

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen>
    with SingleTickerProviderStateMixin {
  final _commentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Reset provider on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReviewProvider>().resetForm();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Image picker + upload ───────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final provider = context.read<ReviewProvider>();
    if (provider.imageCount >= 6) {
      _showSnack('Maximum 6 photos allowed', isError: true);
      return;
    }

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    provider.toggleLoading(true);

    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/${path.basenameWithoutExtension(picked.path)}_cmp.jpg';

      final compressed = await FlutterImageCompress.compressAndGetFile(
        picked.path,
        targetPath,
        quality: 72,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) throw Exception('Compression failed');

      final localFile = File(compressed.path);
      final storagePath =
          '${widget.products.first.docId}_Reviews/${path.basename(localFile.path)}';
      final ref = FirebaseStorage.instance.ref().child(storagePath);

      await ref.putFile(localFile);
      final url = await ref.getDownloadURL();

      provider.addUploadedImage(
        localFile: localFile,
        remoteUrl: url,
        storagePath: storagePath,
      );
    } catch (e) {
      _showSnack('Upload failed: $e', isError: true);
    } finally {
      provider.toggleLoading(false);
    }
  }

  // ── Submit ──────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnack('Please sign in to leave a review', isError: true);
      return;
    }

    final provider = context.read<ReviewProvider>();

    final newReview = ProductReviewModel(
      reviewerName: currentUser.displayName ?? 'Anonymous',
      reviewDate: DateTime.now().toIso8601String(),
      profilePhoto: currentUser.photoURL ?? '',
      comment: _commentController.text.trim(),
      reviewImages: provider.productPhotoUrls,
      rating: provider.selectedStarRating,
    );

    try {
      if (widget.products.length == 1) {
        final p = widget.products.first;
        await provider.submitReview(
          docId: p.docId,
          gender: p.gender,
          category: p.category,
          newReview: newReview,
        );
      } else {
        await provider.submitReviewForMultipleProducts(
          products: widget.products
              .map((p) => {
                    'docId': p.docId,
                    'gender': p.gender,
                    'category': p.category,
                  })
              .toList(),
          newReview: newReview,
        );
      }

      _commentController.clear();
      if (mounted) {
        _showSnack('Review submitted – thank you! 🎉');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted)
        _showSnack('Submission failed. Please try again.', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
        backgroundColor: isError ? _C.danger : _C.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<DarkModeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? _C.darkBg : _C.lightBg,
      appBar: _AppBar(isDark: isDark),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
            children: [
              _ProductListBanner(
                isDark: isDark,
                products: widget.products,
              ),
              const SizedBox(height: 16),

              // ── Rating ────────────────────────────────────────────
              _SectionCard(
                isDark: isDark,
                icon: Icons.star_rounded,
                iconColor: _C.warning,
                title: 'Your Rating',
                child: const _StarRatingRow(),
              ),

              const SizedBox(height: 14),

              // ── Photos ────────────────────────────────────────────
              _SectionCard(
                isDark: isDark,
                icon: Icons.photo_library_outlined,
                iconColor: _C.primary,
                title: 'Add Photos  (max 6)',
                child:
                    _ImagePickerGrid(isDark: isDark, onPickImage: _pickImage),
              ),

              const SizedBox(height: 14),

              // ── Comment ───────────────────────────────────────────
              _SectionCard(
                isDark: isDark,
                icon: Icons.comment_outlined,
                iconColor: _C.accent,
                title: 'Your Comment',
                child: _CommentField(
                    isDark: isDark, controller: _commentController),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _SubmitBar(isDark: isDark, onSubmit: _submit),
    );
  }
}

// ─── AppBar ───────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isDark;

  const _AppBar({required this.isDark});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark ? _C.darkCard : _C.lightCard,
      iconTheme: IconThemeData(color: isDark ? Colors.white : _C.darkBg),
      centerTitle: true,
      title: Text('Write a Review',
          style: AppText.title.copyWith(color: isDark ? white : grayBlack)),
    );
  }
}

// ─── Multi-product banner ─────────────────────────────────────────────────────
class _MultiProductBanner extends StatelessWidget {
  final bool isDark;
  final List<ReviewProduct> products;

  const _MultiProductBanner({required this.isDark, required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.primary.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.shopping_bag_outlined,
                color: _C.primary, size: 16),
            const SizedBox(width: 8),
            Text('Reviewing ${products.length} products',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _C.primary)),
          ]),
          const SizedBox(height: 8),
          ...products.map((p) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                          color: _C.primary, shape: BoxShape.circle)),
                  Expanded(
                    child: Text(
                      p.productName ?? p.docId,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : _C.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              )),
        ],
      ),
    );
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _C.darkCard : _C.lightCard,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: isDark ? _C.darkBorder : Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.25)
                : _C.primary.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A))),
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ─── Star Rating Row ──────────────────────────────────────────────────────────
class _StarRatingRow extends StatelessWidget {
  const _StarRatingRow();

  static const _labels = ['Terrible', 'Bad', 'Okay', 'Good', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    return Consumer<ReviewProvider>(
      builder: (_, provider, __) {
        final selected = provider.selectedStarRating;
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starNum = i + 1;
                final isFilled = selected >= starNum;
                return GestureDetector(
                  onTap: () => provider.setStarRating(starNum),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: AnimatedScale(
                      scale: selected == starNum ? 1.25 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.elasticOut,
                      child: Icon(
                        isFilled ? IconlyBold.star : IconlyLight.star,
                        color: isFilled
                            ? Colors.amber.shade500
                            : Colors.grey.shade400,
                        size: 38,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _labels[selected.clamp(1, 5) - 1],
                key: ValueKey(selected),
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.amber.shade600),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Image Picker Grid ────────────────────────────────────────────────────────
class _ImagePickerGrid extends StatelessWidget {
  final bool isDark;
  final VoidCallback onPickImage;

  const _ImagePickerGrid({required this.isDark, required this.onPickImage});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReviewProvider>(
      builder: (_, provider, __) {
        final files = provider.localImageFiles;
        final loading = provider.isLoading;
        final canAdd = files.length < 6;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ...List.generate(
                files.length,
                (i) => _ImageTile(
                      file: files[i],
                      isDark: isDark,
                      index: i,
                      onDelete: () => provider.deleteImage(i),
                    )),
            if (loading) _LoadingTile(isDark: isDark),
            if (canAdd && !loading)
              _AddTile(isDark: isDark, onTap: onPickImage),
          ],
        );
      },
    );
  }
}

class _ImageTile extends StatelessWidget {
  final File file;
  final bool isDark;
  final int index;
  final VoidCallback onDelete;

  const _ImageTile(
      {required this.file,
      required this.isDark,
      required this.index,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.primary.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.file(file, fit: BoxFit.cover),
        ),
      ),
      // Delete button
      Positioned(
        top: -6,
        right: -6,
        child: GestureDetector(
          onTap: () => _confirmDelete(context),
          child: Container(
            width: 22,
            height: 22,
            decoration:
                const BoxDecoration(color: _C.danger, shape: BoxShape.circle),
            child: const Icon(Icons.close, color: Colors.white, size: 13),
          ),
        ),
      ),
    ]);
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Remove Photo',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('This photo will be removed and deleted from storage.',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins())),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                onDelete();
              },
              child:
                  Text('Remove', style: GoogleFonts.poppins(color: _C.danger))),
        ],
      ),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  final bool isDark;

  const _LoadingTile({required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: isDark ? _C.darkBorder : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.primary.withOpacity(0.2), width: 1.5),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary),
          ),
        ),
      );
}

class _AddTile extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _AddTile({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: isDark ? _C.darkBorder : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDark ? _C.muted.withAlpha(100) : Colors.grey.shade300,
                width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 26, color: isDark ? Colors.white38 : _C.muted),
              const SizedBox(height: 4),
              Text('Add',
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: isDark ? Colors.white38 : _C.muted)),
            ],
          ),
        ),
      );
}

// ─── Comment Field ────────────────────────────────────────────────────────────
class _CommentField extends StatelessWidget {
  final bool isDark;
  final TextEditingController controller;

  const _CommentField({required this.isDark, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 4,
      minLines: 3,
      textCapitalization: TextCapitalization.sentences,
      style: GoogleFonts.poppins(
          fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: 'Share your experience with this product…',
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.white38),
        filled: true,
        fillColor: isDark ? _C.darkBorder : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _C.muted.withAlpha(100))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.danger, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.danger, width: 1.5)),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Please write a comment' : null,
    );
  }
}

// ─── Submit Bar ───────────────────────────────────────────────────────────────
class _SubmitBar extends StatelessWidget {
  final bool isDark;
  final VoidCallback onSubmit;

  const _SubmitBar({required this.isDark, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReviewProvider>(
      builder: (_, provider, __) {
        return Container(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: isDark ? _C.darkBorder : _C.lightCard,
            border: Border(
                top: BorderSide(
                    color: isDark ? _C.darkBorder : Colors.grey.shade100)),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: provider.isLoading
                  ? null
                  : LinearGradient(
                      colors: !isDark ? [lightBlue, lightPurple] : [lightOrange, darkOrange]),
              color: provider.isLoading ? _C.muted : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ElevatedButton.icon(
              onPressed: provider.isLoading ? null : onSubmit,
              icon: provider.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
              label: Text(
                provider.isLoading ? 'Submitting…' : 'Submit Review',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size(double.infinity, 0),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProductListBanner extends StatelessWidget {
  final bool isDark;
  final List<ReviewProduct> products;

  const _ProductListBanner({
    required this.isDark,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    final total = products.fold<double>(0, (sum, item) => sum + item.price);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? _C.darkCard : white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? _C.darkBorder : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined,
                  color: _C.success, size: 16),
              const SizedBox(width: 8),
              Text(
                'Order Items (${products.length})',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? white : grayBlack,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          /// Product List
          ListView.builder(
            itemCount: products.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, i) {
              final p = products[i];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDark ? _C.darkBorder : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.muted.withAlpha(100))
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),

                  /// Image
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      p.imageUrl,
                      width: 55,
                      height: 55,
                      fit: BoxFit.cover,
                    ),
                  ),

                  /// Title + Subtitle
                  title: Text(
                    p.productName ?? 'Product',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),

                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        /// Color box
                        Container(
                          width: 15,
                          height: 15,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: p.color,
                            border: Border.all(
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                          ),
                        ),

                        Text(' • ',
                            style:
                                AppText.statLabel.copyWith(color: Colors.grey)),

                        Text(
                          '${p.pieces} Qty',
                          style: AppText.label.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  /// Price
                  trailing: Text(
                    'Rs ${p.price.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? white : grayBlack,
                    ),
                  ),
                ),
              );
            },
          ),
          Divider(height: 20,color: isDark ? _C.muted.withAlpha(100):Colors.grey.shade300),

          /// Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Rs ${total.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? white : grayBlack,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
