import 'package:flutter/material.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/HistoryModel.dart';
import 'package:glamora/screens/Review/Review.dart';

class OrderHistoryVoice extends StatefulWidget {
  HistoryModel orderDetails;

  OrderHistoryVoice({super.key, required this.orderDetails});

  @override
  State<OrderHistoryVoice> createState() => _OrderHistoryVoiceState();
}

class _OrderHistoryVoiceState extends State<OrderHistoryVoice> {
  _orderHistoryBody() {
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
              color: grayBlack,
              align: TextAlign.start),
          SizedBox(height: 20),
          smallFont(
              text: "Hello ${widget.orderDetails.userDetails['fullName']},",
              color: grayBlack,
              align: TextAlign.start,
              weight: FontWeight.w500),
          SizedBox(height: 5),
          smallFont(
            text:
                "Your order has been confirmed and will be shipping within next 2 Business days",
            color: Colors.grey,
            align: TextAlign.start,
          ),
          SizedBox(height: 40),
          _orderHeaderDetails(
              header: "Order Date", data: widget.orderDetails.orderDate),
          _orderHeaderDetails(
              header: "Order No", data: widget.orderDetails.orderId),
          _orderHeaderDetails(header: "Payment", data: "Cash on Delivery"),
          _orderHeaderDetails(
              header: "Shipping Address",
              data: widget.orderDetails.userDetails['address']),
          SizedBox(height: 30),
          _orderProductList(historyModel: widget.orderDetails),
          SizedBox(height: 20),
          _orderTotalling(header: "SubTotal", body: total),
          _orderTotalling(header: "Shipping Fee", body: "Free Delivery"),
          _orderTotalling(header: "Tax Fee", body: "0%"),
          _orderTotalling(
              header: "Discount",
              body: widget.orderDetails.cartItems[0].discount.toString()),
          SizedBox(height: 5),
          Divider(height: 0, thickness: 1, color: Colors.grey),
          SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              mediumFont(
                  text: "Total", color: grayBlack, weight: FontWeight.bold),
              SizedBox(width: 20),
              smallFont(text: total, color: lightGrayBlack),
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
          smallFont(text: "Glamora Team", color: Colors.grey),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  _orderHeaderDetails({required String header, required String data}) {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          smallFont(text: header, color: Colors.grey, align: TextAlign.start),
          smallFont(
            text: "$data",
            color: lightGrayBlack,
            align: TextAlign.start,
          ),
        ],
      ),
    );
  }

  _orderProductList({required HistoryModel historyModel}) {
    return ListView.builder(
        itemCount: historyModel.cartItems.length,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          var item = historyModel.cartItems[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Image.network(item.imageUrl.toString(),
                          width: 60, height: 60),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          smallFont(
                              text: "${item.title}",
                              color: lightGrayBlack,
                              weight: FontWeight.w600),
                          smallFont(
                              text: "${item.pieces} x Rs${item.newPrice}",
                              color: Colors.grey),
                          smallFont(
                              text: "Discount: ${item.discount}",
                              color: lightGrayBlack)
                        ],
                      ),
                    ],
                  ),
                  smallFont(
                      text: "Rs ${item.total}",
                      color: grayBlack,
                      weight: FontWeight.w500),
                ],
              ),
              SizedBox(height: 8),
              ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => Review(
                                title: widget
                                    .orderDetails.cartItems[index].title
                                    .toString())));
                  },
                  style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      backgroundColor: Colors.blue,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child: smallFont(text: "Write a Review"))
            ],
          );
        });
  }

  _orderTotalling({required String header, required String body}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        smallFont(text: header, color: Colors.grey),
        SizedBox(height: 4),
        smallFont(text: body, color: lightGrayBlack),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      backgroundColor: white,
      body: _orderHistoryBody(),
    );
  }
}
