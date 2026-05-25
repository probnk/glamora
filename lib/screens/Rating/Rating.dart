import 'package:flutter/material.dart';
import 'package:glamora/models/ReviewsModel.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/RatingProvider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// ─── Theme ────────────────────────────────────────────────────────────────────
class _C {
  static const primary    = Color(0xFF6366F1);
  static const accent     = Color(0xFFF97316);
  static const success    = Color(0xFF16A34A);
  static const danger     = Color(0xFFEF4444);
  static const warning    = Color(0xFFF59E0B);
  static const darkBg     = Color(0xFF0D0D0D);
  static const darkCard   = Color(0xFF1A1A1A);
  static const darkBorder = Color(0xFF2A2A2A);
  static const muted      = Color(0xFF6B7280);
  static const lightBg    = Color(0xFFF8FAFC);
  static const lightCard  = Colors.white;
}

// ─── Rating Screen ────────────────────────────────────────────────────────────
class RatingScreen extends StatefulWidget {
  final List<ProductReviewModel> reviews;
  const RatingScreen({super.key, required this.reviews});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  bool _skeletonDone = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<RatingProvider>();
      provider.countStarRatings(widget.reviews);
      // Simulate skeleton: show real content after a short delay
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _skeletonDone = true);
      });
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<DarkModeProvider>().isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? _C.darkBg : _C.lightBg,
      appBar: _RatingAppBar(isDark: isDark),
      body: widget.reviews.isEmpty
          ? _EmptyState(isDark: isDark)
          : _skeletonDone
          ? FadeTransition(
          opacity: _fadeAnim,
          child: _RatingBody(
              isDark: isDark, reviews: widget.reviews))
          : _SkeletonBody(isDark: isDark),
    );
  }
}

// ─── AppBar ───────────────────────────────────────────────────────────────────
class _RatingAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isDark;
  const _RatingAppBar({required this.isDark});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: isDark ? _C.darkCard : _C.lightCard,
    iconTheme: IconThemeData(
        color: isDark ? Colors.white : const Color(0xFF0F172A)),
    centerTitle: true,
    title: ShaderMask(
      shaderCallback: (r) => const LinearGradient(
        colors: [_C.primary, Color(0xFFEC4899)],
      ).createShader(r),
      child: Text(
        'Reviews',
        style: GoogleFonts.poppins(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Colors.white),
      ),
    ),
  );
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────
class _SkeletonBody extends StatefulWidget {
  final bool isDark;
  const _SkeletonBody({required this.isDark});

  @override
  State<_SkeletonBody> createState() => _SkeletonBodyState();
}

class _SkeletonBodyState extends State<_SkeletonBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _shimmer = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) {
        final base  = widget.isDark ? _C.darkCard    : Colors.grey.shade200;
        final shine = widget.isDark ? _C.darkBorder  : Colors.grey.shade100;
        final color = Color.lerp(base, shine, _shimmer.value)!;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          children: [
            // Summary card skeleton
            Container(
              height: 140,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(20)),
            ),
            const SizedBox(height: 16),
            // Filter tabs skeleton
            Container(
              height: 44,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(14)),
            ),
            const SizedBox(height: 16),
            ...List.generate(
                3,
                    (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20)),
                  ),
                )),
          ],
        );
      },
    );
  }
}

