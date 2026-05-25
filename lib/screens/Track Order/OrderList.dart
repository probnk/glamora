import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Reuse Widgets/loadingShimmer.dart';
import '../../constants/app_theme.dart';
import '../../constants/reponsivness.dart';
import '../../models/OrderList.dart';
import '../../models/OrderProducts.dart';
import '../../providers/OrdersProvider.dart';
import '../Review/Review.dart';
import 'TrackOrder.dart';
import '../../constants/colors.dart';
import 'dart:math' as math;

// ─── Theme helpers ────────────────────────────────────────────────────────────
class _C {
  static const primary = Color(0xFF6366F1);
  static const accent = Color(0xFFF97316);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const darkBg = Color(0xFF121212);
  static const darkCard = Color(0xFF181818);
  static const darkBorder = Color(0xFF333333);
  static const muted = Color(0xFF707070);
}
// ─────────────────────────────────────────────────────────────────────────────

class OrdersListScreen extends StatelessWidget {
  const OrdersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<DarkModeProvider>(context).isDarkMode;
    final currentEmail = FirebaseAuth.instance.currentUser?.email;

    return Scaffold(
      backgroundColor: isDark ? _C.darkBg : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(context, isDark),
      body: Consumer<OrdersProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return _buildShimmer(context, isDark);
          }

          final userOrders = currentEmail != null
              ? provider.orders
                  .where((o) => o.userDetails.email == currentEmail)
                  .toList()
              : <OrderList>[];

          final filteredOrders =
              _filterOrders(userOrders, provider.searchQuery);

          if (userOrders.isEmpty) {
            return _EmptyState(
              icon: Icons.shopping_bag_outlined,
              message: 'No Orders Yet',
              subtitle: "Your orders will appear here",
              isDark: isDark,
            );
          }

          if (filteredOrders.isEmpty) {
            return _EmptyState(
              icon: Icons.search_off_rounded,
              message: 'No Results Found',
              subtitle: 'Try different search terms',
              isDark: isDark,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: filteredOrders.length,
            itemBuilder: (context, index) =>
                _OrderCard(order: filteredOrders[index], isDark: isDark),
          );
        },
      ),
      floatingActionButton: _buildFAB(context, isDark),
    );
  }

  // ─── App Bar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark ? _C.darkCard : Colors.white,
      iconTheme: IconThemeData(color: isDark ? Colors.white : _C.darkBg),
      title: Row(
        children: [
          Text('My Orders',
              style: AppText.title.copyWith(color: isDark ? white : grayBlack)),
          const SizedBox(width: 12),
          Expanded(
            child: Consumer<OrdersProvider>(
              builder: (_, provider, __) => _SearchField(
                isDark: isDark,
                value: provider.searchQuery,
                onChanged: provider.setSearchQuery,
                onClear: () => provider.setSearchQuery(''),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: reusableShimmerContainer(
                context: context, isDarkMode: isDark, height: 180),
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context, bool isDark) {
    return Consumer<OrdersProvider>(
      builder: (_, provider, __) => FloatingActionButton(
        onPressed: provider.fetchOrders,
        backgroundColor: _C.primary,
        elevation: 4,
        child: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
    );
  }

  // ─── Filter logic ────────────────────────────────────────────────────────
  List<OrderList> _filterOrders(List<OrderList> orders, String query) {
    if (query.isEmpty) return orders;
    final q = query.toLowerCase();
    return orders.where((order) {
      final total = order.cartItems
          .fold(0.0, (sum, item) => sum + (item.price * item.pieces))
          .toStringAsFixed(0);
      final phone = order.userDetails.phoneNumber ?? '';
      return order.orderId.toLowerCase().contains(q) ||
          order.orderDate.toLowerCase().contains(q) ||
          total.contains(q) ||
          phone.toLowerCase().contains(q);
    }).toList();
  }
}

// ─── Search Field ─────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final bool isDark;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.isDark,
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? _C.darkBg : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        onChanged: onChanged,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: isDark ? Colors.white : _C.darkBg,
        ),
        decoration: InputDecoration(
          hintText: 'Search orders...',
          hintStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: _C.muted,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: _C.muted, size: 18),
          suffixIcon: value.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: _C.muted, size: 16),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
        ),
      ),
    );
  }
}

