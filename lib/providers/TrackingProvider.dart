import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/OrderList.dart';
import '../models/TackingStatusModel.dart';

class TrackingProvider with ChangeNotifier {
  static const String _apiKey = 'z4tfc9r4-4jg7-fmru-fjif-h2ilyzg0murq'; // Replace with actual key
  static const String _baseUrl = 'https://api.trackingmore.com/v4/trackings';

  Future<Map<String, dynamic>?> createAndGetTracking(String trackingNumber, String courierCode) async {
    try {
      // Step 1: POST to create (real-time get for new)
      final createResponse = await http.post(
        Uri.parse('$_baseUrl/create'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Tracking-Api-Key': _apiKey,
        },
        body: jsonEncode({
          'tracking_number': trackingNumber,
          'courier_code': courierCode,
        }),
      );

      debugPrint('Create response: ${createResponse.statusCode} - ${createResponse.body}');

      final createData = jsonDecode(createResponse.body);
      var trackingData = createData['data'];
      if (trackingData is List && trackingData.isNotEmpty) {
        trackingData = trackingData[0];
      }

      // If POST returns full data (has origin_info.trackinfo), use it
      if (trackingData is Map<String, dynamic> &&
          trackingData['origin_info'] != null &&
          trackingData['origin_info']['trackinfo'] != null) {
        debugPrint('Full data from POST');
        return trackingData;
      }

      // Otherwise (e.g., 4101 already exists, partial data), proceed to GET
      debugPrint('Partial data from POST, fetching via GET');

      // Step 2: GET detailed tracking info with correct endpoint
      final getResponse = await http.get(
        Uri.parse('$_baseUrl/get?tracking_numbers=$trackingNumber&courier_code=$courierCode'),
        headers: {
          'Tracking-Api-Key': _apiKey,
        },
      );

      debugPrint('Get response: ${getResponse.statusCode} - ${getResponse.body}');

      if (getResponse.statusCode == 200) {
        final getData = jsonDecode(getResponse.body);
        var trackingData = getData['data'];
        if (trackingData is List && trackingData.isNotEmpty) {
          trackingData = trackingData[0];
        }
        if (trackingData is Map<String, dynamic>) {
          return trackingData;
        }
        return null;
      } else {
        debugPrint('GET failed: ${getResponse.statusCode} - ${getResponse.body}');
        // Fallback: return partial from POST if available
        return trackingData is Map<String, dynamic> ? trackingData : null;
      }
    } catch (e) {
      debugPrint('Tracking error: $e');
      return null;
    }
  }

  List<TrackingStatusModel> mapApiToTrackingStatus(Map<String, dynamic>? trackingData) {
    if (trackingData == null || trackingData['origin_info'] == null) {
      debugPrint('No origin_info or trackingData null');
      return [];
    }

    final trackInfo = trackingData['origin_info']['trackinfo'] as List<dynamic>? ?? [];
    debugPrint('Trackinfo length: ${trackInfo.length}');
    final statuses = trackInfo.reversed.map<TrackingStatusModel>((event) {
      final dateTimeStr = event['checkpoint_date'] as String?;
      if (dateTimeStr == null) return TrackingStatusModel(trackingStatus: "", timeStamp: "");
      final dateTime = DateTime.parse(dateTimeStr);
      final formattedTime = DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
      final status = '${event['tracking_detail'] ?? ''} ${event['location'] ?? ''}'.trim();
      debugPrint('Status: $status at $formattedTime');
      return TrackingStatusModel(
        trackingStatus: status.isEmpty ? 'Unknown event' : status,
        timeStamp: formattedTime,
      );
    }).where((s) => s != null).cast<TrackingStatusModel>().toList();

    debugPrint('Mapped statuses length: ${statuses.length}');
    return statuses;
  }

  Future<List<TrackingStatusModel>> getTrackingStatusForOrder(OrderList order) async {
    if (order.trackingId == null) {
      debugPrint('No tracking ID for order');
      return [];
    }

    final trackingData = await createAndGetTracking(order.trackingId!, 'leopardscourier');
    final newStatus = mapApiToTrackingStatus(trackingData);
    notifyListeners();
    return newStatus;
  }
  // In OrdersProvider.dart (add this method)
  Future<void> updateOrderTrackingStatus(String docId, List<TrackingStatusModel> statuses) async {
    try {
      final ref = FirebaseFirestore.instance.collection('Orders').doc(docId);
      await ref.update({
        'trackingStatuses': statuses.map((s) => s.toMap()).toList(),
      });
      notifyListeners(); // Refresh orders list if needed
      debugPrint('Updated tracking statuses for $docId');
    } catch (e) {
      debugPrint('Error updating tracking statuses: $e');
    }
  }
}