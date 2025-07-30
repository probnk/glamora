import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:glamora/models/ChatUserInfo.dart';
import 'package:glamora/models/MessagingModel.dart';

import '../Services/sendNotifcationService.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();

  DatabaseReference? _messagesRef;
  bool _isLoading = true;
  bool _isFirstMessage = false;
  String? _error;
  List<MessageModel> _messages = [];
  bool _isOnline = false;
  StreamSubscription? _presenceSubscription;
  StreamSubscription? _messagesSubscription;

  DatabaseReference? get messagesRef => _messagesRef;

  bool get isLoading => _isLoading;

  bool get isFirstMessage => _isFirstMessage;

  String? get error => _error;

  List<MessageModel> get messages => _messages;

  bool get isOnline => _isOnline;

  @override
  void dispose() {
    _presenceSubscription?.cancel();
    _messagesSubscription?.cancel();
    _updateUserStatus(false);
    super.dispose();
  }

  Future<void> initializeChat() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Initialize presence tracking
      _setupPresenceTracking();

      final chatId = user.uid;
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();

      final chatDbUrl = 'chats/$chatId/messages';

      if (!chatDoc.exists) {
        _isFirstMessage = true;
        await _firestore.collection('chats').doc(chatId).set({
          'uid': user.uid,
          'name': user.displayName ?? 'Unknown',
          'email': user.email ?? '',
          'photoUrl': user.photoURL ?? '',
          'chatDbUrl': chatDbUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } else {
        final chatData = chatDoc.data();
        if (chatData != null && chatData['chatDbUrl'] == null) {
          await _firestore.collection('chats').doc(chatId).update({
            'chatDbUrl': chatDbUrl,
          });
        }
        // Update online status when initializing
        await _updateUserStatus(true);
      }

      _messagesRef = _rtdb.child(chatDbUrl);
      _setupMessageStream();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setupMessageStream() {
    // Cancel any existing subscription
    _messagesSubscription?.cancel();

    _messagesSubscription = _messagesRef?.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<Object?, Object?>.from(event.snapshot.value as Map);
        final messagesList = data.entries.map((entry) {
          final map = Map<String, dynamic>.from(entry.value as Map);
          return MessageModel.fromMap(map);
        }).toList()
          ..sort((a, b) => a.time.compareTo(b.time));

        _messages = messagesList;
        notifyListeners();
        _updateMessageStatuses();
      } else {
        _messages = [];
        notifyListeners();
      }
    }, onError: (error) {
      _error = error.toString();
      notifyListeners();
    });
  }

  void _setupPresenceTracking() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Update status when app comes to foreground
    WidgetsBinding.instance.addObserver(
      LifecycleEventHandler(
        resumeCallBack: () async => await _updateUserStatus(true),
        suspendingCallBack: () async => await _updateUserStatus(false),
      ),
    );

    // Update status when connectivity changes
    _presenceSubscription =
        _rtdb.child('.info/connected').onValue.listen((event) async {
      if (event.snapshot.value == true) {
        await _updateUserStatus(true);
      } else {
        await _updateUserStatus(false);
      }
    });
  }

  Future<void> _updateUserStatus(bool online) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isOnline = online;
    notifyListeners();

    await _firestore.collection('chats').doc(user.uid).update({
      'isOnline': online,
      'lastSeen': FieldValue.serverTimestamp(),
    });

    // Also update in users collection if exists
    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': online,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateMessageStatuses() async {
    if (_messagesRef == null) return;

    // Update status of messages that are from seller (isSender = false)
    for (final message in _messages) {
      if (!message.isSender && message.status != 'seen') {
        final snapshot = await _messagesRef!.once();
        if (snapshot.snapshot.value != null) {
          final data =
              Map<Object?, Object?>.from(snapshot.snapshot.value as Map);
          for (final entry in data.entries) {
            final map = Map<String, dynamic>.from(entry.value as Map);
            if (map['message'] == message.message &&
                map['time'] == message.time &&
                map['isSender'] == message.isSender) {
              await _messagesRef!
                  .child(entry.key.toString())
                  .update({'status': 'seen'});
              break;
            }
          }
        }
      }
    }
  }

  Future<void> sendMessage(String text, String name) async {
    if (_messagesRef == null || text.trim().isEmpty) return;

    final now = DateTime.now();
    final messageKey = _messagesRef!.push().key;
    final tempMessage = MessageModel(
      message: text.trim(),
      time: now.toIso8601String(),
      date: now.toIso8601String(),
      isSender: true,
      // customer is sending
      status: 'sending',
    );

    // Add temporary message with 'sending' status
    _messages.add(tempMessage);
    notifyListeners();

    try {
      // Update status to 'sent' when successfully written to database
      await _messagesRef!.child(messageKey!).set(tempMessage.toMap()).then((_) {
        _messagesRef!.child(messageKey).update({'status': 'sent'});
      });

      if (_isFirstMessage) {
        final user = _auth.currentUser!;
        await _firestore.collection('users').doc(user.uid).set(
              ChatUser(
                uid: user.uid,
                name: user.displayName ?? 'Unknown',
                email: user.email ?? '',
                photoUrl: user.photoURL ?? '',
                chatDbUrl: 'chats/${user.uid}/messages',
                createdAt: now.toIso8601String(),
                isOnline: true,
                lastSeen: now.toIso8601String(),
              ).toMap(),
            );
        _isFirstMessage = false;
      }

      // Listen for status updates on this specific message
      _messagesRef!.child(messageKey).onValue.listen((event) {
        if (event.snapshot.value != null) {
          final updatedMessage = MessageModel.fromMap(
              Map<String, dynamic>.from(event.snapshot.value as Map));

          // Update the message in our local list
          final index = _messages.indexWhere((m) =>
              m.message == updatedMessage.message &&
              m.time == updatedMessage.time);

          if (index != -1) {
            _messages[index] = updatedMessage;
            notifyListeners();
          }
        }
      });
      SendNotificationService.sendNotificationUsingApi(
          title: name,
          body: text,
          topic: "seller_messages",
          data: {"screen": "messaging_screen"});
    } catch (e) {
      // Remove the temporary message if sending fails
      _messages.removeWhere((m) => m.time == tempMessage.time);
      notifyListeners();
      rethrow;
    }
  }
}

class LifecycleEventHandler extends WidgetsBindingObserver {
  final Function resumeCallBack;
  final Function suspendingCallBack;

  LifecycleEventHandler({
    required this.resumeCallBack,
    required this.suspendingCallBack,
  });

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await resumeCallBack();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        await suspendingCallBack();
        break;
    }
  }
}
