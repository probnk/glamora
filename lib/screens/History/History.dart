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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HistoryProvider>(context, listen: false).fetchOrderHistory();
    });
  }

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

  Widget _historyBody(DarkModeProvider themeProvider) {
    return ListView(
      shrinkWrap: true,
      physics: ScrollPhysics(),
      children: [_historyList(isDarkMode: themeProvider.isDarkMode)],
    );
  }

  Widget _historyList({required bool isDarkMode}) {
    final historyProvider = Provider.of<HistoryProvider>(context);

    if (historyProvider.isLoading) {
      return _buildLoadingIndicator();
    }

    return historyProvider.historyModelList.isEmpty
        ? _buildEmptyIcon()
        : _buildHistoryList(historyProvider, isDarkMode);
  }

  Widget _buildEmptyIcon() {
    return Center(
      child: Icon(Icons.history, size: 80, color: Colors.grey),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
        child: CircularProgressIndicator(
          color: Colors.grey.shade300,
        ));
  }

  Widget _buildHistoryList(HistoryProvider historyProvider, bool isDarkMode) {
    return ListView.builder(
      shrinkWrap: true,
      physics: ScrollPhysics(),
      itemCount: historyProvider.historyModelList.length,
      itemBuilder: (context, index) {
        final order = historyProvider.historyModelList[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderItem(order, index, isDarkMode),
            Divider(
              color: isDarkMode ? grayBlack : Colors.grey.shade100,
              thickness: 5,
              height: 0,
            )
          ],
        );
      },
    );
  }

  Widget _buildOrderItem(HistoryModel order, int index, bool isDarkMode) {
    return Consumer<HistoryProvider>(builder: (context, value, child) {
      return InkWell(
        onTap: () {
          value.setSelectedOrderHistory(index);
        },
        child: Container(
          color: isDarkMode
              ? (value.selectedOrderHistory == index
              ? darkGreen.withAlpha(150)
              : lightGrayBlack)
              : (value.selectedOrderHistory == index
              ? Colors.grey.shade50
              : grayBlack),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  mediumFont(
                      text: "${order.orderId}",
                      color: isDarkMode ? white : grayBlack,
                      maxWidth: MediaQuery.of(context).size.width * .6,
                      weight: FontWeight.w600),
                  smallFont(text: "${order.orderTime}", color:isDarkMode ? Colors.grey.shade300 : Colors.grey)
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  smallFont(text: "${order.orderDate}", color: isDarkMode ? Colors.grey.shade300 : Colors.grey),
                  smallFont(
                      text:
                      "Total: Rs ${order.cartItems.fold(0, (total, item) => total + int.parse(item.total))}",
                      color: isDarkMode ? white : grayBlack,
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
                            builder: (context) => OrderHistoryVoice(
                              orderDetails: order,
                            )));
                  },
                  child: smallFont(
                      text: "View Detail's >",
                      color: isDarkMode ? white : grayBlack,
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