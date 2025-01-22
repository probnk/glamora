import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/HistoryModel.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/HistoryProvider.dart';
import 'package:glamora/screens/History/OrderHistoryVoice.dart';
import 'package:provider/provider.dart';

class History extends StatefulWidget {
  const History({super.key});

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  @override
  void initState() {
    super.initState();
    // Fetch order history when the screen is initialized
    context.read<HistoryProvider>().fetchOrderHistory();
  }

  // Build AppBar based on theme
  AppBar _buildAppBar(DarkModeProvider themeProvider) {
    return AppBar(
      backgroundColor: themeProvider.isDarkMode ? lightGrayBlack : white,
      iconTheme:
          IconThemeData(color: themeProvider.isDarkMode ? white : grayBlack),
      title: titleFont(
        text: "Order History",
        color: themeProvider.isDarkMode ? white : grayBlack,
      ),
      centerTitle: true,
    );
  }

  // Body of the History screen, which includes the list
  Widget _historyBody(DarkModeProvider themeProvider) {
    return ListView(
      shrinkWrap: true,
      physics: ScrollPhysics(),
      children: [_historyList(isDarkMode: themeProvider.isDarkMode)],
    );
  }

  // ListView to display order history
  Widget _historyList({required bool isDarkMode}) {
    final historyProvider = Provider.of<HistoryProvider>(context);
    return historyProvider.historyModelList.isEmpty
        ? _buildLoadingIndicator() // Show loading if no data
        : _buildHistoryList(historyProvider);
  }

  // A loading indicator while fetching the data
  Widget _buildLoadingIndicator() {
    return Center(child: CircularProgressIndicator());
  }

  // Display the history list
  Widget _buildHistoryList(HistoryProvider historyProvider) {
    return ListView.builder(
      shrinkWrap: true,
      physics: ScrollPhysics(),
      itemCount: historyProvider.historyModelList.length,
      itemBuilder: (context, index) {
        final order = historyProvider.historyModelList[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderItem(order, index),
            Divider(
              color: Colors.grey.shade100,
              thickness: 5,
              height: 0,
            )
          ],
        );
      },
    );
  }

  // Build individual order list item
  Widget _buildOrderItem(HistoryModel order, int index) {
    return Consumer<HistoryProvider>(builder: (context, value, child) {
      return InkWell(
        onTap: () {
          value.setSelectedOrderHistory(index);
        },
        child: Container(
          color:
              value.selectedOrderHistory == index ? Colors.grey.shade50 : white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  mediumFont(
                      text: "${order.orderId}",
                      color: grayBlack,
                      maxWidth: MediaQuery.of(context).size.width * .6,
                      weight: FontWeight.w600),
                  smallFont(text: "${order.orderTime}", color: Colors.grey)
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  smallFont(text: "${order.orderDate}", color: Colors.grey),
                  smallFont(
                      text:
                          "Total: Rs ${order.cartItems.fold(0, (total, item) => total + int.parse(item.total))}",
                      color: grayBlack,
                      weight: FontWeight.w600,
                      maxWidth: MediaQuery.of(context).size.width * .5)
                ],
              ),
              if (value.selectedOrderHistory == index) SizedBox(height: 10),
              if (value.selectedOrderHistory == index)
                InkWell(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => OrderHistoryVoice(orderDetails: order,)));
                  },
                  child: smallFont(
                      text: "View Detail's >",
                      color: grayBlack,
                      weight: FontWeight.w600),
                )
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
      appBar: _buildAppBar(themeProvider),
      body: _historyBody(themeProvider),
    );
  }
}
