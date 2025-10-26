// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:glamora/Services/getServerKey.dart';
import 'package:http/http.dart' as http;

class SendNotificationService {
  static Future<void> sendNotificationUsingApi({
    required String? title,
    required String? body,
    required Map<String, dynamic>? data,
    required String topic,
  }) async {
    String serverKey = await GetServerKey().getServerKeyToken();

    const String url =
        "https://fcm.googleapis.com/v1/projects/glamora-c4094/messages:send";

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $serverKey',
    };

    final message = {
      "message": {
        "notification": {
          "title": title,
          "body": body,
        },
        "data": {
          "chat_id": data?['chat_id'] ?? topic,
          "sender": data?['sender'] ?? "Unknown",
          "chat_name": data?['chat_name'] ?? title ?? "Chat",
          "body": body ?? "",
        },
        "android": {
          "notification": {
            "sound": "money",
            "icon": "@drawable/ic_stat_icon",
            "channel_id": "chat_channel"
          }
        },
        "topic": topic
      }
    };

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(message),
    );

    if (response.statusCode == 200) {
      print("✅ Notification sent successfully!");
    } else {
      print("❌ Failed to send notification!");
      print("Response: ${response.body}");
    }
  }
}