// ─── Real Body ────────────────────────────────────────────────────────────────
class _RatingBody extends StatelessWidget {
  final bool isDark;
  final List<ProductReviewModel> reviews;
  const _RatingBody({required this.isDark, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final ratingProvider = context.watch<RatingProvider>();
    final avgRating = reviews.isNotEmpty
        ? reviews.fold(0.0, (s, r) => s + r.rating) / reviews.length
        : 0.0;
    final filtered = ratingProvider.filteredList;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        // ── Summary Card ────────────────────────────────────────────
        _SummaryCard(
          isDark: isDark,
          avgRating: avgRating,
          reviewCount: reviews.length,
          ratingProvider: ratingProvider,
        ),

        const SizedBox(height: 16),

        // ── Filter Tabs ──────────────────────────────────────────────
        _FilterTabBar(isDark: isDark, ratingProvider: ratingProvider),

        const SizedBox(height: 16),

        // ── Reviews Header ────────────────────────────────────────────
        _ReviewsHeader(
            isDark: isDark,
            label: ratingProvider.activeFilter == StarFilter.all
                ? 'All Reviews'
                : '${_filterLabel(ratingProvider.activeFilter)} Reviews',
            count: filtered.length),

        const SizedBox(height: 12),

        // ── Review Cards ───────────────────────────────────────────────
        if (filtered.isEmpty)
          _NoMatchState(isDark: isDark)
        else
          ...filtered.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ReviewCard(review: r, isDark: isDark),
          )),
      ],
    );
  }

  String _filterLabel(StarFilter f) {
    switch (f) {
      case StarFilter.five:  return '5 ★';
      case StarFilter.four:  return '4 ★';
      case StarFilter.three: return '3 ★';
      case StarFilter.two:   return '2 ★';
      case StarFilter.one:   return '1 ★';
      default:               return 'All';
    }
  }
}

// ─── Filter Tab Bar ───────────────────────────────────────────────────────────
class _FilterTabBar extends StatelessWidget {
  final bool isDark;
  final RatingProvider ratingProvider;
  const _FilterTabBar(
      {required this.isDark, required this.ratingProvider});

  static const _tabs = [
    StarFilter.all,
    StarFilter.five,
    StarFilter.four,
    StarFilter.three,
    StarFilter.two,
    StarFilter.one,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final filter  = _tabs[i];
          final active  = ratingProvider.activeFilter == filter;
          final count   = ratingProvider.countForFilter(filter);
          return _FilterChip(
            filter:  filter,
            count:   count,
            active:  active,
            isDark:  isDark,
            onTap:   () => ratingProvider.setFilter(filter),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final StarFilter  filter;
  final int         count;
  final bool        active;
  final bool        isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.filter,
    required this.count,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  String get _label {
    switch (filter) {
      case StarFilter.all:   return 'All';
      case StarFilter.five:  return '5';
      case StarFilter.four:  return '4';
      case StarFilter.three: return '3';
      case StarFilter.two:   return '2';
      case StarFilter.one:   return '1';
    }
  }

  Color get _chipColor {
    if (!active) return Colors.transparent;
    switch (filter) {
      case StarFilter.five:
      case StarFilter.four:  return _C.success;
      case StarFilter.three: return _C.warning;
      case StarFilter.two:
      case StarFilter.one:   return _C.danger;
      default:               return _C.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAll  = filter == StarFilter.all;
    final border = active
        ? _chipColor
        : isDark
        ? _C.darkBorder
        : Colors.grey.shade300;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          color: active
              ? _chipColor.withOpacity(0.12)
              : isDark
              ? _C.darkCard
              : _C.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: active ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isAll) ...[
              Icon(Icons.star_rounded,
                  size: 14,
                  color: active ? _chipColor : _C.warning),
              const SizedBox(width: 4),
            ],
            Text(
              _label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight:
                active ? FontWeight.w600 : FontWeight.w500,
                color: active
                    ? _chipColor
                    : isDark
                    ? Colors.white70
                    : _C.muted,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: active
                    ? _chipColor.withOpacity(0.2)
                    : isDark
                    ? _C.darkBorder
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? _chipColor
                      : isDark
                      ? Colors.white54
                      : _C.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reviews Header ───────────────────────────────────────────────────────────
class _ReviewsHeader extends StatelessWidget {
  final bool isDark;
  final String label;
  final int count;
  const _ReviewsHeader(
      {required this.isDark, required this.label, required this.count});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: _C.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.rate_review_outlined,
          size: 16, color: _C.primary),
    ),
    const SizedBox(width: 10),
    Text(label,
        style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A))),
    const SizedBox(width: 8),
    Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: _C.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text('$count',
          style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _C.primary)),
    ),
  ]);
}

// ─── No-Match State ───────────────────────────────────────────────────────────
class _NoMatchState extends StatelessWidget {
  final bool isDark;
  const _NoMatchState({required this.isDark});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.filter_list_off_rounded,
          size: 40,
          color: isDark ? Colors.white24 : Colors.grey.shade300),
      const SizedBox(height: 12),
      Text('No reviews for this rating',
          style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDark ? Colors.white38 : _C.muted)),
    ]),
  );
}

