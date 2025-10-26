// ignore_for_file: avoid_print

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../BottomNavBar/BottomNavBar.dart';

class NotificationService {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Store messages grouped by chat (for stacked notifications)
  final Map<String, List<Map<String, String>>> _chatMessages = {};

  // 🔹 1. Request Permission
  Future<void> requestNotificationPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Notification permission granted');
    } else {
      print('❌ Notification permission denied');
    }
  }

  // 🔹 2. Get FCM Token
  Future<String> getDeviceToken() async {
    String? token = await messaging.getToken();
    if (kDebugMode) print('📱 FCM Token: $token');
    return token ?? '';
  }

  // 🔹 3. Initialize Local Notifications
  Future<void> initLocalNotifications(
      BuildContext context, RemoteMessage message) async {
    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_icon');
    const iOSInit = DarwinInitializationSettings();
    final settings = InitializationSettings(android: androidInit, iOS: iOSInit);

    await _flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        handleMessage(context, message);
      },
    );

    const channel = AndroidNotificationChannel(
      'chat_channel',
      'Chat Notifications',
      description: 'Used for chat message notifications',
      importance: Importance.max,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // 🔹 4. Listen to Firebase messages (foreground)
  void firebaseInit(BuildContext context) {
    FirebaseMessaging.onMessage.listen((message) {
      if (Platform.isAndroid) {
        initLocalNotifications(context, message);
        _showChatStyleNotification(message);
      } else if (Platform.isIOS) {
        FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    });
  }

  // 🔹 5. Handle taps from background or terminated state
  Future<void> setupInteractMessage(BuildContext context) async {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      handleMessage(context, message);
    });

    RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      handleMessage(context, initialMessage);
    }
  }

  // 🔹 6. WhatsApp-style stacked notifications
  Future<void> _showChatStyleNotification(RemoteMessage message) async {
    final data = message.data;
    final chatId = data['chat_id'] ?? 'default_chat';
    final chatName = data['chat_name'] ?? 'Chat';
    final sender = data['sender'] ?? 'Someone';
    final text = message.notification?.body ?? data['body'] ?? '';

    // Store recent messages for each chat
    _chatMessages.putIfAbsent(chatId, () => []);
    _chatMessages[chatId]!.add({'sender': sender, 'text': text});

    // Keep last 5 messages
    if (_chatMessages[chatId]!.length > 5) {
      _chatMessages[chatId] =
          _chatMessages[chatId]!.sublist(_chatMessages[chatId]!.length - 5);
    }

    // Create list of Message objects
    final List<Message> messageList = _chatMessages[chatId]!
        .map((msg) => Message(
      msg['text'] ?? '',
      DateTime.now(),
      Person(name: msg['sender']),
    ))
        .toList();

    // WhatsApp-like Messaging style
    final style = MessagingStyleInformation(
      Person(name: chatName),
      conversationTitle: chatName,
      groupConversation: true,
      messages: messageList,
    );

    final androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      channelDescription: 'For chat messages',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: style,
      groupKey: 'chat_group',
      icon: '@drawable/ic_stat_icon',
    );

    const iOSDetails = DarwinNotificationDetails();
    final details =
    NotificationDetails(android: androidDetails, iOS: iOSDetails);

    final int notificationId = chatId.hashCode;

    await _flutterLocalNotificationsPlugin.show(
      notificationId,
      chatName,
      text,
      details,
    );

    // Group summary (like WhatsApp multiple chats)
    const summary = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      styleInformation: InboxStyleInformation([]),
      setAsGroupSummary: true,
      groupKey: 'chat_group',
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      'You have new messages',
      'Multiple conversations',
      NotificationDetails(android: summary),
    );
  }

  // 🔹 7. Handle Navigation on Tap
  Future<void> handleMessage(BuildContext context, RemoteMessage message) async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => BottomNavBar()),
          (route) => false,
    );
  }
}
