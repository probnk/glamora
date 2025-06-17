import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:glamora/BottomNavBar/BottomNavBar.dart';
import 'package:glamora/Reuse%20Widgets/cartProductsList.dart';
import 'package:glamora/Services/notificationService.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/ColorVariantModel.dart';
import 'package:glamora/models/SizesVariants.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/providers/CartProvider.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/UserDetailsProvider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../Services/sendNotifcationService.dart';

class OrderDetails extends StatefulWidget {
  OrderDetails({
    super.key,
  });

  @override
  State<OrderDetails> createState() => _OrderDetailsState();
}

class _OrderDetailsState extends State<OrderDetails> {

  Future<void> _addOrder() async {
    try {
      final userDetails =
          Provider.of<UserDetailsProvider>(context, listen: false);
      final cartItems = Provider.of<CartProvider>(context, listen: false);
      int timestamp = DateTime.now().millisecondsSinceEpoch;

      DateTime now = DateTime.now();
      String _formattedDate = DateFormat('d MMMM, yyyy').format(now);
      String _formattedTime = DateFormat('h:mm a').format(now);

      // User details map
      Map<String, dynamic> userDetailsMap = {
        'fullName': userDetails.userDetails.fullName,
        'email': userDetails.userDetails.email,
        'address': userDetails.userDetails.address,
        'phoneNumber': userDetails.userDetails.phoneNumber,
        'zipCode': userDetails.userDetails.zipCode,
      };

      // Create unique order number based on timestamp
      String orderId = 'ORD$timestamp';

      // Create a list of HistoryProductItems from cartItems
      var copiedCartItems =
          cartItems.cartItems.map((item) => item.toMap()).toList();
      // ✅ Step 1: Add the order to Firestore
      final docRef = await FirebaseFirestore.instance.collection("Orders").add({
        'docId': '', // placeholder, will update
        'orderId': orderId,
        'orderDate': _formattedDate,
        'orderTime': _formattedTime,
        'userDetails': userDetailsMap,
        'cartItems': copiedCartItems,
        'paid': false,
        'fulfilled': false,
        'cancelled':false
      });

      // ✅ Step 2: Update the doc with its own ID
      await docRef.update({'docId': docRef.id});

// Create the HistoryModel with copied cart item

// Save to Firestore under History collection
      await FirebaseFirestore.instance
          .collection("History")
          .doc(FirebaseAuth.instance.currentUser!.email)
          .collection("orderHistory")
          .doc()
          .set({
        'orderId': orderId,
        'orderDate': _formattedDate,
        'orderTime': _formattedTime,
        'userDetails': userDetailsMap,
        'cartItems': copiedCartItems,
        'paid': false,
        'fulfilled': false,
        'status': "unseen",
      });
      var total = context
          .read<CartProvider>()
          .cartItems
          .fold(0, (sum, item) => sum + int.parse(item.total));

      // Now clear the cart items after the order is successfully added
      for (int i = 0; i < cartItems.cartItems.length; i++) {
        cartItems.deleteCartItem(cartItems.cartItems[i]);
      }
      cartItems.cartItems.clear();
      SendNotificationService.sendNotificationUsingApi(
          orderId: timestamp.toString(),
          total: total.toString(),
          body: "",
          data: {"screen": "notification"});
      // Navigate to the BottomNavBar after the order is completed
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
    int variantIndex = 0, // which variant to update
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

      // Load model
      ClothingProductModel product = ClothingProductModel.fromSnapshot(docSnap);

      // Get the correct variant
      var selectedVariant = product.variants[variantIndex];

      // Update the matching size's stock
      List<ClothingSizesModel> updatedSizes = selectedVariant.sizes.map((s) {
        if (s.size == size) {
          return ClothingSizesModel(
            size: s.size,
            stock: s.stock - quantity,
          );
        }
        return s;
      }).toList();

      // Replace sizes in selected variant
      selectedVariant = ClothingVariantModel(
        colors: selectedVariant.colors,
        sizes: updatedSizes,
      );

      // Replace the variant in the list
      product.variants[variantIndex] = selectedVariant;

      // Update total orders
      int updatedTotalOrders = product.totalOrders + quantity;

      // Push to Firestore
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
        shoppingCartBody(isDarkMode: isDarkMode),
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
        _confirmButton(isDarkMode: isDarkMode),
        SizedBox(height: 20)
      ],
    );
  }

  _customerInfo({required bool isDarkMode}) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Consumer<UserDetailsProvider>(builder: (context, value, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleFont(
                  text: "Customer Info", color: isDarkMode ? white : grayBlack),
              smallFont(
                  text: value.userDetails.fullName,
                  color: Colors.grey,
                  align: TextAlign.start),
              smallFont(
                  text: value.userDetails.phoneNumber,
                  color: Colors.grey,
                  align: TextAlign.start),
              smallFont(
                  text: value.userDetails.email ?? "",
                  color: Colors.grey,
                  align: TextAlign.start),
              smallFont(
                  text: value.userDetails.address,
                  color: Colors.grey,
                  align: TextAlign.start),
              smallFont(
                  text: value.userDetails.zipCode,
                  color: Colors.grey,
                  align: TextAlign.start),
            ],
          );
        }));
  }

  _orderInfo({required bool isDarkMode}) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Consumer<CartProvider>(builder: (context, value, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleFont(
                  text: "Order Info", color: isDarkMode ? white : grayBlack),
              _orderInfoRows(
                  title: "subTotal",
                  price: "Rs ${value.totalAmount}",
                  isDarkMode: isDarkMode),
              _orderInfoRows(
                  title: "Shipping Cost",
                  price: "Free Delivery",
                  isDarkMode: isDarkMode),
              _orderInfoRows(
                  title: "Extra Coupon Discount",
                  price: "0%",
                  isDarkMode: isDarkMode),
              SizedBox(height: 10),
              _orderInfoRows(
                  title: "Total",
                  price: "Rs ${value.totalAmount}",
                  isDarkMode: isDarkMode),
            ],
          );
        }));
  }

  _orderInfoRows(
      {required String title,
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

  _confirmButton({required bool isDarkMode}) {
    return Consumer<CartProvider>(builder: (context, cartValue, child) {
      return InkWell(
        onTap: () {
          for (int i = 0; i < cartValue.cartItems.length; i++) {
            _updateStockBySize(
                productId: cartValue.cartItems[0].id,
                category: cartValue.cartItems[0].category,
                gender: cartValue.cartItems[0].gender,
                size: cartValue.cartItems[0].size,
                quantity: cartValue.cartItems[0].pieces);
          }
          _addOrder();
        },
        child: Card(
          margin: EdgeInsets.symmetric(horizontal: 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 3,
          child: Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 60),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: isDarkMode
                          ? [lightOrange, darkOrange]
                          : [lightBlack, darkBlack])),
              child: smallFont(text: "Checkout", color: white)),
        ),
      );
    });
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
      backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
      body: _orderDetailsBody(isDarkMode: themeProvider.isDarkMode),
    );
  }
}