// ─── Summary Card ─────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final bool isDark;
  final double avgRating;
  final int reviewCount;
  final RatingProvider ratingProvider;

  const _SummaryCard({
    required this.isDark,
    required this.avgRating,
    required this.reviewCount,
    required this.ratingProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? _C.darkCard : _C.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? _C.darkBorder : Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : _C.primary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // ── Score ──────────────────────────────────────────────────
        Column(children: [
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [_C.primary, Color(0xFFEC4899)],
            ).createShader(r),
            child: Text(
              avgRating.toStringAsFixed(1),
              style: GoogleFonts.poppins(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ),
          _StarRow(rating: avgRating),
          const SizedBox(height: 4),
          Text('$reviewCount Reviews',
              style: GoogleFonts.poppins(fontSize: 12, color: _C.muted)),
        ]),

        const SizedBox(width: 20),

        Container(
            width: 1,
            height: 100,
            color: isDark ? _C.darkBorder : Colors.grey.shade200),

        const SizedBox(width: 20),

        // ── Bars ───────────────────────────────────────────────────
        Expanded(
          child: Column(children: [
            _RatingBar(
                star: 5,
                count: ratingProvider.fifthCount,
                total: reviewCount,
                isDark: isDark,
                onTap: () =>
                    ratingProvider.setFilter(StarFilter.five)),
            _RatingBar(
                star: 4,
                count: ratingProvider.fourthCount,
                total: reviewCount,
                isDark: isDark,
                onTap: () =>
                    ratingProvider.setFilter(StarFilter.four)),
            _RatingBar(
                star: 3,
                count: ratingProvider.thirdCount,
                total: reviewCount,
                isDark: isDark,
                onTap: () =>
                    ratingProvider.setFilter(StarFilter.three)),
            _RatingBar(
                star: 2,
                count: ratingProvider.secondCount,
                total: reviewCount,
                isDark: isDark,
                onTap: () =>
                    ratingProvider.setFilter(StarFilter.two)),
            _RatingBar(
                star: 1,
                count: ratingProvider.firstCount,
                total: reviewCount,
                isDark: isDark,
                onTap: () =>
                    ratingProvider.setFilter(StarFilter.one)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Rating Bar ───────────────────────────────────────────────────────────────
class _RatingBar extends StatelessWidget {
  final int  star;
  final int  count;
  final int  total;
  final bool isDark;
  final VoidCallback onTap;

  const _RatingBar({
    required this.star,
    required this.count,
    required this.total,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? count / total : 0.0;
    final barColor = star >= 4
        ? _C.success
        : star == 3
        ? _C.warning
        : _C.danger;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text('$star',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF0F172A))),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, size: 12, color: _C.warning),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (_, val, __) => LinearProgressIndicator(
                  value: val,
                  minHeight: 7,
                  backgroundColor:
                  isDark ? _C.darkBorder : Colors.grey.shade200,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 20,
            child: Text('$count',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: _C.muted)),
          ),
        ]),
      ),
    );
  }
}

