import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_waveforms/audio_waveforms.dart' as aw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:glamora/Google%20Auth%20Services/SellerOnlineStatus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart' hide AVAudioSessionCategory;
import 'package:record/record.dart';
import 'package:glamora/models/MessagingModel.dart';
import 'package:glamora/Services/sendNotifcationService.dart';
import '../Local Storage/MessagesLocalStorage.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AudioRecorder _record = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
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

  DBHelper _dbHelper = DBHelper();

  DBHelper get dbHelper => _dbHelper;

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
    _audioPlayer.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> enableFirestorePersistence() async {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      print('Firestore persistence enabled');
    } catch (e) {
      print('Error enabling Firestore persistence: $e');
    }
  }

  Future<void> initializeChat(
      {String name = "Unknown",
        String email = "Anonymouse",
        String photoUrl =
        'https://www.w3schools.com/w3images/avatar2.png'}) async {
    try {
      await enableFirestorePersistence();
      print('Firestore persistence enabled');

      final user = _auth.currentUser;
      if (user == null) {
        _error = 'User not logged in. Please sign in to continue.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _setupPresenceTracking();

      final connectivityResult = await Connectivity().checkConnectivity();
      _isOnline = connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi);

      final localMessages = await _dbHelper.getMessages();
      _hasMessages = localMessages.isNotEmpty;
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

        if (_hasMessages) {
          for (var entry in data!.entries) {
            final map = Map<String, dynamic>.from(entry.value as Map);
            if (!map['isSender'] && map['status'] != 'seen') {
              await _messagesRef!
                  .child(entry.key as String)
                  .update({'status': 'seen'});
            }
            await _dbHelper
                .insertMessage(MessageModel.fromMap(map, id: entry.key));
          }
        }
        await syncPendingMessages();
      }

      if (!_isOnline || _error != null) {
        _messagesRef = _rtdb.child(chatDbUrl);
        _hasMessages = localMessages.isNotEmpty;
      }

      _childChangedSubscription =
          _messagesRef!.onChildChanged.listen((event) async {
            try {
              final map = Map<String, dynamic>.from(event.snapshot.value as Map);
              final msg = MessageModel.fromMap(map, id: event.snapshot.key);
              if (msg.isSender && msg.status != 'seen') {
                // Add this check for realtime update
                await _messagesRef!
                    .child(event.snapshot.key!)
                    .update({'status': 'seen'});
              }
              await _dbHelper.insertMessage(msg);
              notifyListeners();
            } catch (e) {
              print('Error in child changed: $e');
            }
          });

      _childRemovedSubscription =
          _messagesRef!.onChildRemoved.listen((event) async {
            try {
              final id = event.snapshot.key;
              if (id != null) {
                await _dbHelper.deleteMessage(id);
                _selectedMessageIds.remove(id);
                await _updateCanEdit();
                notifyListeners();
              }
            } catch (e) {
              print('Error in child removed: $e');
            }
          });

      _listenSellerStatus();
      _connectivitySubscription = Connectivity()
          .onConnectivityChanged
          .listen((List<ConnectivityResult> result) {
        _isOnline = result.contains(ConnectivityResult.mobile) ||
            result.contains(ConnectivityResult.wifi);
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
      print('InitializeChat error: $e');
    }
  }

  Future<void> syncPendingMessages() async {
    final pendingMessages = await _dbHelper.getPendingMessages();
    for (var msg in pendingMessages) {
      await sendMessageFromLocal(msg);
    }
  }

  Future<void> sendMessageFromLocal(MessageModel msg) async {
    if (_messagesRef == null || msg.id == null) return;

    try {
      await _dbHelper.updateMessageStatus(msg.id!, 'sending');
      await _messagesRef!.child(msg.id!).set(msg.toMap());

      if (msg.messageType == 'image' || msg.messageType == 'voice') {
        File mediaFile = File(msg.message);
        File uploadFile = mediaFile;
        String extension = msg.messageType == 'image' ? '.jpg' : '.m4a';
        String storageFolder =
        msg.messageType == 'image' ? 'chat_images' : 'chat_voices';
        String? compressedPath;

        if (msg.messageType == 'image') {
          compressedPath =
              mediaFile.path.replaceAll(RegExp(r'\.[^.]+$'), '_compressed.jpg');
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
        final storageRef =
        _storage.ref('$storageFolder/${_auth.currentUser!.uid}/$fileName');
        final uploadTask = storageRef.putFile(uploadFile);
        final taskSnapshot = await uploadTask;
        final url = await taskSnapshot.ref.getDownloadURL();

        await _messagesRef!.child(msg.id!).update({
          'message': url,
          'status': _isSellerOnline ? 'delivered' : 'sent',
          'localPath': null,
        });
        await _dbHelper.updateMessageUrl(msg.id!, url,
            localPath: msg.localPath);

        if (msg.messageType == 'voice' && mediaFile.existsSync()) {
          await mediaFile.delete().catchError((_) {});
        }
        if (msg.messageType == 'image' &&
            compressedPath != null &&
            File(compressedPath).existsSync()) {
          await File(compressedPath).delete().catchError((_) {});
        }
      } else {
        await _messagesRef!.child(msg.id!).update({
          'status': _isSellerOnline ? 'delivered' : 'sent',
        });
        await _dbHelper.updateMessageStatus(
            msg.id!, _isSellerOnline ? 'delivered' : 'sent');
      }

      String notifBody = msg.messageType == 'text'
          ? msg.message
          : (msg.messageType == 'image'
          ? 'Sent an image'
          : 'Sent a voice message');
      await SendNotificationService.sendNotificationUsingApi(
        title: _auth.currentUser!.displayName ?? '',
        body: notifBody,
        topic: 'seller_messages',
        data: {'screen': 'messaging_screen'},
      );
    } catch (e) {
      await _messagesRef!.child(msg.id!).update({'status': 'failed'});
      await _dbHelper.updateMessageStatus(msg.id!, 'failed');
      _failedUploads[msg.id!] = {
        'file': msg.message,
        'type': msg.messageType,
        'repliedTo': msg.repliedTo,
        'repliedMessage': msg.repliedMessage,
        'repliedType': msg.repliedType,
      };
      print('Error sending pending message: $e');
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
    if (_messagesRef == null) {
      print('Error: messagesRef is null');
      return;
    }

    final now = DateTime.now();
    final messageKey = _messagesRef!.push().key;
    if (messageKey == null) {
      print('Error: Failed to generate message key');
      return;
    }

    String messageContent = '';
    String messageTypeLocal = 'text';
    String? localPath;

    if (text != null) {
      messageContent = text.trim();
      if (messageContent.isEmpty) return;
    } else if (mediaFile != null && mediaType != null) {
      messageTypeLocal = mediaType;
      messageContent = mediaFile.path;
      localPath = mediaFile.path;
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
      localPath: localPath,
    );

    await _dbHelper.insertMessage(message);

    notifyListeners();

    if (!_isOnline) {
      return;
    }

    try {
      await _messagesRef!.child(messageKey).set(message.toMap());

      if (mediaFile != null && mediaType != null) {
        File uploadFile = mediaFile;
        String extension = mediaType == 'image' ? '.jpg' : '.m4a';
        String storageFolder =
        mediaType == 'image' ? 'chat_images' : 'chat_voices';
        String? compressedPath;

        if (mediaType == 'image') {
          compressedPath =
              mediaFile.path.replaceAll(RegExp(r'\.[^.]+$'), '_compressed.jpg');
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

        final fileName = '${now.millisecondsSinceEpoch}$extension';
        final storageRef =
        _storage.ref('$storageFolder/${_auth.currentUser!.uid}/$fileName');
        final uploadTask = storageRef.putFile(uploadFile);
        final taskSnapshot = await uploadTask;
        final url = await taskSnapshot.ref.getDownloadURL();

        await _messagesRef!.child(messageKey).update({
          'message': url,
          'status': _isSellerOnline ? 'delivered' : 'sent',
          'localPath': null,
        });
        await _dbHelper.updateMessageUrl(messageKey, url, localPath: localPath);

        if (mediaType == 'voice' && mediaFile.existsSync()) {
          await mediaFile.delete().catchError((_) {});
        }
        if (mediaType == 'image' &&
            compressedPath != null &&
            File(compressedPath).existsSync()) {
          await File(compressedPath).delete().catchError((_) {});
        }
      } else {
        await _dbHelper.updateMessageStatus(
            messageKey, _isSellerOnline ? 'delivered' : 'sent');
      }

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

      String notifBody = text ??
          (mediaType == 'image' ? 'Sent an image' : 'Sent a voice message');
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
      await _dbHelper.updateMessageStatus(messageKey, 'failed');
      if (mediaFile != null && mediaType != null) {
        _failedUploads[messageKey] = {
          'file': mediaFile.path,
          'type': mediaType,
          'repliedTo': repliedTo,
          'repliedMessage': repliedMessage,
          'repliedType': repliedType,
        };
      }
      print('Error sending message: $e');
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
        await _dbHelper.updateMessageStatus(messageKey, 'uploading');

        File mediaFile = File(filePath);
        File uploadFile = mediaFile;
        String extension = mediaType == 'image' ? '.jpg' : '.m4a';
        String storageFolder =
        mediaType == 'image' ? 'chat_images' : 'chat_voices';

        if (mediaType == 'image') {
          compressedPath =
              filePath.replaceAll(RegExp(r'\.[^.]+$'), '_compressed.jpg');
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
        final storageRef =
        _storage.ref('$storageFolder/${_auth.currentUser!.uid}/$fileName');
        final uploadTask = storageRef.putFile(uploadFile);
        final taskSnapshot = await uploadTask;
        final url = await taskSnapshot.ref.getDownloadURL();

        await _messagesRef!.child(messageKey).update({
          'message': url,
          'status': _isSellerOnline ? 'delivered' : 'sent',
          'localPath': null,
        });
        await _dbHelper.updateMessageUrl(messageKey, url, localPath: filePath);

        _failedUploads.remove(messageKey);
        if (mediaType == 'voice' && mediaFile.existsSync()) {
          await mediaFile.delete().catchError((_) {});
        }
        if (mediaType == 'image' &&
            compressedPath != null &&
            File(compressedPath).existsSync()) {
          await File(compressedPath).delete().catchError((_) {});
        }
      } catch (e) {
        await _messagesRef!.child(messageKey).update({'status': 'failed'});
        await _dbHelper.updateMessageStatus(messageKey, 'failed');
        print('Retry failed: $e');
      }
    }
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

    if (!_isOnline) return;

    try {
      await FirebaseDatabase.instance
          .ref()
          .child('status')
          .child(user.uid)
          .update({
        'isOnline': online,
        'lastSeen': ServerValue.timestamp,
      });
    } catch (e) {
      print('Error updating status: $e');
    }
  }

  void _listenSellerStatus() {
    final sellerStatusRef = FirebaseDatabase.instance.ref('status/seller');

    sellerStatusRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map?;

      if (data != null) {
        final isOnline = data['isOnline'] ?? false;

        if (isOnline && !_isSellerOnline) {
          try {
            final event = await _messagesRef!.once();
            final messagesData = event.snapshot.value as Map?;
            if (messagesData != null) {
              for (var entry in messagesData.entries) {
                final map = Map<String, dynamic>.from(entry.value as Map);
                if (map["isSender"] == true && map["status"] == "sent") {
                  await _messagesRef!.child(entry.key as String).update({
                    "status": "delivered",
                  });
                  await _dbHelper.updateMessageStatus(
                      entry.key as String, "delivered");
                }
              }
            }
          } catch (e) {
            print('Error updating delivered status: $e');
          }
        }

        _isSellerOnline = isOnline;
        notifyListeners();
      }
    }, onError: (error) {
      print('Error listening to seller status: $error');
    });
  }

  Future<void> togglePlay(String id, String url) async {
    try {
      if (_playingMessageId == id) {
        await _audioPlayer.pause();
        _playingMessageId = null;
      } else {
        final source =
        File(url).existsSync() ? DeviceFileSource(url) : UrlSource(url);
        await _audioPlayer.play(source);
        _playingMessageId = id;
        _audioPlayer.onPlayerComplete.listen((_) {
          _playingMessageId = null;
          notifyListeners();
        });
      }
      notifyListeners();
    } catch (e) {
      print('Error toggling play: $e');
    }
  }

  bool isPlayingMessage(String? messageId) {
    return _playingMessageId == messageId;
  }

  Future<void> removeReaction(String messageId) async {
    if (_messagesRef == null) return;

    try {
      await _messagesRef!.child(messageId).update({'reaction': ''});
      await _dbHelper.insertMessage(
        MessageModel.fromMap(
          (await _messagesRef!.child(messageId).get()).value
          as Map<String, dynamic>,
          id: messageId,
        ),
      );
    } catch (e) {
      print('Error removing reaction: $e');
    }
  }

  Future<void> addReaction(String messageId, String reaction) async {
    if (_messagesRef == null) return;

    try {
      await _messagesRef!.child(messageId).update({'reaction': reaction});
      await _dbHelper.insertMessage(
        MessageModel.fromMap(
          (await _messagesRef!.child(messageId).get()).value
          as Map<String, dynamic>,
          id: messageId,
        ),
      );
    } catch (e) {
      print('Error adding reaction: $e');
    }
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

  void updateScrollButtonVisibility(
      double currentPosition, double maxScrollExtent) {
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
    if (_selectedMessageIds.contains(id)) {
      _selectedMessageIds.remove(id);
    } else {
      _selectedMessageIds.add(id);
    }
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
      await _dbHelper.deleteMessage(id);
    }
    clearSelection();
  }

  Future<void> _updateCanEdit() async {
    if (_selectedMessageIds.length == 1) {
      final id = _selectedMessageIds.first;
      final msg = await _dbHelper.getMessageById(id);
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
    final msg = await _dbHelper.getMessageById(id);
    if (msg != null) {
      // Create a new MessageModel with updated message content
      final updatedMsg = MessageModel.fromMap(
        {
          ...msg.toMap(),
          'message': newText,
        },
        id: id,
      );
      await _dbHelper.insertMessage(updatedMsg);
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
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        _pendingImage = File(picked.path);
        notifyListeners();
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void cancelPendingImage() {
    _pendingImage = null;
    notifyListeners();
  }

  Future<void> startRecording() async {
    try {
      if (await Permission.microphone.request().isGranted) {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration(
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
        ));

        final dir = await getTemporaryDirectory();
        _recordingPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await recorderController.record(path: _recordingPath);
        _isRecording = true;
        _recordingDuration = Duration.zero;
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _recordingDuration += const Duration(seconds: 1);
          notifyListeners();
        });
        notifyListeners();
      } else {
        print('Microphone permission denied');
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      await recorderController.stop();
      _recordingTimer?.cancel();
      _isRecording = false;
      _pendingVoicePath = _recordingPath;
      _recordingPath = null;
      notifyListeners();
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> cancelRecording() async {
    try {
      await recorderController.stop();
      _recordingTimer?.cancel();
      _isRecording = false;
      if (_recordingPath != null) {
        await File(_recordingPath!).delete();
      }
      _recordingPath = null;
      notifyListeners();
    } catch (e) {
      print('Error canceling recording: $e');
    }
  }

  Future<void> cancelPendingVoice() async {
    try {
      if (_pendingVoicePath != null) {
        await File(_pendingVoicePath!).delete();
        _pendingVoicePath = null;
        notifyListeners();
      }
    } catch (e) {
      print('Error canceling pending voice: $e');
    }
  }
}