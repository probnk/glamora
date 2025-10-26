import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:audio_waveforms/audio_waveforms.dart' as aw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:glamora/Services/sendNotifcationService.dart';
import 'package:glamora/models/MessagingModel.dart';
import 'package:record/record.dart';

import '../Google Auth Services/SellerOnlineStatus.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AudioRecorder _record = AudioRecorder();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Map<String, Map<String, dynamic>> _failedUploads = {};
  final List<String> _emojis = ['👍', '❤️', '😂', '😮', '😡'];
  DatabaseReference? _messagesRef;
  bool _isLoading = true;
  bool _isFirstMessage = false;
  String? _error;
  bool _hasMessages = false;
  bool _isOnline = false;
  bool _isSellerOnline = false;
  String? _playingMessageId;
  StreamSubscription? _presenceSubscription;
  StreamSubscription? _childAddedSubscription;
  StreamSubscription? _childChangedSubscription;
  StreamSubscription? _childRemovedSubscription;
  String? _currentChatUserId;
  String _repliedTo = "";
  String _repliedMessage = "";
  String _repliedType = "";
  bool _showScrollToBottomButton = false;
  final List<String> _selectedMessageIds = [];
  bool _canEdit = false;
  String _selectedText = '';
  List<MessageModel> _messages = [];

  List<MessageModel> get messages => _messages;
  bool get isSellerOnline => _isSellerOnline;
  String get repliedTo => _repliedTo;
  String get repliedMessage => _repliedMessage;
  String get repliedType => _repliedType;
  DatabaseReference? get messagesRef => _messagesRef;
  bool get showScrollToBottomButton => _showScrollToBottomButton;
  bool get isLoading => _isLoading;
  bool get isFirstMessage => _isFirstMessage;
  String? get error => _error;
  bool get hasMessages => _hasMessages;
  bool get isOnline => _isOnline;
  List<String> get emojis => _emojis;
  List<String> get selectedMessageIds => _selectedMessageIds;
  bool get isSelectionMode => _selectedMessageIds.isNotEmpty;
  bool get canEdit => _canEdit;
  String get selectedText => _selectedText;

  @override
  void dispose() {
    _presenceSubscription?.cancel();
    _childAddedSubscription?.cancel();
    _childChangedSubscription?.cancel();
    _childRemovedSubscription?.cancel();
    _updateUserStatus(false);
    _record.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> initializeChat({
    String name = "Unknown",
    String email = "Anonymouse",
    String photoUrl = 'https://www.w3schools.com/w3images/avatar2.png',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _error = 'User not logged in. Please sign in to continue.';
        _isLoading = false;
        notifyListeners();
        return;
      }
      _setupPresenceTracking();
      final connectivityResult = await Connectivity().checkConnectivity();
      _isOnline = connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.wifi);
      notifyListeners();
      final chatId = user.uid;
      _currentChatUserId = user.uid;
      String chatDbUrl = 'chats/$chatId/messages';
      if (_isOnline) {
        final chatDoc = await _firestore.collection('chats').doc(chatId).get();
        if (!chatDoc.exists) {
          _isFirstMessage = true;
          await _firestore.collection('chats').doc(chatId).set({
            'uid': user.uid,
            'name': user.displayName ?? name,
            'email': user.email ?? email,
            'photoUrl': user.photoURL ?? photoUrl,
            'chatDbUrl': chatDbUrl,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await _updateUserStatus(true);
        _messagesRef = _rtdb.child(chatDbUrl);
        final event = await _messagesRef!.once();
        final data = event.snapshot.value as Map?;
        _hasMessages = data != null && data.isNotEmpty;
        _messages.clear();
        if (_hasMessages) {
          for (var entry in data!.entries) {
            final map = Map<String, dynamic>.from(entry.value as Map);
            if (!map['isSender'] && map['status'] != 'seen') {
              await _messagesRef!.child(entry.key as String).update({'status': 'seen'});
            }
            _messages.add(MessageModel.fromMap(map, id: entry.key));
          }
          _messages.sort((a, b) => DateTime.parse(a.time).compareTo(DateTime.parse(b.time)));
        }
        await syncPendingMessages();
      }
      if (!_isOnline || _error != null) {
        _messagesRef = _rtdb.child(chatDbUrl);
        _hasMessages = _messages.isNotEmpty;
      }
      _childAddedSubscription = _messagesRef!.onChildAdded.listen((event) async {
        final map = Map<String, dynamic>.from(event.snapshot.value as Map);
        final msg = MessageModel.fromMap(map, id: event.snapshot.key);
        if (!msg.isSender && msg.status != 'seen') {
          await _messagesRef!.child(event.snapshot.key!).update({'status': 'seen'});
        }
        await insertMessage(msg);
      });
      _childChangedSubscription = _messagesRef!.onChildChanged.listen((event) async {
        final map = Map<String, dynamic>.from(event.snapshot.value as Map);
        final msg = MessageModel.fromMap(map, id: event.snapshot.key);
        if (!msg.isSender && msg.status != 'seen') {
          await _messagesRef!.child(event.snapshot.key!).update({'status': 'seen'});
        }
        await insertMessage(msg);
      });
      _childRemovedSubscription = _messagesRef!.onChildRemoved.listen((event) async {
        final id = event.snapshot.key;
        if (id != null) {
          await deleteMessage(id);
          _selectedMessageIds.remove(id);
          await _updateCanEdit();
          notifyListeners();
        }
      });
      _listenSellerStatus();
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
        _isOnline = result.contains(ConnectivityResult.mobile) || result.contains(ConnectivityResult.wifi);
        if (_isOnline && _error != null) {
          _error = null;
          initializeChat();
        }
        if (_isOnline) {
          _retryFailedMessages();
          syncPendingMessages();
        }
        notifyListeners();
      });
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Initialization failed: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<MessageModel>> getMessages() async => _messages;

  Future<List<MessageModel>> getPendingMessages() async =>
      _messages.where((msg) => msg.status == 'pending' || msg.status == 'failed').toList();

  Future<void> insertMessage(MessageModel msg) async {
    int index = _messages.indexWhere((m) => m.id == msg.id);
    if (index != -1) {
      _messages[index] = msg;
    } else {
      _messages.add(msg);
    }
    _messages.sort((a, b) => DateTime.parse(a.time).compareTo(DateTime.parse(b.time)));
    _hasMessages = _messages.isNotEmpty;
    notifyListeners();
  }

  Future<void> updateMessageStatus(String id, String status) async {
    int index = _messages.indexWhere((m) => m.id == id);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(status: status);
      notifyListeners();
    }
  }

  Future<void> updateMessageUrl(String id, String url) async {
    int index = _messages.indexWhere((m) => m.id == id);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(message: url);
      notifyListeners();
    }
  }

  Future<void> deleteMessage(String id) async {
    _messages.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  Future<MessageModel?> getMessageById(String id) async {
    try {
      return _messages.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> syncPendingMessages() async {
    final pendingMessages = await getPendingMessages();
    for (var msg in pendingMessages) await sendMessageFromLocal(msg);
  }

  Future<void> sendMessageFromLocal(MessageModel msg) async {
    if (_messagesRef == null || msg.id == null) return;
    try {
      await updateMessageStatus(msg.id!, 'sending');
      await _messagesRef!.child(msg.id!).set(msg.toMap());
      if (msg.messageType == 'image' || msg.messageType == 'voice') {
        File mediaFile = File(msg.message);
        File uploadFile = mediaFile;
        String extension = msg.messageType == 'image' ? '.jpg' : '.m4a';
        String storageFolder = msg.messageType == 'image' ? 'chat_images' : 'chat_voices';
        String? compressedPath;
        if (msg.messageType == 'image') {
          compressedPath = mediaFile.path.replaceAll(RegExp(r'\.[^.]+$'), '_compressed.jpg');
          final compressedBytes = await FlutterImageCompress.compressWithFile(
            mediaFile.path,
            minWidth: 800,
            minHeight: 800,
            quality: 70,
            format: CompressFormat.jpeg,
          );
          if (compressedBytes == null) throw Exception('Compression failed');
          uploadFile = await File(compressedPath).writeAsBytes(compressedBytes);
        }
        final now = DateTime.now();
        final fileName = '${now.millisecondsSinceEpoch}$extension';
        final storageRef = _storage.ref('$storageFolder/${_auth.currentUser!.uid}/$fileName');
        final metadata = SettableMetadata(contentType: msg.messageType == 'image' ? 'image/jpeg' : 'audio/m4a');
        final uploadTask = storageRef.putFile(uploadFile, metadata);
        final taskSnapshot = await uploadTask;
        final url = await taskSnapshot.ref.getDownloadURL();
        await _messagesRef!.child(msg.id!).update({'message': url, 'status': _isSellerOnline ? 'delivered' : 'sent'});
        await updateMessageUrl(msg.id!, url);
        if (msg.messageType == 'voice') {
          final bytes = await mediaFile.readAsBytes();
          final cacheManager = DefaultCacheManager();
          await cacheManager.putFile(url, bytes, fileExtension: 'm4a');
        }
        if (msg.messageType == 'voice' && mediaFile.existsSync()) await mediaFile.delete();
        if (msg.messageType == 'image' && compressedPath != null && File(compressedPath).existsSync()) {
          await File(compressedPath).delete();
        }
      } else {
        await _messagesRef!.child(msg.id!).update({'status': _isSellerOnline ? 'delivered' : 'sent'});
        await updateMessageStatus(msg.id!, _isSellerOnline ? 'delivered' : 'sent');
      }
      String notifBody = msg.messageType == 'text'
          ? msg.message
          : (msg.messageType == 'image' ? 'Sent an image' : 'Sent a voice message');
      await SendNotificationService.sendNotificationUsingApi(
        title: _auth.currentUser!.displayName ?? '',
        body: notifBody,
        topic: 'seller_messages',
        data: {'screen': 'messaging_screen'},
      );
    } catch (e) {
      await _messagesRef!.child(msg.id!).update({'status': 'failed'});
      await updateMessageStatus(msg.id!, 'failed');
      _failedUploads[msg.id!] = {
        'file': msg.message,
        'type': msg.messageType,
        'repliedTo': msg.repliedTo,
        'repliedMessage': msg.repliedMessage,
        'repliedType': msg.repliedType,
      };
    }
  }

  Future<void> sendMessage({
    String? text,
    File? mediaFile,
    String? mediaType,
    String repliedTo = '',
    String repliedMessage = '',
    String repliedType = '',
  }) async {
    if (_messagesRef == null) return;

    final now = DateTime.now();
    final messageKey = _messagesRef!.push().key;
    if (messageKey == null) return;

    String messageContent = '';
    String messageTypeLocal = 'text';

    if (text != null) {
      messageContent = text.trim();
      if (messageContent.isEmpty) return;
    } else if (mediaFile != null && mediaType != null) {
      messageTypeLocal = mediaType;
      messageContent = mediaFile.path;
    } else {
      return;
    }

    String initialStatus = _isOnline && _isSellerOnline ? 'delivered' : 'sent';
    if (mediaFile != null && mediaType != null) {
      initialStatus = _isOnline ? 'uploading' : 'pending';
    }

    final message = MessageModel(
      id: messageKey,
      message: messageContent,
      time: now.toIso8601String(),
      date: now.toIso8601String(),
      isSender: true,
      status: initialStatus,
      reaction: '',
      repliedTo: repliedTo,
      repliedMessage: repliedMessage,
      repliedType: repliedType,
      messageType: messageTypeLocal,
    );

    await insertMessage(message);
    notifyListeners();

    if (!_isOnline) return;

    try {
      await _messagesRef!.child(messageKey).set(message.toMap());

      if (mediaFile != null && mediaType != null) {
        File uploadFile = mediaFile;
        String extension = mediaType == 'image' ? '.jpg' : '.m4a';
        String storageFolder = mediaType == 'image' ? 'chat_images' : 'chat_voices';
        String? compressedPath;

        if (mediaType == 'image') {
          // Image compression
          compressedPath = mediaFile.path.replaceAll(RegExp(r'\.[^.]+$'), '_compressed.jpg');
          final compressedBytes = await FlutterImageCompress.compressWithFile(
            mediaFile.path,
            minWidth: 800,
            minHeight: 800,
            quality: 70,
            format: CompressFormat.jpeg,
          );
          if (compressedBytes == null) throw Exception('Compression failed');
          uploadFile = await File(compressedPath).writeAsBytes(compressedBytes);
        } else if (mediaType == 'voice') {
          // Voice compression already done during recording
          // Use the same file as it's already compressed
          uploadFile = mediaFile;
        }

        final fileName = '${now.millisecondsSinceEpoch}$extension';
        final storageRef = _storage.ref('$storageFolder/${_auth.currentUser!.uid}/$fileName');

        final metadata = SettableMetadata(
            contentType: mediaType == 'image' ? 'image/jpeg' : 'audio/m4a'
        );

        final uploadTask = storageRef.putFile(uploadFile, metadata);
        final taskSnapshot = await uploadTask;
        final url = await taskSnapshot.ref.getDownloadURL();

        // Update with actual Firebase URL
        await _messagesRef!.child(messageKey).update({
          'message': url,
          'status': _isSellerOnline ? 'delivered' : 'sent'
        });

        await updateMessageUrl(messageKey, url);

        // Cache voice messages
        if (mediaType == 'voice') {
          final bytes = await uploadFile.readAsBytes();
          final cacheManager = DefaultCacheManager();
          await cacheManager.putFile(url, bytes, fileExtension: 'm4a');
        }

        // Cleanup temporary files
        if (mediaType == 'voice' && mediaFile.existsSync()) {
          await mediaFile.delete();
        }
        if (mediaType == 'image' && compressedPath != null && File(compressedPath).existsSync()) {
          await File(compressedPath).delete();
        }
      } else {
        await updateMessageStatus(messageKey, _isSellerOnline ? 'delivered' : 'sent');
      }

      // First message handling
      if (_isFirstMessage) {
        final user = _auth.currentUser!;
        await _firestore.collection('chats').doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? 'Unknown',
          'email': user.email ?? '',
          'photoUrl': user.photoURL ?? '',
          'chatDbUrl': 'chats/${user.uid}/messages',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _isFirstMessage = false;
      }

      // Send notification
      String notifBody = text ?? (mediaType == 'image' ? 'Sent an image' : 'Sent a voice message');
      await SendNotificationService.sendNotificationUsingApi(
        title: _auth.currentUser!.displayName ?? '',
        body: notifBody,
        topic: 'seller_messages',
        data: {'screen': 'messaging_screen'},
      );

      setRepliedMessageEmpty();
      notifyListeners();
    } catch (e) {
      await _messagesRef!.child(messageKey).update({'status': 'failed'});
      await updateMessageStatus(messageKey, 'failed');

      if (mediaFile != null && mediaType != null) {
        _failedUploads[messageKey] = {
          'file': mediaFile.path,
          'type': mediaType,
          'repliedTo': repliedTo,
          'repliedMessage': repliedMessage,
          'repliedType': repliedType,
        };
      }
    }
  }

  Future<void> _retryFailedMessages() async {
    for (var entry in List.from(_failedUploads.entries)) {
      final messageKey = entry.key;
      final data = entry.value;
      final filePath = data['file'] as String;
      final mediaType = data['type'] as String;
      final repliedTo = data['repliedTo'] as String;
      final repliedMessage = data['repliedMessage'] as String;
      final repliedType = data['repliedType'] as String;
      String? compressedPath;
      try {
        await _messagesRef!.child(messageKey).update({'status': 'uploading'});
        await updateMessageStatus(messageKey, 'uploading');
        File mediaFile = File(filePath);
        File uploadFile = mediaFile;
        String extension = mediaType == 'image' ? '.jpg' : '.m4a';
        String storageFolder = mediaType == 'image' ? 'chat_images' : 'chat_voices';
        if (mediaType == 'image') {
          compressedPath = filePath.replaceAll(RegExp(r'\.[^.]+$'), '_compressed.jpg');
          final compressedBytes = await FlutterImageCompress.compressWithFile(
            filePath,
            minWidth: 800,
            minHeight: 800,
            quality: 70,
            format: CompressFormat.jpeg,
          );
          if (compressedBytes == null) throw Exception('Compression failed');
          uploadFile = await File(compressedPath).writeAsBytes(compressedBytes);
        }
        final now = DateTime.now();
        final fileName = '${now.millisecondsSinceEpoch}$extension';
        final storageRef = _storage.ref('$storageFolder/${_auth.currentUser!.uid}/$fileName');
        final metadata = SettableMetadata(contentType: mediaType == 'image' ? 'image/jpeg' : 'audio/m4a');
        final uploadTask = storageRef.putFile(uploadFile, metadata);
        final taskSnapshot = await uploadTask;
        final url = await taskSnapshot.ref.getDownloadURL();
        await _messagesRef!.child(messageKey).update({'message': url, 'status': _isSellerOnline ? 'delivered' : 'sent'});
        await updateMessageUrl(messageKey, url);
        if (mediaType == 'voice') {
          final bytes = await mediaFile.readAsBytes();
          final cacheManager = DefaultCacheManager();
          await cacheManager.putFile(url, bytes, fileExtension: 'm4a');
        }
        _failedUploads.remove(messageKey);
        if (mediaType == 'voice' && mediaFile.existsSync()) await mediaFile.delete();
        if (mediaType == 'image' && compressedPath != null && File(compressedPath).existsSync()) {
          await File(compressedPath).delete();
        }
      } catch (e) {
        await _messagesRef!.child(messageKey).update({'status': 'failed'});
        await updateMessageStatus(messageKey, 'failed');
      }
    }
  }

  void _setupPresenceTracking() {
    final user = _auth.currentUser;
    if (user == null) return;
    WidgetsBinding.instance.addObserver(LifecycleEventHandler(
      resumeCallBack: () async => await _updateUserStatus(true),
      suspendingCallBack: () async => await _updateUserStatus(false),
    ));
    _presenceSubscription = _rtdb.child('.info/connected').onValue.listen((event) async {
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
    if (!_isOnline) return;
    try {
      await FirebaseDatabase.instance.ref().child('status').child(user.uid).update({
        'isOnline': online,
        'lastSeen': ServerValue.timestamp,
      });
    } catch (e) {}
  }

  void _listenSellerStatus() {
    final sellerStatusRef = FirebaseDatabase.instance.ref('status/seller');
    sellerStatusRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        final isOnline = data['isOnline'] ?? false;
        if (isOnline && !_isSellerOnline) {
          final event = await _messagesRef!.once();
          final messagesData = event.snapshot.value as Map?;
          if (messagesData != null) {
            for (var entry in messagesData.entries) {
              final map = Map<String, dynamic>.from(entry.value as Map);
              if (map["isSender"] == true && map["status"] == "sent") {
                await _messagesRef!.child(entry.key as String).update({"status": "delivered"});
                await updateMessageStatus(entry.key as String, "delivered");
              }
            }
          }
        }
        _isSellerOnline = isOnline;
        notifyListeners();
      }
    });
  }

  Future<void> togglePlay(String id, String url) async {
    if (_playingMessageId == id) {
      _playingMessageId = null;
    } else {
      _playingMessageId = id;
    }
    notifyListeners();
  }

  bool isPlayingMessage(String? messageId) => _playingMessageId == messageId;

  Future<void> removeReaction(String messageId) async {
    if (_messagesRef == null) return;
    await _messagesRef!.child(messageId).update({'reaction': ''});
    final map = (await _messagesRef!.child(messageId).get()).value as Map<String, dynamic>?;
    if (map != null) await insertMessage(MessageModel.fromMap(map, id: messageId));
  }

  Future<void> addReaction(String messageId, String reaction) async {
    if (_messagesRef == null) return;
    await _messagesRef!.child(messageId).update({'reaction': reaction});
    final map = (await _messagesRef!.child(messageId).get()).value as Map<String, dynamic>?;
    if (map != null) await insertMessage(MessageModel.fromMap(map, id: messageId));
  }

  void setRepliedMessage(MessageModel repliedMsg, String repliedTo) {
    _repliedTo = repliedTo;
    _repliedMessage = repliedMsg.message;
    _repliedType = repliedMsg.messageType;
    notifyListeners();
  }

  void setRepliedMessageEmpty() {
    _repliedMessage = "";
    _repliedTo = "";
    _repliedType = "";
    notifyListeners();
  }

  void updateScrollButtonVisibility(double currentPosition, double maxScrollExtent) {
    _showScrollToBottomButton = currentPosition < maxScrollExtent - 50;
    notifyListeners();
  }

  Future<void> startSelectionMode(String id) async {
    if (!_selectedMessageIds.contains(id)) {
      _selectedMessageIds.add(id);
      await _updateCanEdit();
    }
    notifyListeners();
  }

  Future<void> toggleMessageSelection(String id) async {
    _selectedMessageIds.contains(id) ? _selectedMessageIds.remove(id) : _selectedMessageIds.add(id);
    await _updateCanEdit();
    notifyListeners();
  }

  void clearSelection() {
    _selectedMessageIds.clear();
    _canEdit = false;
    _selectedText = '';
    notifyListeners();
  }

  Future<void> deleteMessages(List<String> ids) async {
    if (_messagesRef == null) return;
    for (var id in ids) {
      await _messagesRef!.child(id).remove();
      await deleteMessage(id);
    }
    clearSelection();
  }

  Future<void> _updateCanEdit() async {
    if (_selectedMessageIds.length == 1) {
      final id = _selectedMessageIds.first;
      final msg = await getMessageById(id);
      _canEdit = msg != null && msg.messageType == 'text' && msg.isSender;
      _selectedText = _canEdit ? (msg?.message ?? '') : '';
    } else {
      _canEdit = false;
      _selectedText = '';
    }
  }

  Future<void> updateMessage(String id, String newText) async {
    if (_messagesRef == null) return;
    await _messagesRef!.child(id).update({'message': newText});
    final msg = await getMessageById(id);
    if (msg != null) {
      final updatedMsg = msg.copyWith(message: newText);
      await insertMessage(updatedMsg);
    }
    clearSelection();
  }
}

class InputProvider with ChangeNotifier {
  final TextEditingController controller = TextEditingController();
  File? _pendingImage;
  String? _pendingVoicePath;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  String? _recordingPath;
  final aw.RecorderController recorderController = aw.RecorderController();

  File? get pendingImage => _pendingImage;
  String? get pendingVoicePath => _pendingVoicePath;
  bool get isRecording => _isRecording;
  Duration get recordingDuration => _recordingDuration;

  @override
  void dispose() {
    controller.dispose();
    _recordingTimer?.cancel();
    recorderController.dispose();
    _recordingPath = null;
    _pendingVoicePath = null;
    super.dispose();
  }

  Future<void> pickImage(BuildContext context) async {
    final bottomSheet = showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: () {
              Navigator.pop(ctx);
              _pickFromSource(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: () {
              Navigator.pop(ctx);
              _pickFromSource(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
    await bottomSheet;
  }

  Future<void> _pickFromSource(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      _pendingImage = File(picked.path);
      notifyListeners();
    }
  }

  void cancelPendingImage() {
    _pendingImage = null;
    notifyListeners();
  }

  Future<void> startRecording() async {
    if (await Permission.microphone.request().isGranted) {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(contentType: AndroidAudioContentType.speech, usage: AndroidAudioUsage.voiceCommunication),
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
      ));
      final dir = await getTemporaryDirectory();
      _recordingPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await recorderController.record(path: _recordingPath);
      _isRecording = true;
      _recordingDuration = Duration.zero;
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) => {_recordingDuration += const Duration(seconds: 1), notifyListeners()});
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    await recorderController.stop();
    _recordingTimer?.cancel();
    _isRecording = false;
    _pendingVoicePath = _recordingPath;
    _recordingPath = null;
    notifyListeners();
  }

  Future<void> cancelRecording() async {
    await recorderController.stop();
    _recordingTimer?.cancel();
    _isRecording = false;
    if (_recordingPath != null) await File(_recordingPath!).delete();
    _recordingPath = null;
    notifyListeners();
  }

  Future<void> cancelPendingVoice() async {
    if (_pendingVoicePath != null) {
      await File(_pendingVoicePath!).delete();
      _pendingVoicePath = null;
      notifyListeners();
    }
  }
}