import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart' as aw;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/loadingShimmer.dart';
import 'package:glamora/Reuse%20Widgets/userDetailsTexfield.dart';
import 'package:glamora/constants/app_theme.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/MessagingModel.dart';
import 'package:glamora/providers/ChatProvider.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/UserProvider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../Services/notificationService.dart';
import 'VoiceBubble.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  var currentUser;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        Provider.of<ChatProvider>(context, listen: false).updateScrollButtonVisibility(
            _scrollController.position.pixels, _scrollController.position.maxScrollExtent);
      }
    });
    currentUser = FirebaseAuth.instance.currentUser!.uid;
    NotificationService.onChatOpened(currentUser);

    Connectivity().checkConnectivity().then((result) {
      if (mounted) setState(() => _isConnected = result.contains(ConnectivityResult.mobile) || result.contains(ConnectivityResult.wifi));
    });
    Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) setState(() => _isConnected = result.contains(ConnectivityResult.mobile) || result.contains(ConnectivityResult.wifi));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    NotificationService.onChatClosed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<DarkModeProvider>(context).isDarkMode;
    final userProvider = Provider.of<UserProvider>(context);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider()
            ..initializeChat(
                name: userProvider.name, email: userProvider.email, photoUrl: userProvider.pictureUrl),
        ),
        ChangeNotifierProvider<InputProvider>(create: (_) => InputProvider()),
      ],
      child: Scaffold(
        backgroundColor: isDarkMode ? grayBlack : white,
        body: Stack(
          children: [
            Consumer<ChatProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return ListView.builder(
                      itemCount: 14,
                      itemBuilder: (context, index) => Padding(
                          padding: EdgeInsets.all(8),
                          child: reusableShimmerContainer(context: context, isDarkMode: isDarkMode, height: 50)));
                }
                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(provider.error!,
                            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.initializeChat(
                              name: userProvider.name, email: userProvider.email, photoUrl: userProvider.pictureUrl),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                if (!_isConnected && !provider.hasMessages) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('No internet connection. Please connect to view messages.',
                            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.initializeChat(
                              name: userProvider.name, email: userProvider.email, photoUrl: userProvider.pictureUrl),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    provider.isSelectionMode ? _buildSelectionAppBar(provider, isDarkMode) : _buildAppBar(context, isDarkMode),
                    Expanded(child: _buildMessageList(provider, isDarkMode)),
                    if (provider.messagesRef != null)
                      Consumer<InputProvider>(
                        builder: (context, inputProvider, _) =>
                            _buildMessageInput(provider, inputProvider, isDarkMode),
                      ),
                    if (provider.messagesRef == null) const Center(child: Text('Failed to load messages')),
                  ],
                );
              },
            ),
            Consumer<ChatProvider>(
              builder: (context, chatProvider, _) => chatProvider.showScrollToBottomButton
                  ? Positioned(
                bottom: 80,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: isDarkMode ? lightGreen : lightPurple,
                  onPressed: _scrollToBottom,
                  child: Icon(Icons.arrow_downward, color: white),
                ),
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionAppBar(ChatProvider provider, bool isDarkMode) {
    return AppBar(
      toolbarHeight: 70,
      elevation: 0.4,
      backgroundColor: isDarkMode ? lightGrayBlack : lightPurple,
      leading: IconButton(icon: const Icon(Icons.close, color: white), onPressed: provider.clearSelection),
      title: Text('${provider.selectedMessageIds.length} Selected', style: GoogleFonts.exo2(color: white)),
      actions: [
        if (provider.canEdit)
          IconButton(icon: const Icon(Icons.edit, color: white), onPressed: () => _showEditDialog(provider, isDarkMode)),
        IconButton(icon: const Icon(Icons.delete, color: white), onPressed: () => _confirmDelete(provider, isDarkMode)),
      ],
    );
  }

  void _showEditDialog(ChatProvider provider, bool isDarkMode) {
    final controller = TextEditingController(text: provider.selectedText);
    showDialog(
      barrierColor: Colors.black26,
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? lightGrayBlack : white,
        title: productTitle(text: "Edit Message", color: isDarkMode ? white : grayBlack),
        content: UserDetailsTextField(
            label: 'Enter New Message',
            controller: controller,
            hintText: "Enter Message",
            inputType: 'text',
            onChange: (value) {},
            isDarkMode: isDarkMode),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: smallFont(text: "Cancel", color: isDarkMode ? Colors.grey.shade300 : Colors.grey),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) await provider.updateMessage(provider.selectedMessageIds.first, controller.text.trim());
              Navigator.pop(ctx);
            },
            child: productTitle(text: "Save", color: isDarkMode ? green : purple),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ChatProvider provider, bool isDarkMode) {
    showDialog(
      barrierColor: Colors.black26,
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? lightGrayBlack : white,
        title: productTitle(text: "Delete Message", color: isDarkMode ? white : grayBlack),
        content: smallFont(
            align: TextAlign.start,
            text: 'Are you sure you want to delete the selected message(s)?',
            color: isDarkMode ? white : grayBlack),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: smallFont(text: "Cancel", color: isDarkMode ? Colors.grey.shade300 : Colors.grey),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteMessages(provider.selectedMessageIds);
              Navigator.pop(ctx);
            },
            child: smallFont(text: "Delete", color: isDarkMode ? Colors.redAccent : Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDarkMode) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref().child('status/seller').onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppBar(
            toolbarHeight: 70,
            elevation: 0.4,
            backgroundColor: isDarkMode ? lightGrayBlack : lightPurple,
            iconTheme: const IconThemeData(color: white),
            titleSpacing: 0,
            title: Row(
              children: [
                const CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.transparent,
                  backgroundImage: AssetImage("assets/icons/logo_1.png"),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    mediumFont(text: "Vision Cart", color: white),
                    reusableShimmerContainer(context: context, isDarkMode: isDarkMode, height: 15, width: 100),
                  ],
                ),
              ],
            ),
          );
        }
        String statusText = 'Offline';
        Color statusColor = Colors.grey.shade300;
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final isOnline = data['isOnline'] ?? false;
          final lastSeen = data['lastSeen'];
          if (isOnline) {
            statusText = 'Online';
            statusColor = Colors.green;
          } else {
            statusText = 'Last seen ${_formatLastSeen(lastSeen)}';
          }
        }
        return AppBar(
          toolbarHeight: 70,
          elevation: 0.4,
          backgroundColor: isDarkMode ? lightGrayBlack : lightPurple,
          iconTheme: const IconThemeData(color: white),
          titleSpacing: 0,
          title: Row(
            children: [
              const CircleAvatar(
                radius: 25,
                backgroundColor: Colors.transparent,
                backgroundImage: AssetImage("assets/icons/logo_1.png"),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                 Row(
                   children: [
                     mediumFont(text: "Vision Cart ", color: white),
                     Icon(Icons.verified,color: Colors.blue.shade600,size: 16)
                   ],
                 ),
                  smallFont(text: statusText, overflow: TextOverflow.ellipsis, color: statusColor),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatLastSeen(dynamic lastSeen) {
    if (lastSeen == null) return 'recently';
    DateTime lastSeenTime;
    try {
      lastSeenTime = DateTime.fromMillisecondsSinceEpoch(lastSeen is int ? lastSeen : int.parse(lastSeen));
    } catch (e) {
      return 'recently';
    }
    final now = DateTime.now();
    final difference = now.difference(lastSeenTime);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inDays < 1) return '${difference.inHours} hours ago';
    return '${difference.inDays} days ago';
  }

  Widget _buildMessageList(ChatProvider provider, bool isDarkMode) {
    if (provider.messagesRef == null) return const Center(child: Text('Messages not initialized'));
    if (!_isConnected || provider.error != null) {
      return FutureBuilder<List<MessageModel>>(
        future: provider.getMessages(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return reusableShimmerContainer(context: context, isDarkMode: isDarkMode, height: 50);
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final messages = snapshot.data ?? [];
          if (messages.isEmpty) return _buildEmptyMessageList(isDarkMode);
          return ListView.builder(
            key: const Key('offline_messages'),
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final isSent = message.isSender;
              final dateTime = DateTime.tryParse(message.time) ?? DateTime.now();
              final date = DateFormat('d MMMM, y').format(dateTime);
              final time = DateFormat('h:mm a').format(dateTime);
              final showDate = index == 0 ||
                  (index > 0 && DateFormat('d MMMM, y').format(DateTime.parse(messages[index - 1].time)) != date);
              return Column(
                crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (showDate)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Center(child: smallFont(text: date, color: Colors.grey.shade500)),
                    ),
                  _buildMessageItem(message, isDarkMode, provider, time, isSent),
                ],
              );
            },
          );
        },
      );
    }
    if (!provider.hasMessages) return _buildEmptyMessageList(isDarkMode);
    String? lastDate;
    return FirebaseAnimatedList(
      key: ValueKey(provider.messagesRef!.path),
      controller: _scrollController,
      query: provider.messagesRef!.orderByChild('time'),
      reverse: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      itemBuilder: (context, snapshot, animation, index) {
        if (!snapshot.exists || snapshot.value == null) return const SizedBox.shrink();
        final map = Map<String, dynamic>.from(snapshot.value as Map);
        final message = MessageModel.fromMap(map, id: snapshot.key);
        final isSent = message.isSender;
        final dateTime = DateTime.tryParse(message.time) ?? DateTime.now();
        final date = DateFormat('d MMMM, y').format(dateTime);
        final time = DateFormat('h:mm a').format(dateTime);
        final showDate = index == 0 || date != lastDate;
        lastDate = date;
        return Column(
          crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showDate)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Center(child: smallFont(text: date, color: Colors.grey.shade500)),
              ),
            _buildMessageItem(message, isDarkMode, provider, time, isSent),
          ],
        );
      },
    );
  }

  Widget _buildEmptyMessageList(bool isDarkMode) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      children: [
        Center(child: smallFont(text: DateFormat('d MMMM, y').format(DateTime.now()), color: Colors.grey.shade500)),
        IntrinsicWidth(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isDarkMode ? lightGrayBlack : Colors.grey.shade200,
              border: Border.all(color: isDarkMode ? Colors.grey : white),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                smallFont(
                  text: "👋 Welcome to Vision Cart!\nWe're excited to assist you with your fashion needs.\nFeel free to ask anything!",
                  color: isDarkMode ? white : grayBlack,
                  align: TextAlign.start,
                  weight: FontWeight.w500,
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [smallFont(text: DateFormat('h:mm a').format(DateTime.now()), color: Colors.grey.shade500)],
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageItem(MessageModel message, bool isDarkMode, ChatProvider provider, String time, bool isSent) {
    final isSelected = provider.selectedMessageIds.contains(message.id);
    return GestureDetector(
      onTap: () {
        if (provider.isSelectionMode && isSent && message.id != null) provider.toggleMessageSelection(message.id!);
      },
      onHorizontalDragEnd: (details) {
        if (!provider.isSelectionMode && details.primaryVelocity! > 0) {
          provider.setRepliedMessage(message, message.isSender ? "Customer" : "Seller");
        }
      },
      onLongPressStart: (details) {
        if (provider.isSelectionMode) return;
        if (isSent && message.id != null) {
          provider.startSelectionMode(message.id!);
          return;
        }
        final offset = details.globalPosition;
        final position = RelativeRect.fromLTRB(
          offset.dx,
          offset.dy,
          MediaQuery.of(context).size.width - offset.dx,
          MediaQuery.of(context).size.height - offset.dy,
        );
        if (!message.isSender) {
          showMenu<String>(
            context: context,
            position: position,
            items: provider.emojis
                .map((e) => PopupMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontSize: 24))))
                .toList(),
          ).then((value) {
            if (value != null && message.id != null) provider.addReaction(message.id!, value);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: smallFont(text: "You Can't react on Your Own Message")));
        }
      },
      child: IntrinsicWidth(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: EdgeInsets.only(top: 6, bottom: message.reaction.isNotEmpty ? 14 : 6),
              padding: const EdgeInsets.all(6),
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width * 0.25,
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withOpacity(0.3)
                    : (isDarkMode
                    ? (isSent ? green.withAlpha(100) : lightGrayBlack)
                    : (isSent ? lightPurple.withAlpha(80) : Colors.grey.shade200)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: isSent ? const Radius.circular(12) : const Radius.circular(0),
                  bottomRight: isSent ? const Radius.circular(0) : const Radius.circular(12),
                ),
                border: Border.all(
                  color: isDarkMode ? (isSent ? green : Colors.grey.shade500) : (isSent ? Colors.deepPurple : Colors.grey.shade500),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.repliedTo.isNotEmpty && message.repliedMessage.isNotEmpty) ...[
                    Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey.withAlpha(80) : Colors.white54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 4,
                              color: message.isSender
                                  ? (isDarkMode ? green : lightPurple)
                                  : (isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  smallFont(
                                      text: provider.repliedTo == "Customer" ? "You" : "Seller",
                                      color: isDarkMode ? white : grayBlack,
                                      weight: FontWeight.bold),
                                  _buildPreviewContent(message.repliedMessage, message.repliedType, isDarkMode),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: _buildMessageContent(message, isDarkMode, provider),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      smallFont(text: time, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500),
                      if (isSent) ...[const SizedBox(width: 5), _buildStatusIcon(message.status, isDarkMode)],
                    ],
                  )
                ],
              ),
            ),
            if (message.reaction.isNotEmpty)
              Positioned(
                bottom: -7,
                left: isSent ? null : 10,
                right: isSent ? 7 : null,
                child: InkWell(
                  onTap: () {
                    if (message.isSender) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: smallFont(text: "You can't able to remove your message Reaction")));
                    } else if (message.id != null && !message.isSender) {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: isDarkMode ? grayBlack : white,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (BuildContext context) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDarkMode ? lightGrayBlack : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(message.reaction, style: const TextStyle(fontSize: 24)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          smallFont(
                                            text: 'Reaction on:',
                                            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                            weight: FontWeight.bold,
                                          ),
                                          const SizedBox(height: 4),
                                          _buildPreviewContent(message.message, message.messageType, isDarkMode),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Divider(color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
                                ListTile(
                                  leading: Icon(Icons.delete_outline, color: isDarkMode ? Colors.redAccent : Colors.red),
                                  title: smallFont(text: 'Tap to remove reaction', color: isDarkMode ? white : grayBlack),
                                  onTap: () {
                                    provider.removeReaction(message.id!);
                                    Navigator.pop(context);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }
                  },
                  child: Card(
                    elevation: 4,
                    color: isDarkMode ? grayBlack : white,
                    child: Padding(padding: const EdgeInsets.all(3), child: Text(message.reaction, style: const TextStyle(fontSize: 14))),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewContent(String content, String type, bool isDarkMode) {
    switch (type) {
      case 'image':
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(
            content,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => smallFont(text: 'Image', color: isDarkMode ? white : grayBlack),
          ),
        );
      // case 'voice':
      //   return Row(
      //     children: [Icon(Icons.mic, size: 16, color: isDarkMode ? white : grayBlack), smallFont(text: 'Voice message', color: isDarkMode ? white : grayBlack)],
      //   );
      default:
        return smallFont(
          text: content,
          color: isDarkMode ? Colors.grey.shade300 : Colors.grey,
          align: TextAlign.start,
          maxLine: 3,
          overflow: TextOverflow.ellipsis,
        );
    }
  }

  Widget _buildMessageContent(MessageModel message, bool isDarkMode, ChatProvider provider) {
    if (message.status == 'uploading' || message.status == 'sending' || message.status == 'pending') {
      if (message.messageType == 'image') return const SizedBox(width: 200, height: 200, child: Center(child: CircularProgressIndicator()));
      if (message.messageType == 'voice') {
        return VoiceBubble(
          audioPath: message.message,
          isPlaying: provider.isPlayingMessage(message.id),
          onPlayPause: () => provider.togglePlay(message.id!, message.message),
        );
      }
    }
    switch (message.messageType) {
      case 'image':
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: message.message,
            height: 200,
            width: 200,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                Center(child: reusableShimmerContainer(context: context, isDarkMode: isDarkMode, height: 200)),
            errorWidget: (context, url, error) => Center(child: Icon(Icons.error, color: Colors.red)),
          ),
        );
      // case 'voice':
      //   return VoiceBubble(
      //     audioPath: message.message,
      //     isPlaying: provider.isPlayingMessage(message.id),
      //     onPlayPause: () => provider.togglePlay(message.id!, message.message),
      //   );
      default:
        return smallFont(
          text: message.message,
          maxLine: 20,
          color: isDarkMode ? white : grayBlack,
          align: TextAlign.start,
          weight: FontWeight.w500,
        );
    }
  }

  Widget _buildStatusIcon(String status, bool isDarkMode) {
    switch (status) {
      case 'sending':
      case 'uploading':
      case 'pending':
        return Icon(Icons.access_time, color: isDarkMode ? Colors.grey.shade300 : Colors.grey, size: 18);
      case 'sent':
        return Icon(Icons.done, color: isDarkMode ? Colors.grey.shade300 : Colors.grey, size: 18);
      case 'delivered':
        return Icon(Icons.done_all, color: isDarkMode ? Colors.grey.shade300 : Colors.grey, size: 18);
      case 'seen':
        return Icon(Icons.done_all, color: isDarkMode ? lightGreen : darkBlue, size: 18);
      default:
        return Icon(Icons.error, color: isDarkMode ? Colors.redAccent : Colors.red, size: 18);
    }
  }

  Widget _buildMessageInput(ChatProvider chatProvider, InputProvider inputProvider, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: isDarkMode ? lightGrayBlack : white,
      child: Column(
        children: [
          if (chatProvider.repliedMessage.isNotEmpty && chatProvider.repliedTo.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(color: isDarkMode ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.hardEdge,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      color: chatProvider.repliedTo == "Customer"
                          ? (isDarkMode ? green : purple)
                          : (isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            smallFont(
                              text: chatProvider.repliedTo == "Customer" ? "Replying Yourself" : "Replying Seller",
                              color: isDarkMode ? Colors.greenAccent : Colors.green,
                              weight: FontWeight.bold,
                            ),
                            _buildPreviewContent(chatProvider.repliedMessage, chatProvider.repliedType, isDarkMode),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: chatProvider.setRepliedMessageEmpty,
                      child: const Padding(padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.close, size: 18, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            ),
          Row(children: _buildInputRow(chatProvider, inputProvider, isDarkMode)),
        ],
      ),
    );
  }

  List<Widget> _buildInputRow(ChatProvider chatProvider, InputProvider inputProvider, bool isDarkMode) {
    List<Widget> children = [
      if (inputProvider.controller.text.isEmpty)
        IconButton(
          icon: Icon(Icons.attach_file, color: isDarkMode ? white : grayBlack),
          onPressed: inputProvider.isRecording || inputProvider.pendingImage != null || inputProvider.pendingVoicePath != null
              ? null
              : () => inputProvider.pickImage(context),
        ),
      // if (inputProvider.controller.text.isEmpty)
      //   IconButton(
      //     icon: Icon(inputProvider.isRecording ? Icons.stop : Icons.mic, color: isDarkMode ? white : grayBlack),
      //     onPressed: inputProvider.pendingImage != null || inputProvider.pendingVoicePath != null
      //         ? null
      //         : (inputProvider.isRecording ? inputProvider.stopRecording : inputProvider.startRecording),
      //   ),
    ];
    Widget inputWidget;
    if (inputProvider.isRecording) {
      inputWidget = Row(
        children: [
          IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: inputProvider.cancelRecording),
          Expanded(
            child: aw.AudioWaveforms(
              size: Size(MediaQuery.of(context).size.width * 0.6, 50),
              recorderController: inputProvider.recorderController,
              waveStyle: const aw.WaveStyle(waveColor: Colors.blue, extendWaveform: true, showMiddleLine: false),
            ),
          ),
          smallFont(text: '${inputProvider.recordingDuration.inSeconds}s', color: isDarkMode ? white : grayBlack),
        ],
      );
    } else if (inputProvider.pendingImage != null) {
      inputWidget = Row(
        children: [
          Image.file(inputProvider.pendingImage!, width: 60, height: 60, fit: BoxFit.cover),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: inputProvider.cancelPendingImage),
        ],
      );
    } else if (inputProvider.pendingVoicePath != null) {
      inputWidget = Row(
        children: [
          smallFont(text: 'Voice message', color: isDarkMode ? white : grayBlack),
          const Spacer(),
          IconButton(icon: const Icon(Icons.delete), onPressed: inputProvider.cancelPendingVoice),
        ],
      );
    } else {
      inputWidget = TextField(
        maxLines: 4,
        minLines: 1,
        controller: inputProvider.controller,
        style: GoogleFonts.exo2(fontSize: 14, color: isDarkMode ? white : grayBlack),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          hintText: 'Type a message',
          hintStyle: GoogleFonts.exo2(color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
          filled: true,
          fillColor: isDarkMode ? grayBlack : const Color(0xFFF0F0F0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
        onSubmitted: (text) {
          if (text.trim().isNotEmpty) {
            chatProvider.sendMessage(
              text: inputProvider.controller.text.trim(),
              repliedTo: chatProvider.repliedTo,
              repliedMessage: chatProvider.repliedMessage,
              repliedType: chatProvider.repliedType,
            );
            inputProvider.controller.clear();
          }
        },
      );
    }
    children.add(Expanded(child: inputWidget));
    children.add(const SizedBox(width: 10));
    children.add(
      InkWell(
        onTap: () {
          if (inputProvider.pendingImage != null) {
            chatProvider.sendMessage(
              mediaFile: inputProvider.pendingImage,
              mediaType: 'image',
              repliedTo: chatProvider.repliedTo,
              repliedMessage: chatProvider.repliedMessage,
              repliedType: chatProvider.repliedType,
            );
            inputProvider.cancelPendingImage();
          } else if (inputProvider.pendingVoicePath != null) {
            chatProvider.sendMessage(
              mediaFile: File(inputProvider.pendingVoicePath!),
              mediaType: 'voice',
              repliedTo: chatProvider.repliedTo,
              repliedMessage: chatProvider.repliedMessage,
              repliedType: chatProvider.repliedType,
            );
            inputProvider.cancelPendingVoice();
          } else if (inputProvider.controller.text.trim().isNotEmpty) {
            chatProvider.sendMessage(
              text: inputProvider.controller.text.trim(),
              repliedTo: chatProvider.repliedTo,
              repliedMessage: chatProvider.repliedMessage,
              repliedType: chatProvider.repliedType,
            );
            inputProvider.controller.clear();
          }
        },
        child: CircleAvatar(radius: 25, backgroundColor: isDarkMode ? grayBlack : lightPurple, child: Icon(Icons.send, color: white)),
      ),
    );
    return children;
  }
}