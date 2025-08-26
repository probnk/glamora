import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:timeline_tile_plus/timeline_tile_plus.dart';

class TrackOrderScreen extends StatelessWidget {
  final String trackingId;
  TrackOrderScreen({required this.trackingId});

  Future<List<Map<String, dynamic>>> fetchTrackingStatus() async {
    if (trackingId.isEmpty) return [];

    final String clientId = '14604bad-580d-4dd1-b7ec-9917b9cb6da1';
    final String apiUrl =
        'https://api.tcscourier.com/sandbox/track/v1/shipments/detail?consignmentNo=1000001';

    const int maxRetries = 3;
    int retryCount = 0;
    const baseDelay = Duration(milliseconds: 1000);

    while (retryCount < maxRetries) {
      http.Client? client;
      try {
        client = http.Client();
        final response = await client.get(
          Uri.parse(apiUrl),
          headers: {
            'X-IBM-Client-Id': clientId,
            'accept': 'application/json',
          },
        ).timeout(Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['TrackDetailReply']?['Checkpoints'] != null) {
            return List<Map<String, dynamic>>.from(
                data['TrackDetailReply']['Checkpoints']).map((event) {
              String dt = event['dateTime']?.toString() ?? '';
              if (dt.isNotEmpty) {
                if (dt.length == 8) {
                  dt =
                  '${dt.substring(0, 4)}-${dt.substring(4, 6)}-${dt.substring(6, 8)}';
                } else if (dt.contains(' ')) {
                  dt = dt.replaceFirstMapped(
                      RegExp(r'(\d{4})(\d{2})(\d{2})\s(\d{2}:\d{2})'),
                          (m) => '${m[1]}-${m[2]}-${m[3]} ${m[4]}');
                }
              } else {
                dt = DateFormat('yyyy-MM-dd').format(DateTime.now());
              }
              final timestamp = DateTime.tryParse(dt)?.millisecondsSinceEpoch ??
                  DateTime.now().millisecondsSinceEpoch;

              return {
                'status': event['status']?.toString() ?? 'Unknown',
                'timestamp': timestamp,
              };
            }).toList();
          }
          return [];
        } else {
          print(
              'Failed to fetch tracking status: ${response.statusCode} - ${response.body}');
          return [];
        }
      } catch (e) {
        print('Error fetching tracking status (attempt ${retryCount + 1}): $e');
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(baseDelay * pow(2, retryCount));
        } else {
          return [];
        }
      } finally {
        client?.close();
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track Order'),
        backgroundColor: Colors.purple,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchTrackingStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final trackingStatus = snapshot.data ?? [];
          if (trackingStatus.isEmpty) {
            return Center(child: Text('No tracking information available'));
          }

          return ListView.builder(
            itemCount: trackingStatus.length,
            itemBuilder: (context, index) {
              final status = trackingStatus[index];
              final timestamp =
              DateTime.fromMillisecondsSinceEpoch(status['timestamp']);
              final formattedDate =
              DateFormat('d MMMM, yyyy').format(timestamp);
              final formattedTime = DateFormat('h:mm a').format(timestamp);

              return TimelineTile(
                alignment: TimelineAlign.manual,
                lineXY: 0.3,
                isFirst: index == 0,
                isLast: index == trackingStatus.length - 1,
                indicatorStyle: IndicatorStyle(
                  width: 20,
                  color: Colors.purple,
                  indicatorXY: 0.5,
                  iconStyle: IconStyle(
                    iconData: Icons.check_circle,
                    color: Colors.white,
                  ),
                ),
                beforeLineStyle: LineStyle(color: Colors.purple),
                afterLineStyle: LineStyle(color: Colors.purple),
                endChild: Container(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status['status'] ?? 'Unknown',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('$formattedDate at $formattedTime'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