// ─── Order Card ───────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final OrderList order;
  final bool isDark;

  const _OrderCard({required this.order, required this.isDark});
  Widget _buildImageStack(
      List<OrderProducts> cartItems, bool isDark, BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(cartItems.length, (i) {
        return Positioned(
          left: i * getResponsiveWidth(12),
          bottom: i * getResponsiveHeight(4),
          child: _buildSingleImage(cartItems[i], isDark, context),
        );
      }),
    );
  }

  Widget _buildImageRow(
      List<OrderProducts> cartItems, bool isDark, BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: math.min(4, cartItems.length), // Show first 4 for >3
      itemBuilder: (context, i) {
        return Padding(
          padding: EdgeInsets.only(right: getResponsiveWidth(8)),
          child: _buildSingleImage(cartItems[i], isDark, context),
        );
      },
    );
  }

  Widget _buildSingleImage(
      OrderProducts item, bool isDark, BuildContext context) {
    final String? imageUrl = item.photoUrl.isNotEmpty ? item.photoUrl[0] : null;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: getResponsiveWidth(50),
        height: getResponsiveHeight(50),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.image_not_supported,
            color: isDark ? white : darkBlack, size: 24),
      );
    }
    return Container(
      width: getResponsiveWidth(50),
      height: getResponsiveHeight(50),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: (isDark ? darkBlack : Colors.black).withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.image_not_supported,
                color: isDark ? white : darkBlack),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                valueColor:
                AlwaysStoppedAnimation<Color>(isDark ? green : purple),
              ),
            );
          },
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final totalAmount = order.cartItems
        .fold(0.0, (sum, item) => sum + (item.price * item.pieces));
    final totalItems = order.cartItems.length;
    final isDelivered = order.trackingStatus != null &&
        order.trackingStatus!.isNotEmpty &&
        order.trackingStatus!.last.trackingStatus == "Delivered";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? _C.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : _C.primary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? _C.darkBorder : Colors.grey.shade100,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Row(
              children: [
                // Product images
                Expanded(
                  flex: 1,
                  child: Container(
                    height: getResponsiveHeight(60),
                    child: totalItems <= 3
                        ? _buildImageStack(
                        order.cartItems, isDark, context)
                        : _buildImageRow(
                        order.cartItems, isDark, context),
                  ),
                ),
                // Order ID + Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : _C.darkBg,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${order.orderDate} · ${order.orderTime}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: _C.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                _StatusBadge(
                  fulfilled: order.fulfilled,
                  cancelled: order.cancelled,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Divider ───────────────────────────────────────────────
            Divider(
              color: isDark ? _C.darkBorder : Colors.grey.shade100,
              height: 1,
            ),
            const SizedBox(height: 12),

            // ── Details row ───────────────────────────────────────────
            Row(
              children: [
                _InfoChip(
                  icon: Icons.person_outline_rounded,
                  label: order.userDetails.fullName,
                  color: _C.primary,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.receipt_long_rounded,
                  label: '$totalItems items',
                  color: _C.warning,
                  isDark: isDark,
                ),
                const Spacer(),
                // Total amount
                Text(
                  'Rs. ${totalAmount.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _C.success,
                  ),
                ),
              ],
            ),

            // ── Address ───────────────────────────────────────────────
            if (order.userDetails.address != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_rounded, size: 14, color: _C.accent),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.userDetails.address!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: _C.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // ── Action Buttons ────────────────────────────────────────
            _ActionButtons(
              order: order,
              isDark: isDark,
              isDelivered: isDelivered,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final bool fulfilled;
  final bool? cancelled;
  final bool isDark;

  const _StatusBadge({
    required this.fulfilled,
    required this.cancelled,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (cancelled == true) {
      return _badge(Icons.cancel_outlined, 'Cancelled', _C.danger);
    }
    if (fulfilled) {
      return _badge(
          Icons.check_circle_outline_rounded, 'Fulfilled', _C.success);
    }
    return _badge(Icons.schedule_rounded, 'Pending', _C.warning);
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Chip ────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isDark ? Colors.white70 : _C.darkBg,
          ),
        ),
      ],
    );
  }
}

