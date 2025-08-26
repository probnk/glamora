// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:glamora/Services/getServerKey.dart';
import 'package:http/http.dart' as http;

class SendNotificationService {
  static Future<void> sendNotificationUsingApi(
      {required String? title,
      required String? body,
      required Map<String, dynamic>? data,
      required String topic}) async {
    String serverKey = await GetServerKey().getServerKeyToken();
    String url =
        "https://fcm.googleapis.com/v1/projects/glamora-c4094/messages:send";

    var headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $serverKey',
    };

    //mesaage
    Map<String, dynamic> message = {
      "message": {
        "notification": {
          "body": body,
          "title": title,
        },
        "android": {
          "notification": {
            "sound": "money",
            "icon": "@drawable/ic_stat_icon",
            "channel_id": "high_importance_channel"
          }
        },
        "topic": topic
      }
    };

    //hit api
    final http.Response response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(message),
    );

    if (response.statusCode == 200) {
      print("Notification Send Successfully!");
    } else {
      print("Notification not send!");
    }
  }
}
