import 'package:flutter/material.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/HistoryModel.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/screens/Review/Review.dart';
import 'package:provider/provider.dart';

class OrderHistoryVoice extends StatefulWidget {
  HistoryModel orderDetails;

  OrderHistoryVoice({super.key, required this.orderDetails});

  @override
  State<OrderHistoryVoice> createState() => _OrderHistoryVoiceState();
}

class _OrderHistoryVoiceState extends State<OrderHistoryVoice> {
  _orderHistoryBody({required bool isDarkMode}) {
    var total = widget.orderDetails.cartItems
        .fold(0, (total, item) => total + int.parse(item.total))
        .toString();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        physics: ScrollPhysics(),
        shrinkWrap: true,
        children: [
          mediumFont(
              text: "Your Order Confirmed",
              color: isDarkMode ? white : grayBlack,
              align: TextAlign.start),
          SizedBox(height: 20),
          smallFont(
              text: "Hello ${widget.orderDetails.userDetails['fullName']},",
              color: isDarkMode ? white : grayBlack,
              align: TextAlign.start,
              weight: FontWeight.w500),
          SizedBox(height: 5),
          smallFont(
            text:
                "Your order has been confirmed and will be shipping within next 2 Business days",
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
            align: TextAlign.start,
          ),
          SizedBox(height: 40),
          mediumFont(
              text: "Order Details",
              color: isDarkMode ? white : grayBlack,
              align: TextAlign.start),
          _orderHeaderDetails(
              header: "Order Date",
              data: widget.orderDetails.orderDate,
              isDarkMode: isDarkMode),
          _orderHeaderDetails(
              header: "Order No",
              data: widget.orderDetails.orderId,
              isDarkMode: isDarkMode),
          _orderHeaderDetails(
              header: "Payment",
              data: "Cash on Delivery",
              isDarkMode: isDarkMode),
          _orderHeaderDetails(
              header: "Shipping Address",
              data: widget.orderDetails.userDetails['address'],
              isDarkMode: isDarkMode),
          SizedBox(height: 30),
          _orderProductList(
              historyModel: widget.orderDetails, isDarkMode: isDarkMode),
          SizedBox(height: 20),
          _orderTotalling(
              header: "SubTotal", body: "Rs ${total}", isDarkMode: isDarkMode),
          _orderTotalling(
              header: "Shipping Fee",
              body: "Free Delivery",
              isDarkMode: isDarkMode),
          _orderTotalling(
              header: "Tax Fee", body: "0%", isDarkMode: isDarkMode),
          _orderTotalling(
              header: "Discount",
              body: "${widget.orderDetails.cartItems[0].discount.toString()}%",
              isDarkMode: isDarkMode),
          SizedBox(height: 5),
          Divider(height: 0, thickness: 1, color: Colors.grey),
          SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              mediumFont(
                  text: "Total",
                  color: isDarkMode ? white : grayBlack,
                  weight: FontWeight.bold),
              SizedBox(width: 20),
              smallFont(
                  text: total, color: isDarkMode ? white : lightGrayBlack),
            ],
          ),
          SizedBox(height: 20),
          smallFont(
              text:
                  "We'll be sending a shipping confirmation email email when the items shipped successfully\n",
              color: Colors.grey,
              align: TextAlign.start),
          SizedBox(height: 10),
          mediumFont(
              text: "Thanks You for shopping with us!", color: grayBlack),
          smallFont(text: "Vision Cart Pro Team", color: Colors.grey),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  _orderHeaderDetails(
      {required String header,
      required String data,
      required bool isDarkMode}) {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          smallFont(
              text: header,
              color: isDarkMode ? white : Colors.grey,
              align: TextAlign.start),
          smallFont(
            text: "$data",
            color: isDarkMode ? Colors.grey.shade400 : lightGrayBlack,
            align: TextAlign.start,
          ),
        ],
      ),
    );
  }

  _orderProductList(
      {required HistoryModel historyModel, required bool isDarkMode}) {
    return ListView.builder(
        itemCount: historyModel.cartItems.length,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          var item = historyModel.cartItems[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isDarkMode ? lightGrayBlack : Colors.grey.shade300),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.images[0].toString(),
                              width: 100,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            smallFont(
                                text: "${item.title}",
                                color: isDarkMode ? white : lightGrayBlack,
                                weight: FontWeight.w600),
                            smallFont(
                                text:
                                    "${item.pieces} x Rs${((item.price / 100) * (100 - item.discount))}",
                                color: isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey),
                            smallFont(
                                text: "Discount: ${item.discount}%",
                                color: isDarkMode ? white : lightGrayBlack),
                            Row(
                              children: [
                                Container(
                                  margin: EdgeInsets.zero,
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: item.colorHex,
                                    border: Border.all(
                                        color: isDarkMode
                                            ? white
                                            : Colors.grey.shade300),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 10),
                                mediumFont(
                                    text: item.size,
                                    color: isDarkMode ? white : grayBlack),
                                SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width * .2),
                                mediumFont(
                                    text: "Rs ${item.total}",
                                    color: isDarkMode ? white : grayBlack,
                                    weight: FontWeight.bold),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                  onPressed: () {
                    List<ReviewProduct> reviewProducts = [];

                    for (var item in widget.orderDetails.cartItems) {
                      reviewProducts.add(
                        ReviewProduct(
                          docId: item.id.toString(),
                          gender: item.gender.toString(),
                          category: item.category.toString(),
                          productName: item.title,
                          imageUrl: item.images[0],
                          price: (item.price * item.pieces).toDouble(),
                          color: item.colorHex,
                          pieces: item.pieces
                        ),
                      );
                    }
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                ReviewScreen(products: reviewProducts)));
                  },
                  style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      backgroundColor: isDarkMode ? darkGreen : Colors.blue,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child: smallFont(text: "Write a Review"))
            ],
          );
        });
  }

  _orderTotalling(
      {required String header,
      required String body,
      required bool isDarkMode}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        smallFont(text: header, color: isDarkMode ? white : Colors.grey),
        SizedBox(height: 4),
        smallFont(
            text: body,
            color: isDarkMode ? Colors.grey.shade400 : lightGrayBlack),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: headingFont(
            text: "History",
            color: themeProvider.isDarkMode ? white : grayBlack),
        iconTheme:
            IconThemeData(color: themeProvider.isDarkMode ? white : grayBlack),
        backgroundColor:
            themeProvider.isDarkMode ? lightGrayBlack : Colors.white,
      ),
      backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
      body: _orderHistoryBody(isDarkMode: themeProvider.isDarkMode),
    );
  }
}