// ─── Action Buttons ───────────────────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  final OrderList order;
  final bool isDark;
  final bool isDelivered;

  const _ActionButtons({
    required this.order,
    required this.isDark,
    required this.isDelivered,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── Write Review (only after delivery) ────────────────────────
        // BUG FIX: was using outer `index` (order index), now uses 0
        // because review is for the first item; adjust if needed
        if (isDelivered)
          _ActionButton(
            icon: Icons.rate_review_outlined,
            label: 'Write Review',
            color: _C.warning,
            isDark: isDark,
            onTap: () {
              List<ReviewProduct> reviewProducts = [];

              for (var item in order.cartItems) {
                reviewProducts.add(
                  ReviewProduct(
                    docId: item.id.toString(),
                    gender: item.gender.toString(),
                    category: item.category.toString(),
                    productName: item.title,
                    imageUrl: item.photoUrl[0],
                    price: (item.price * item.pieces).toDouble(),
                    color: item.colorHex,
                    pieces: item.pieces
                  ),
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewScreen(
                      products: reviewProducts,
                    ),
                  ),
                );
              }
            },
          ),

        if (order.cancelled != true) ...[
          if (isDelivered) const SizedBox(width: 8),

          // ── Track Order ─────────────────────────────────────────────
          if (order.trackingId != null && order.trackingId!.isNotEmpty)
            _ActionButton(
              icon: Icons.local_shipping_outlined,
              label: 'Track Order',
              color: _C.primary,
              isDark: isDark,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => OrderTrackingScreen(order: order)),
              ),
            )

          // ── Cancel Order ────────────────────────────────────────────
          else
            _ActionButton(
              icon: Icons.cancel_outlined,
              label: 'Cancel',
              color: _C.danger,
              isDark: isDark,
              onTap: () => _confirmCancel(context),
            ),
        ] else
          // ── Cancelled chip ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _C.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.danger.withOpacity(0.3)),
            ),
            child: Text(
              'Order Cancelled',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _C.danger,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? _C.darkCard : white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel Order',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: isDark ? white : _C.darkCard)),
        content: Text('Are you sure you want to cancel this order?',
            style: GoogleFonts.poppins(fontSize: 14, color: _C.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No', style: GoogleFonts.poppins(color: _C.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes, Cancel',
                style: GoogleFonts.poppins(
                    color: _C.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('Orders')
            .doc(order.docId)
            .update({'cancelled': true});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order cancelled successfully',
                  style: GoogleFonts.poppins()),
              backgroundColor: _C.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Failed to cancel order', style: GoogleFonts.poppins()),
              backgroundColor: _C.danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Image Stack / Row ────────────────────────────────────────────────────────
class _ImageStack extends StatelessWidget {
  final List<OrderProducts> items;
  final bool isDark;

  const _ImageStack({required this.items, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(items.length, (i) {
        return Positioned(
          left: i * 14.0,
          bottom: i * 3.0,
          child: _OrderImage(item: items[i], isDark: isDark),
        );
      }),
    );
  }
}

class _ImageRow extends StatelessWidget {
  final List<OrderProducts> items;
  final bool isDark;

  const _ImageRow({required this.items, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        math.min(3, items.length),
        (i) => Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _OrderImage(item: items[i], isDark: isDark),
        ),
      ),
    );
  }
}

class _OrderImage extends StatelessWidget {
  final OrderProducts item;
  final bool isDark;

  const _OrderImage({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final url = item.photoUrl.isNotEmpty ? item.photoUrl[0] : null;

    return Container(
      width: 48,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? _C.darkBorder : Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color: isDark ? _C.darkBorder : Colors.grey.shade200,
                        child: const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: _C.primary,
                            ),
                          ),
                        ),
                      ),
                errorBuilder: (_, __, ___) => _placeholder(isDark),
              )
            : _placeholder(isDark),
      ),
    );
  }

  Widget _placeholder(bool isDark) {
    return Container(
      color: isDark ? _C.darkBorder : Colors.grey.shade200,
      child: Icon(Icons.image_not_supported_outlined,
          size: 18, color: isDark ? Colors.white38 : Colors.grey),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;
  final bool isDark;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: _C.primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : _C.darkBg,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: _C.muted,
            ),
          ),
        ],
      ),
    );
  }
}
