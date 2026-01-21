// order_details.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glamora/BottomNavBar/BottomNavBar.dart';
import 'package:glamora/Reuse%20Widgets/cartProductsList.dart';
import 'package:glamora/Services/payment_button.dart';
import 'package:glamora/Services/personalization_service.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/ColorVariantModel.dart';
import 'package:glamora/models/SizesVariants.dart';
import 'package:glamora/models/TackingStatusModel.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/providers/CartProvider.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/UserDetailsProvider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../Services/sendNotifcationService.dart';
import '../../models/cartProducts.dart';

class OrderDetails extends StatefulWidget {
  final List<CartProducts> itemsToCheckout;

  OrderDetails({
    super.key,
    required this.itemsToCheckout,
  });

  @override
  State<OrderDetails> createState() => _OrderDetailsState();
}

class _OrderDetailsState extends State<OrderDetails> {
  Future<void> _addOrder() async {
    try {
      final userDetails = Provider.of<UserDetailsProvider>(context, listen: false);
      final cartItems = Provider.of<CartProvider>(context, listen: false);
      int timestamp = DateTime.now().millisecondsSinceEpoch;

      DateTime now = DateTime.now();
      String _formattedDate = DateFormat('d MMMM, yyyy').format(now);
      String _formattedTime = DateFormat('h:mm a').format(now);

      Map<String, dynamic> userDetailsMap = {
        'fullName': userDetails.userDetails.fullName,
        'email': userDetails.userDetails.email,
        'address': userDetails.userDetails.address,
        'phoneNumber': userDetails.userDetails.phoneNumber,
        'zipCode': userDetails.userDetails.zipCode,
      };

      String orderId = 'ORD$timestamp';
      final currentUser = FirebaseAuth.instance.currentUser!.uid;

      var orderCartItems = widget.itemsToCheckout.map((item) => item.toMap()).toList();

      final docRef = await FirebaseFirestore.instance.collection("Orders").add({
        'docId': '',
        'orderId': orderId,
        'orderDate': _formattedDate,
        'orderTime': _formattedTime,
        'userDetails': userDetailsMap,
        'uid': currentUser,
        'cartItems': orderCartItems,
        'paid': false,
        'fulfilled': false,
        'cancelled': false,
        'trackingId': "",
        'trackingUrl': "",
        'trackingStatus': [],
      });

      await docRef.update({'docId': docRef.id});

      await FirebaseFirestore.instance
          .collection("History")
          .doc(currentUser)
          .collection("orderHistory")
          .doc()
          .set({
        'orderId': orderId,
        'orderDate': _formattedDate,
        'orderTime': _formattedTime,
        'userDetails': userDetailsMap,
        'cartItems': orderCartItems,
        'paid': false,
        'fulfilled': false,
        'status': "unseen",
        'trackingId': "",
        'trackingUrl': "",
        'trackingStatus': [],
      });

      var total = widget.itemsToCheckout.fold(0, (sum, item) => sum + int.parse(item.total));

      for (int i = 0; i < widget.itemsToCheckout.length; i++) {
        if(currentUser != null){
          trackPersonalization(FirebaseAuth.instance.currentUser!.uid,
              widget.itemsToCheckout[i].category, "order",'increment');
          cartItems.deleteCartItem(widget.itemsToCheckout[i]);
        }
      }

      SendNotificationService.sendNotificationUsingApi(
          body: "Order Id: $orderId with Total Bill ${total.toString()}",
          title: "New Order Placed!",
          data: {"screen": "notification"},
          topic: 'Orders');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BottomNavBar()),
      );
      print('Order successfully added to History!');
    } catch (e) {
      print('Error adding order: $e');
    }
  }

  Future<void> _updateStockBySize({
    required String productId,
    required String category,
    required String gender,
    required String size,
    required int quantity,
    int variantIndex = 0,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection("Cloths")
          .doc(gender)
          .collection(category)
          .doc(productId);

      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        print("Product not found");
        return;
      }

      ClothingProductModel product = ClothingProductModel.fromSnapshot(docSnap);
      var selectedVariant = product.variants[variantIndex];

      List<ClothingSizesModel> updatedSizes = selectedVariant.sizes.map((s) {
        if (s.size == size) {
          return ClothingSizesModel(
            size: s.size,
            stock: s.stock - quantity,
          );
        }
        return s;
      }).toList();

      selectedVariant = ClothingVariantModel(
        colors: selectedVariant.colors,
        sizes: updatedSizes,
      );

      product.variants[variantIndex] = selectedVariant;
      int updatedTotalOrders = product.totalOrders + quantity;

      await docRef.update({
        "totalOrders": updatedTotalOrders,
        "variants": product.variants.map((v) => v.toMap()).toList(),
      });

      print("Stock updated for size $size and totalOrders updated.");
    } catch (e) {
      print("Error: $e");
    }
  }

  _orderDetailsBody({required bool isDarkMode}) {
    return ListView(
      shrinkWrap: true,
      physics: ScrollPhysics(),
      children: [
        _orderItemsList(isDarkMode: isDarkMode),
        SizedBox(height: 10),
        _customerInfo(isDarkMode: isDarkMode),
        SizedBox(height: 10),
        Divider(color: Colors.grey.shade300),
        _orderInfo(isDarkMode: isDarkMode),
        Padding(
            padding: EdgeInsets.only(left: 16),
            child: productTitle(
                text: "Payment Method: Cash On Delivery (COD)",
                color: isDarkMode ? white : grayBlack)),
        Divider(color: isDarkMode ? Colors.grey : Colors.grey.shade300),
        SizedBox(height: 20),
      ],
    );
  }

  _orderItemsList({required bool isDarkMode}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: widget.itemsToCheckout.length,
      itemBuilder: (context, index) {
        return cartClothCardDesign(
          cartItems: widget.itemsToCheckout[index],
          context: context,
          isCart: true,
          isDarkMode: isDarkMode,
        );
      },
    );
  }

  Widget _customerInfo({required bool isDarkMode}) {
    return Consumer<UserDetailsProvider>(
      builder: (context, value, child) {
        final user = value.userDetails;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDarkMode ? Colors.grey : grayBlack,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    titleFont(
                      text: "Customer Info",
                      color: isDarkMode ? white : grayBlack,
                    ),
                    InkWell(
                      onTap: () {
                        // TODO: open edit screen / bottom sheet
                      },
                      child: Icon(
                        Icons.edit,
                        size: 20,
                        color: isDarkMode ? Colors.white70 : grayBlack,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                _infoLine(user.fullName),
                _infoLine(user.phoneNumber),
                _infoLine(user.email ?? ""),
                _infoLine(user.address),
                _infoLine(user.zipCode),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: smallFont(
        text: text,
        color: Colors.grey,
        align: TextAlign.start,
      ),
    );
  }

  Widget _orderInfo({required bool isDarkMode}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDarkMode ? Colors.grey : grayBlack,
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            titleFont(
              text: "Order Summary",
              color: isDarkMode ? white : grayBlack,
            ),

            const SizedBox(height: 12),

            _orderRow(
              "Sub Total",
              "Rs ${_calculateTotal()}",
              isDarkMode,
            ),

            const SizedBox(height: 6),

            _orderRow(
              "Shipping",
              "Free Delivery",
              isDarkMode,
              highlight: true,
            ),

            const SizedBox(height: 6),

            _orderRow(
              "Coupon Discount",
              "0%",
              isDarkMode,
            ),

            const SizedBox(height: 12),

            Divider(
              color: isDarkMode ? Colors.white24 : Colors.black26,
              thickness: 1,
            ),

            const SizedBox(height: 12),

            _orderRow(
              "Total Amount",
              "Rs ${_calculateTotal()}",
              isDarkMode,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderRow(
      String title,
      String value,
      bool isDarkMode, {
        bool highlight = false,
        bool isTotal = false,
      }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        smallFont(
          text: title,
          color: isDarkMode ? Colors.white70 : Colors.black87,
          weight: isTotal ? FontWeight.w600 : FontWeight.w400,
        ),
        highlight
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: mediumFont(text: value,weight: FontWeight.w600,color: Colors.green),
        )
            : smallFont(
          text: value,
          color: isTotal
              ? (isDarkMode ? Colors.white : grayBlack)
              : (isDarkMode ? Colors.white60 : Colors.black87),
          weight: isTotal ? FontWeight.w700 : FontWeight.w400,
        ),
      ],
    );
  }


  int _calculateTotal() {
    return widget.itemsToCheckout.fold(0, (sum, item) => sum + int.parse(item.total));
  }

  _orderInfoRows({
    required String title,
    required String price,
    required bool isDarkMode}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        smallFont(text: title, color: isDarkMode ? white : grayBlack),
        smallFont(text: price, color: Colors.grey)
      ],
    );
  }

  _confirmButton(bool isDarkMode) {
    return Container(
      height: 70,
      padding: EdgeInsets.symmetric(vertical: 10),
      width: double.infinity,
      color: lightGrayBlack,
      child: InkWell(
        onTap: () {
          for (int i = 0; i < widget.itemsToCheckout.length; i++) {
            _updateStockBySize(
              productId: widget.itemsToCheckout[i].id,
              category: widget.itemsToCheckout[i].category,
              gender: widget.itemsToCheckout[i].gender,
              size: widget.itemsToCheckout[i].size,
              quantity: widget.itemsToCheckout[i].pieces,
            );
          }
          _addOrder();
        },
        child: Card(
          margin: EdgeInsets.symmetric(horizontal: 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 3,
          child: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 60),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: isDarkMode
                    ? [lightOrange, darkOrange]
                    : [lightBlack, darkBlack],
              ),
            ),
            child: smallFont(text: "Checkout", color: white),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: themeProvider.isDarkMode ? lightGrayBlack : white,
        iconTheme:
        IconThemeData(color: themeProvider.isDarkMode ? white : grayBlack),
        centerTitle: true,
        title: titleFont(
            text: "Order Details",
            color: themeProvider.isDarkMode ? white : grayBlack),
      ),
      bottomSheet: _confirmButton(themeProvider.isDarkMode),
      backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
      body: _orderDetailsBody(isDarkMode: themeProvider.isDarkMode),
    );
  }
}