// ─── Review Card ──────────────────────────────────────────────────────────────
class _ReviewCard extends StatefulWidget {
  final ProductReviewModel review;
  final bool isDark;
  const _ReviewCard({required this.review, required this.isDark});

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _expanded = false;

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy · h:mm a').format(dt);
    } catch (_) {
      try {
        final dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(raw);
        return DateFormat('dd MMM yyyy · h:mm a').format(dt);
      } catch (_) {
        return raw;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r      = widget.review;
    final isDark = widget.isDark;
    final hasImages =
        r.reviewImages != null && r.reviewImages!.isNotEmpty;
    final commentLong =
        r.comment.length > 120;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _C.darkCard : _C.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? _C.darkBorder : Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.25)
                : _C.primary.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ─────────────────────────────────────────────────
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
            isDark ? _C.darkBorder : Colors.grey.shade200,
            backgroundImage: r.profilePhoto.isNotEmpty
                ? NetworkImage(r.profilePhoto)
                : null,
            child: r.profilePhoto.isEmpty
                ? Icon(Icons.person_rounded,
                color: isDark ? Colors.white38 : _C.muted)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.reviewerName,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A))),
                  const SizedBox(height: 1),
                  Text(_formatDate(r.reviewDate),
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: _C.muted)),
                ]),
          ),
          _StarBadge(rating: r.rating),
        ]),

        // ── Comment ────────────────────────────────────────────────
        if (r.comment.isNotEmpty) ...[
          const SizedBox(height: 12),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expanded || !commentLong
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Text(
              r.comment,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDark
                      ? Colors.white70
                      : const Color(0xFF475569),
                  height: 1.5),
            ),
            secondChild: Text(
              r.comment,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDark
                      ? Colors.white70
                      : const Color(0xFF475569),
                  height: 1.5),
            ),
          ),
          if (commentLong)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _expanded ? 'Show less' : 'Read more',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _C.primary),
                ),
              ),
            ),
        ],

        // ── Images ─────────────────────────────────────────────────
        if (hasImages) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: r.reviewImages!.length,
              separatorBuilder: (_, __) =>
              const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _openImage(context, r.reviewImages!, i),
                child: Hero(
                  tag: 'review_img_${r.reviewDate}_$i',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      r.reviewImages![i],
                      width: 82,
                      height: 82,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) =>
                      progress == null
                          ? child
                          : Container(
                        width: 82,
                        height: 82,
                        color: isDark
                            ? _C.darkBorder
                            : Colors.grey.shade200,
                        child: const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: _C.primary),
                          ),
                        ),
                      ),
                      errorBuilder: (_, __, ___) => Container(
                        width: 82,
                        height: 82,
                        color: isDark
                            ? _C.darkBorder
                            : Colors.grey.shade200,
                        child: const Icon(
                            Icons.broken_image_outlined,
                            color: _C.muted),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  void _openImage(
      BuildContext context, List<String> images, int initial) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) =>
            _ImageViewer(images: images, initial: initial),
      ),
    );
  }
}

// ─── Full-screen Image Viewer ─────────────────────────────────────────────────
class _ImageViewer extends StatefulWidget {
  final List<String> images;
  final int          initial;
  const _ImageViewer({required this.images, required this.initial});

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
    _ctrl    = PageController(initialPage: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${_current + 1} / ${widget.images.length}',
            style: GoogleFonts.poppins(color: Colors.white)),
      ),
      body: PageView.builder(
        controller: _ctrl,
        onPageChanged: (i) => setState(() => _current = i),
        itemCount: widget.images.length,
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: Image.network(widget.images[i],
                fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// ─── Star Badge ───────────────────────────────────────────────────────────────
class _StarBadge extends StatelessWidget {
  final int rating;
  const _StarBadge({required this.rating});

  Color get _color {
    if (rating >= 4) return _C.success;
    if (rating == 3) return _C.warning;
    return _C.danger;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: _color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.star_rounded, size: 13, color: _color),
      const SizedBox(width: 4),
      Text(rating.toString(),
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _color)),
    ]),
  );
}

// ─── Star Row ─────────────────────────────────────────────────────────────────
class _StarRow extends StatelessWidget {
  final double rating;
  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) {
      if (i < rating.floor()) {
        return const Icon(Icons.star_rounded,
            color: _C.warning, size: 18);
      } else if (i == rating.floor() && rating % 1 >= 0.5) {
        return const Icon(Icons.star_half_rounded,
            color: _C.warning, size: 18);
      } else {
        return const Icon(Icons.star_outline_rounded,
            color: _C.warning, size: 18);
      }
    }),
  );
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: _C.primary.withOpacity(0.08),
            shape: BoxShape.circle),
        child: Icon(Icons.rate_review_outlined,
            size: 48, color: _C.primary.withOpacity(0.5)),
      ),
      const SizedBox(height: 16),
      Text('No Reviews Yet',
          style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color:
              isDark ? Colors.white : const Color(0xFF0F172A))),
      const SizedBox(height: 6),
      Text('Be the first to share your experience!',
          style: GoogleFonts.poppins(
              fontSize: 13, color: _C.muted)),
    ]),
  );
}