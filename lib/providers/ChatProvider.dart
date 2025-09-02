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
  bool _isSellerOnline = false;

  bool get isSellerOnline => _isSellerOnline;
  StreamSubscription? _presenceSubscription;
  StreamSubscription? _messagesSubscription;
  String? _currentChatUserId;
  String _repliedTo = "";
  String _repliedMessage = "";
  String get repliedTo => _repliedMessage;
  String get repliedMessage => _repliedTo;
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
      final userDoc = await _firestore.collection('users').doc(chatId).get();

      final chatDbUrl = 'chats/$chatId/messages';
      _currentChatUserId = FirebaseAuth.instance.currentUser!.uid;

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
      }

      if (!userDoc.exists) {
        await _firestore.collection('users').doc(chatId).set({
          'uid': user.uid,
          'name': user.displayName ?? 'Unknown',
          'email': user.email ?? '',
          'photoUrl': user.photoURL ?? '',
          'chatDbUrl': chatDbUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }

      await _updateUserStatus(true);

      _messagesRef = _rtdb.child(chatDbUrl);
      _setupMessageStream();
      _listenSellerStatus();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setupMessageStream() {
    _messagesSubscription?.cancel();

    _messagesSubscription = _messagesRef?.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<Object?, Object?>.from(event.snapshot.value as Map);
        final messagesList = data.entries.map((entry) {
          final map = Map<String, dynamic>.from(entry.value as Map);
          return MessageModel.fromMap(map, id: entry.key.toString());
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

    WidgetsBinding.instance.addObserver(
      LifecycleEventHandler(
        resumeCallBack: () async => await _updateUserStatus(true),
        suspendingCallBack: () async => await _updateUserStatus(false),
      ),
    );

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

    await _firestore.collection('users').doc(user.uid).set({
      'isOnline': online,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _updateMessageStatuses() async {
    if (_messagesRef == null || _currentChatUserId == null) return;

    for (final message in _messages) {
      if (!message.isSender && message.status != 'seen' && message.id != null) {
        await _messagesRef!.child(message.id!).update({'status': 'seen'});
      }
    }
  }

  void _listenSellerStatus() {
    _firestore.collection("seller_status").snapshots().listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final isOnline = doc["isOnline"] ?? false;

        _isSellerOnline = isOnline;
        notifyListeners();

        if (isOnline && _messagesRef != null) {
          final snapshot = await _messagesRef!.once();
          if (snapshot.snapshot.value != null) {
            final data =
                Map<Object?, Object?>.from(snapshot.snapshot.value as Map);
            for (final entry in data.entries) {
              final map = Map<String, dynamic>.from(entry.value as Map);
              if (map["isSender"] == true && map["status"] == "sent") {
                await _messagesRef!.child(entry.key.toString()).update({
                  "status": "delivered",
                });
              }
            }
          }
        }
      }
    });
  }

  Future<void> sendMessage(String text, String name,
      {String repliedTo = '', String repliedMessage = ''}) async {
    if (_messagesRef == null || text.trim().isEmpty) return;

    final now = DateTime.now();
    final messageKey = _messagesRef!.push().key;
    final tempMessage = MessageModel(
        id: messageKey,
        message: text.trim(),
        time: now.toIso8601String(),
        date: now.toIso8601String(),
        isSender: true,
        status: 'sending',
        reaction: "",
        repliedTo: repliedTo,
        repliedMessage: repliedMessage);

    _messages.add(tempMessage);
    notifyListeners();

    try {
      var snapshot =
          await _firestore.collection("seller_status").limit(1).get();
      var doc = snapshot.docs.first;
      _isSellerOnline = doc["isOnline"];
      notifyListeners();

      await _messagesRef!.child(messageKey!).set(tempMessage.toMap());

      if (_isSellerOnline) {
        await _messagesRef!.child(messageKey).update({'status': 'delivered'});
      } else {
        await _messagesRef!.child(messageKey).update({'status': 'sent'});
      }

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

      _messagesRef!.child(messageKey).onValue.listen((event) {
        if (event.snapshot.value != null) {
          final updatedMessage = MessageModel.fromMap(
              Map<String, dynamic>.from(event.snapshot.value as Map),
              id: messageKey);

          final index = _messages.indexWhere(
            (m) =>
                m.message == updatedMessage.message &&
                m.time == updatedMessage.time,
          );

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
        data: {"screen": "messaging_screen"},
      );
    } catch (e) {
      _messages.removeWhere((m) => m.time == tempMessage.time);
      notifyListeners();
      rethrow;
    }
  }

// Add this method to ChatProvider class
  Future<void> removeReaction(String messageId) async {
    if (_messagesRef == null) return;

    try {
      await _messagesRef!.child(messageId).update({'reaction': ''});
    } catch (e) {
      print('Error removing reaction: $e');
    }
  }

  Future<void> addReaction(String messageId, String reaction) async {
    if (_messagesRef == null) return;

    try {
      await _messagesRef!.child(messageId).update({'reaction': reaction});
    } catch (e) {
      print('Error adding reaction: $e');
    }
  }

  void setRepliedMessage(String repliedTo, repliedMessage){
    _repliedMessage = repliedMessage;
    _repliedTo = repliedTo;
    notifyListeners();
  }

  void setRepliedMessageEmpty(){
    _repliedMessage = "";
    _repliedTo = "";
    notifyListeners();
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
