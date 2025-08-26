import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glamora/models/cartProducts.dart';
import 'package:glamora/screens/Track%20Order/TrackOrder.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OrdersScreen extends StatelessWidget {
  Future<List<Map<String, dynamic>>> fetchTrackingStatus(
      String consignmentNo) async {
    final String clientId = '14604bad-580d-4dd1-b7ec-9917b9cb6da1';
    final String apiUrl =
        'https://api.tcscourier.com/sandbox/track/v1/shipments/detail?consignmentNo=$consignmentNo';
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
            'Connection': 'keep-alive',
          },
        ).timeout(Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['TrackDetailReply']?['Checkpoints'] != null) {
            return List<Map<String, dynamic>>.from(
                data['TrackDetailReply']['Checkpoints'])
                .map((event) {
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
    final currentUser = FirebaseAuth.instance.currentUser?.uid;

    if (currentUser == null) {
      return Scaffold(
        body: Center(child: Text('Please log in to view your orders.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('My Orders'),
        backgroundColor: Colors.purple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Orders')
            .where('uid', isEqualTo: currentUser)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No orders found.'));
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.all(16.0),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index].data() as Map<String, dynamic>;
              final orderId = order['orderId']?.toString() ?? 'N/A';
              final orderDate = order['orderDate']?.toString() ?? 'N/A';
              final orderTime = order['orderTime']?.toString() ?? 'N/A';
              final userDetails =
                  order['userDetails'] as Map<String, dynamic>? ?? {};
              final cartItems =
              List<Map<String, dynamic>>.from(order['cartItems'] ?? []);
              final trackingId =
                  order['trackingId']?.toString() ?? '7341654876';

              return Card(
                elevation: 4.0,
                margin: EdgeInsets.only(bottom: 16.0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0)),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #$orderId',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8.0),
                      Text('Placed on: $orderDate at $orderTime'),
                      SizedBox(height: 8.0),
                      Text(
                          'Name: ${userDetails['fullName']?.toString() ?? 'N/A'}'),
                      Text(
                          'Address: ${userDetails['address']?.toString() ?? 'N/A'}'),
                      Text(
                          'Phone: ${userDetails['phoneNumber']?.toString() ?? 'N/A'}'),
                      SizedBox(height: 16.0),
                      Text(
                        'Items',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      ...cartItems.map((item) {
                        final cartProduct = CartProducts.fromMap(item);
                        return ListTile(
                          leading: item['imageUrls'] != null &&
                              (item['imageUrls'] as List).isNotEmpty
                              ? Image.network(
                            item['imageUrls'][0].toString(),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.image_not_supported, size: 50),
                          )
                              : Icon(Icons.image_not_supported, size: 50),
                          title: Text(cartProduct.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Price: \$${cartProduct.price}'),
                              Text('Quantity: ${cartProduct.pieces}'),
                              Text('Size: ${cartProduct.size}'),
                              Text('Color: ${cartProduct.colorHex.toString()}'),
                            ],
                          ),
                        );
                      }).toList(),
                      SizedBox(height: 16.0),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TrackOrderScreen(trackingId: "7341654876"),
                            ),
                          );
                        },
                        child: Text('Track Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
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
    );
  }
}
