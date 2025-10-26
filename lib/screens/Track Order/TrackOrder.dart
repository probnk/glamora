import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glamora/Reuse%20Widgets/imagesFunctionCall.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/colors.dart';
import '../../models/OrderList.dart';
import '../../models/TackingStatusModel.dart';
import '../../providers/TrackingProvider.dart';
import '../../providers/OrdersProvider.dart';

class OrderTrackingScreen extends StatefulWidget {
  final OrderList order;

  const OrderTrackingScreen({Key? key, required this.order}) : super(key: key);

  @override
  _OrderTrackingScreenState createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late List<TrackingStatusModel> _trackingStatus = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTracking();
  }

  Future<void> _loadTracking() async {
    setState(() => _isLoading = true);
    List<TrackingStatusModel> statuses = [];
    final trackingProvider = context.read<TrackingProvider>();

    if (widget.order.trackingStatus?.isNotEmpty ?? false) {
      statuses = widget.order.trackingStatus!;
    } else {
      final newStatuses =
          await trackingProvider.getTrackingStatusForOrder(widget.order);
      if (newStatuses.isNotEmpty) {
        context
            .read<OrdersProvider>()
            .updateOrderTrackingStatus(widget.order.docId, newStatuses);
        statuses = newStatuses;
      }
    }

    if (mounted)
      setState(() {
        _trackingStatus = statuses;
        _isLoading = false;
      });
  }

  String _getDeliveryStatus() {
    if (_trackingStatus.isEmpty) return 'Unknown';
    final s = _trackingStatus[_trackingStatus.length - 1]
        .trackingStatus
        .toLowerCase();
    if (s.contains('delivered')) return 'Delivered';
    if (s.contains('out for delivery') || s.contains('assigned'))
      return 'Out For Delivery';
    if (s.contains('transit') ||
        s.contains('dispatched') ||
        s.contains('picked')) return 'In Transit';
    if (s.contains('return')) return 'Ready To Returned';
    return 'Processing';
  }

  String _getDeliveryDate() {
    if (_trackingStatus.isEmpty) return '';
    try {
      final dt =
          DateFormat('yyyy-MM-dd HH:mm').parse(_trackingStatus[0].timeStamp);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (e) {
      return _trackingStatus[0].timeStamp;
    }
  }

  String _getGroupKey(String status) {
    final s = status.toLowerCase();
    if (s.contains('delivered')) return 'Delivered';
    if (s.contains('out for delivery') || s.contains('assigned'))
      return 'Out For Delivery';
    if (s.contains('transit') || s.contains('dispatched')) return 'In Transit';
    if (s.contains('picked')) return 'Picked Up';
    if (s.contains('ready') || s.contains('pack')) return 'Ready To Ship';
    if (s.contains('return')) return 'Ready To Return';
    return 'Processing';
  }

  IconData _getGroupIcon(String title) =>
      {
        'delivered': Icons.check_circle,
        'out for delivery': Icons.local_shipping,
        'in transit': Icons.drive_eta,
        'picked up': Icons.local_shipping,
        'ready to ship': Icons.inventory_2,
        'ready to return': Icons.local_shipping_rounded,
      }[title.toLowerCase()] ??
      Icons.info;

  TextStyle _textStyle(double sz, int w, Color c) => GoogleFonts.exo2(
      fontSize: sz, fontWeight: FontWeight.values[w], color: c);

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF22C55E),
        blue = Color(0xFFE8F7FF),
        dark = Color(0xFF1F2937),
        gray = Color(0xFF666666),
        light = Color(0xFFE5E7EB),
        lightGray = Color(0xFFD1D5DB),
        deepPurple = Color(0xffE2EAFE);

    if (_isLoading)
      return Scaffold(
          body: const Center(
              child: CircularProgressIndicator(color: Color(0xFF22C55E))));

    if (_trackingStatus.isEmpty)
      return Scaffold(
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.info_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No Tracking Info Available',
                style: _textStyle(16, 4, Colors.grey[600]!)),
            const SizedBox(height: 8),
            Text('Tracking: ${widget.order.trackingId ?? 'N/A'}',
                style: _textStyle(14, 2, Colors.grey[500]!)),
          ]),
        ),
      );

    final status = _getDeliveryStatus();
    final date = _getDeliveryDate();
    final isDarkMode = Provider.of<DarkModeProvider>(context).isDarkMode;
    return Scaffold(
      backgroundColor: isDarkMode ? grayBlack : white,
      appBar: AppBar(
        iconTheme: IconThemeData(color: isDarkMode ? white : grayBlack),
        // title: Text('Delivery Detail', style: _textStyle(18, 6, dark)),
        title: productTitle(text: 'Delivery Detail',color: isDarkMode ? white : grayBlack),
        backgroundColor: isDarkMode ? lightGrayBlack : white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: 8),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration:  BoxDecoration(
                gradient: LinearGradient(
                    begin: isDarkMode ? Alignment.topLeft : Alignment.topCenter,
                    end: isDarkMode ? Alignment.bottomRight :Alignment.bottomCenter,
                    colors: isDarkMode ? [lightPurple,purple] : [blue, deepPurple]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: networkImagesCache(
                              url: widget.order.cartItems[0].photoUrl[0]
                                  .toString(),
                              width: 80,
                              height: 80,
                              isDarkMode: false)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(status,
                                  style: GoogleFonts.exo2(
                                    color: isDarkMode ? white : grayBlack,
                                    fontSize: 23,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2),
                              smallFont(
                                  align: TextAlign.start,
                                  text: date.isEmpty
                                      ? 'Tracking in progress'
                                      : 'Order is $status on $date',
                                  color: isDarkMode ? white : grayBlack),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on,
                                      color:  isDarkMode ? white :Colors.grey, size: 16),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'Delivery to ',
                                            style: _textStyle(14, 2,  isDarkMode ? white :gray),
                                          ),
                                          TextSpan(
                                            text: widget.order.userDetails
                                                    .fullName ??
                                                'Customer',
                                            style: _textStyle(
                                                14, 6,  isDarkMode ? white :Colors.black87),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ]),
                      )
                    ],
                  ),
                  smallFont(
                      text: widget.order.userDetails.address ?? '',
                      color:  isDarkMode ? white :lightGrayBlack)
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: isDarkMode ? lightGrayBlack : white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_shipping, color: isDarkMode ? Colors.blue : lightGray, size: 24),
                        const SizedBox(width: 3),
                        smallFont(
                            text: 'Leopards: Standard Delivery',
                            color: isDarkMode ? white : grayBlack,
                            weight: FontWeight.w500),
                      ],
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                      smallFont(
                          text: widget.order.trackingId ?? '',
                          color:  isDarkMode ? lightGray : Colors.grey.shade400),
                      const SizedBox(width: 2),
                      GestureDetector(
                          onTap: () {
                            if (widget.order.trackingId != null &&
                                widget.order.trackingId!.isNotEmpty) {
                              Clipboard.setData(ClipboardData(
                                  text: widget.order.trackingId!));
                            }
                          },
                          child: Icon(Icons.content_copy,
                              color: Colors.blue, size: 18)),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildTimeline(green, light, lightGray, dark, gray)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(
      Color green, Color light, Color lightGray, Color dark, Color gray) {
    Map<String, List<TrackingStatusModel>> grouped = {};
    List<String> order = [];
    final isDarkMode = Provider.of<DarkModeProvider>(context).isDarkMode;

    for (final s in _trackingStatus.reversed) {
      final key = _getGroupKey(s.trackingStatus);
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
        order.add(key);
      }
      grouped[key]!.add(s);
    }

    List<Widget> tiles = [];
    for (int gi = 0; gi < order.length; gi++) {
      final key = order[gi];
      final statuses = grouped[key]!;
      final done = key.toLowerCase() == 'delivered';
      final isLast = gi == order.length - 1;

      tiles.add(_timelineItem(true, gi == 0, false, done ? green : isDarkMode ? gray : lightGray,
          _getGroupIcon(key), key, null, green, light, lightGray, dark, gray));

      for (int i = 0; i < statuses.length; i++) {
        tiles.add(_timelineItem(
            false,
            false,
            isLast && i == statuses.length - 1,
            done ? green : lightGray,
            null,
            null,
            statuses[i],
            green,
            light,
            lightGray,
            dark,
            gray));
      }
    }

    return Column(children: tiles);
  }

  Widget _timelineItem(
      bool isHeader,
      bool first,
      bool last,
      Color color,
      IconData? icon,
      String? title,
      TrackingStatusModel? status,
      Color green,
      Color light,
      Color lightGray,
      Color dark,
      Color gray,
      ) {
    final isDarkMode = Provider.of<DarkModeProvider>(context).isDarkMode;

    // ✅ Detect last tracking group
    final lastGroupKey = _getGroupKey(_trackingStatus.last.trackingStatus);
    final currentGroupKey =
    isHeader ? title : _getGroupKey(status!.trackingStatus);
    final bool isLastItem = currentGroupKey == lastGroupKey;

    // ✅ Line color logic (green for last)
    final lineColor = isLastItem
        ? green
        : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300);

    return TimelineTile(
      alignment: TimelineAlign.start,
      isFirst: first,
      isLast: last,
      lineXY: 0,

      beforeLineStyle: LineStyle(color: lineColor, thickness: 2),
      afterLineStyle: LineStyle(color: lineColor, thickness: 2),

      // ✅ Circle / Indicator logic
      indicatorStyle: IndicatorStyle(
        width: 24,
        height: isHeader ? 24 : 8,
        indicator: isHeader
            ? Container(
          decoration: BoxDecoration(
            color: isLastItem ? green : (isDarkMode ? gray : lightGray),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isLastItem ? Icons.check : icon,
            color: white,
            size: 14,
          ),
        )
            : Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isLastItem ? green : (isDarkMode ? gray : lightGray),
            shape: BoxShape.circle,
          ),
        ),
      ),

      // ✅ Text styling
      endChild: Container(
        margin: EdgeInsets.only(bottom: 16, left: 16, top: isHeader ? 4 : 2),
        child: isHeader
            ? productTitle(
          text: title!,
          color: isLastItem
              ? (isDarkMode ? white : grayBlack)
              : (isDarkMode ? lightGray : Colors.grey),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            smallFont(
              text: status!.trackingStatus,
              color: isLastItem
                  ? (isDarkMode ? white : grayBlack)
                  : (isDarkMode ? lightGray : Colors.grey),
              align: TextAlign.start,
              maxWidth: MediaQuery.of(context).size.width * .5,
            ),
            smallFont(
              text: formatDate(status.timeStamp),
              color: isLastItem
                  ? (isDarkMode ? white : grayBlack)
                  : (isDarkMode ? lightGray : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String formatDate(String dateStr) {
    try {
      DateTime date = DateTime.parse(dateStr);
      return DateFormat('dd MMMM HH:mm').format(date);
    } catch (e) {
      return dateStr; // fallback if parsing fails
    }
  }
}
