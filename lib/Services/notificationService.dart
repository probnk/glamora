// ignore_for_file: avoid_print

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static const _methodChannel = MethodChannel('com.example.glamora/notifications');

  // Active chat track karne ke liye — null = koi chat screen open nahi
  static String? activeChatId;
  static bool isOrderScreenOpen = false;

  // ── 1. Permission ─────────────────────────────────────────────
  Future<void> requestNotificationPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      print(settings.authorizationStatus == AuthorizationStatus.authorized
          ? '✅ Permission granted'
          : '❌ Permission denied');
    }
  }

  // ── 2. FCM Token ─────────────────────────────────────────────
  Future<String> getDeviceToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (kDebugMode) print('📱 FCM Token: $token');
    return token ?? '';
  }

  // ── 3. Init — ek baar call karo, BuildContext nahi chahiye ────
  static void init() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background se notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data);
    });
  }

  // ── 4. Terminated state tap ───────────────────────────────────
  static Future<void> setupInteractMessage(BuildContext context) async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // Thoda delay do app properly load hone ke liye
      await Future.delayed(const Duration(seconds: 1));
      _handleNotificationTap(initialMessage.data);
    }
  }

  // ── 5. Foreground Handler ─────────────────────────────────────
  static void _handleForegroundMessage(RemoteMessage message) {
    if (!Platform.isAndroid) {
      // iOS — FCM khud handle karta hai
      FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );
      return;
    }

    final data = message.data;
    final type = data['type'] ?? '';

    // ── Chat message ───────────────────────────────────────────
    if (type == 'chat' || data['chat_id'] != null) {
      final chatId = data['chat_id'] ?? '';

      // Agar same chat open hai → notification mat dikhao
      if (activeChatId == chatId) {
        print("📵 Chat screen open hai — notification skip");
        return;
      }

      _showNativeMessageNotification(
        chatId:     chatId,
        senderName: data['sender'] ?? data['chat_name'] ?? 'User',
        message:    message.notification?.body ?? data['body'] ?? '',
      );
      return;
    }

    // ── Order update ───────────────────────────────────────────
    if (type == 'order_update') {
      if (isOrderScreenOpen) {
        print("📵 Orders screen open hai — skip");
        return;
      }
      _showNativeOrderUpdateNotification(
        orderId: data['order_id'] ?? '',
        title:   message.notification?.title ?? 'Order Update',
        body:    message.notification?.body ?? '',
      );
      return;
    }
  }

  // ── 6. Native Message Notification call ───────────────────────
  static Future<void> _showNativeMessageNotification({
    required String chatId,
    required String senderName,
    required String message,
  }) async {
    try {
      await _methodChannel.invokeMethod('showMessageNotification', {
        'chatId':     chatId,
        'senderName': senderName,
        'message':    message,
      });
    } catch (e) {
      print("❌ Message notification error: $e");
    }
  }

  // ── 7. Native Order Update Notification call ──────────────────
  static Future<void> _showNativeOrderUpdateNotification({
    required String orderId,
    required String title,
    required String body,
  }) async {
    try {
      await _methodChannel.invokeMethod('showOrderUpdateNotification', {
        'orderId': orderId,
        'title':   title,
        'body':    body,
      });
    } catch (e) {
      print("❌ Order notification error: $e");
    }
  }

  // ── 8. Chat Screen khulne/bandh hone par call karo ───────────
  static Future<void> onChatOpened(String chatId) async {
    activeChatId = chatId;
    try {
      await _methodChannel.invokeMethod('cancelChatNotification', {
        'chatId': chatId,
      });
    } catch (e) {
      print("❌ Cancel notification error: $e");
    }
  }

  static void onChatClosed() {
    activeChatId = null;
  }

  // ── 9. Order screen ───────────────────────────────────────────
  static void onOrderScreenOpened() => isOrderScreenOpen = true;
  static void onOrderScreenClosed() => isOrderScreenOpen = false;

  // ── 10. Notification tap navigation ──────────────────────────
  static void _handleNotificationTap(Map<String, dynamic> data) {
    print("🔔 Notification tapped: $data");
    // TODO: apna NavigationService ya GlobalKey<NavigatorState> yahan use karo
    // e.g. navigatorKey.currentState?.pushNamed('/chat', arguments: data['chat_id']);
  }
}