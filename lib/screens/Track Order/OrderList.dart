import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Reuse Widgets/loadingShimmer.dart';
import '../../constants/reponsivness.dart';
import '../../models/OrderList.dart';
import '../../models/OrderProducts.dart';
import '../../providers/OrdersProvider.dart';
import 'TrackOrder.dart';
import '../../constants/fonts.dart';
import '../../constants/colors.dart';
import 'dart:math' as math;

class OrdersListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    final bool isDark = themeProvider.isDarkMode;
    final String? currentEmail = FirebaseAuth.instance.currentUser?.email;

    return Scaffold(
      backgroundColor: isDark ? darkBlack : white,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            productTitle(text: "My Orders",color: white),
            SizedBox(width: 4),
            Consumer<OrdersProvider>(
              builder: (ctx, provider, _) {
                return Expanded(
                  child: TextField(
                    onChanged: (value) => provider.setSearchQuery(value),
                    style: TextStyle(
                      color: isDark ? white : darkBlack,
                      fontSize: getResponsiveFontSize(14),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search Your Orders',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: getResponsiveFontSize(14),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        size: getResponsiveIconSize(20),
                      ),
                      suffixIcon: provider.searchQuery.isNotEmpty
                          ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: isDark ? white : darkBlack,
                        ),
                        onPressed: () => provider.setSearchQuery(''),
                      )
                          : null,
                      filled: true,
                      fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(21),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: getResponsiveWidth(16),
                        vertical: getResponsiveHeight(8),
                      ),
                    ),
                  ),
                );
              },
            )
          ],
        ),
        backgroundColor: isDark ? lightBlack : purple,
        elevation: 0,
        iconTheme: IconThemeData(color: white),
      ),
      body: Consumer<OrdersProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Padding(
              padding: EdgeInsets.all(getResponsiveWidth(8)),
              child: buildShimmerLoading(context, isDark),
            );
          }

          List<OrderList> userOrders = currentEmail != null
              ? provider.orders
              .where((order) => order.userDetails.email == currentEmail)
              .toList()
              : <OrderList>[];

          List<OrderList> filteredOrders = userOrders.where((order) {
            if (provider.searchQuery.isEmpty) return true;
            double totalAmount = order.cartItems
                .fold(0.0, (sum, item) => sum + (item.price * item.pieces));
            String amountStr = totalAmount.toStringAsFixed(0);
            String phone = order.userDetails.phoneNumber ?? '';
            return order.orderId.toLowerCase().contains(provider.searchQuery) ||
                order.orderDate.toLowerCase().contains(provider.searchQuery) ||
                amountStr.contains(provider.searchQuery) ||
                phone.toLowerCase().contains(provider.searchQuery);
          }).toList();

          if (userOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: getResponsiveIconSize(80),
                    color: isDark ? lightGrayBlack : Colors.grey[400],
                  ),
                  SizedBox(height: getResponsiveHeight(16)),
                  headingFont(
                    text: 'No Orders Found',
                    color: isDark ? white : darkBlack,
                  ),
                ],
              ),
            );
          }

          if (filteredOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: getResponsiveIconSize(80),
                    color: isDark ? lightGrayBlack : Colors.grey[400],
                  ),
                  SizedBox(height: getResponsiveHeight(16)),
                  headingFont(
                    text: provider.searchQuery.isEmpty
                        ? 'No Orders Yet'
                        : 'No Orders Matching Your Search',
                    color: isDark ? white : darkBlack,
                  ),
                  if (provider.searchQuery.isNotEmpty) ...[
                    SizedBox(height: getResponsiveHeight(8)),
                    smallFont(
                      text: 'Try adjusting your search terms',
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: responsivePadding(left: 16, right: 16, bottom: 16),
            itemCount: filteredOrders.length,
            itemBuilder: (context, index) {
              final order = filteredOrders[index];
              final isFulfilled =
              order.fulfilled ? Icons.check_circle : Icons.schedule;
              final statusColor = order.fulfilled
                  ? isDark
                  ? lightGreen
                  : darkGreen.withAlpha(150)
                  : isDark
                  ? lightOrange
                  : darkOrange.withAlpha(150);

              // Calculate total items and total amount
              int totalItems = order.cartItems.length;
              double totalAmount = order.cartItems
                  .fold(0.0, (sum, item) => sum + (item.price * item.pieces));

              return Card(
                elevation: isDark ? 0 : 4,
                margin: EdgeInsets.only(
                    bottom: getResponsiveHeight(16),
                    top: getResponsiveHeight(16)),
                color: isDark ? lightBlack : white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(getResponsiveWidth(16)),
                  side: BorderSide(
                      color: isDark ? lightGrayBlack : Colors.grey[200]!,
                      width: 0.5),
                ),
                child: Padding(
                  padding: responsivePadding(
                      left: 16, right: 16, top: 16, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Order ID, Date/Time, Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
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
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                productTitle(
                                    text: order.orderId,
                                    color: isDark ? white : darkBlack,
                                    maxWidth: 200),
                                SizedBox(height: getResponsiveHeight(4)),
                                smallFont(
                                  text:
                                  '${order.orderDate} at ${order.orderTime}',
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: responsivePadding(
                                left: 8, right: 8, top: 4, bottom: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              isFulfilled,
                              color: statusColor,
                              size: getResponsiveIconSize(20),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: getResponsiveHeight(12)),
                      // Customer Details
                      Row(
                        children: [
                          Icon(Icons.person,
                              size: 20,
                              color: isDark
                                  ? lightBlue
                                  : darkBlue2),
                          SizedBox(width: getResponsiveWidth(8)),
                          Expanded(
                            child: mediumFont(
                              align: TextAlign.start,
                              text: 'Customer: ${order.userDetails.fullName}',
                              color: isDark ? white : darkBlack,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: getResponsiveHeight(8)),
                      // Total Amount and Items Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.attach_money,
                                  size: 20,
                                  color: isDark
                                      ? green
                                      : darkGreen),
                              SizedBox(width: getResponsiveWidth(8)),
                              mediumFont(
                                align: TextAlign.start,
                                text:
                                'Total: Rs. ${totalAmount.toStringAsFixed(0)}',
                                color: isDark ? green : darkGreen,
                                weight: FontWeight.w600,
                              ),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.shopping_cart,
                                  size: 20,
                                  color: isDark
                                      ? Colors.yellow
                                      :Colors.yellow.shade700),
                              SizedBox(width: getResponsiveWidth(8)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  smallFont(
                                    align: TextAlign.start,
                                    text: 'Items: $totalItems',
                                    color: isDark ? white : darkBlack,
                                  ),
                                  SizedBox(height: getResponsiveHeight(4)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Add more details if available, e.g., delivery address or total
                      if (order.userDetails.address != null) ...[
                        SizedBox(height: getResponsiveHeight(8)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on,
                                size: 20,
                                color: isDark
                                    ? lightOrange
                                    : darkOrange),
                            SizedBox(width: getResponsiveWidth(8)),
                            Expanded(
                              child: smallFont(
                                align: TextAlign.start,
                                text: 'Address: ${order.userDetails.address}',
                                color: isDark ? Colors.grey.shade300 : lightBlack,
                                maxLine: 2,
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: getResponsiveHeight(12)),
                      // Tracking Button if available
                      // Assuming these fields exist on your model
// order.trackingId  → String?
// order.isCancelled → bool
// order.id          → String (document ID)

                      if (order.cancelled == false) ...[
                        // 1. Tracking button – show only when trackingId exists
                        if (order.trackingId != null && order.trackingId!.isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderTrackingScreen(order: order),
                                  ),
                                );
                              },
                              icon: Icon(Icons.track_changes,
                                  size: 16, color: isDark ? green : purple),
                              label: mediumFont(
                                text: 'Track Order',
                                color: isDark ? green : purple,
                                weight: FontWeight.w600,
                              ),
                              style: TextButton.styleFrom(
                                padding: responsivePadding(
                                    left: 16, right: 16, top: 8, bottom: 8),
                                backgroundColor:
                                isDark ? green.withAlpha(50) : purple.withAlpha(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(getResponsiveWidth(20)),
                                ),
                              ),
                            ),
                          )
                        // 2. Cancel button – show only when NO trackingId (order not shipped yet)
                        else if (order.trackingId == null || order.trackingId!.isEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () async {
                                // Optional: show confirmation dialog
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text("Cancel Order"),
                                    content: Text("Are you sure you want to cancel this order?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: Text("No"),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: Text("Yes"),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('Orders')
                                        .doc(order.docId) // or order.orderId whatever your doc ID field is
                                        .update({'cancelled': true});

                                    // Optional: show success message
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Order cancelled successfully")),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Failed to cancel order")),
                                    );
                                  }
                                }
                              },
                              icon: Icon(Icons.cancel, size: 16, color: Colors.red),
                              label: mediumFont(
                                text: 'Cancel Order',
                                color: Colors.red,
                                weight: FontWeight.w600,
                              ),
                              style: TextButton.styleFrom(
                                padding: responsivePadding(
                                    left: 16, right: 16, top: 8, bottom: 8),
                                backgroundColor: Colors.red.withAlpha(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(getResponsiveWidth(20)),
                                ),
                              ),
                            ),
                          ),

// 3. If order is already cancelled → show a simple label (optional)
                      ] else
                        Align(
                          alignment: Alignment.centerRight,
                          child: Chip(
                            backgroundColor: Colors.red.withOpacity(0.2),
                            label: Text(
                              "Order Cancelled",
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Consumer<OrdersProvider>(
        builder: (context, provider, child) {
          return FloatingActionButton(
            onPressed: provider.fetchOrders,
            backgroundColor: isDark ? lightBlack : purple,
            child: Icon(Icons.refresh, color: white),
          );
        },
      ),
    );
  }

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
}