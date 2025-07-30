import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glamora/providers/ChatProvider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _sellerId = "4d32xXkG9qgOGi7PW9i4NFjOrgA3";

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider()..initializeChat(),
      child: Scaffold(
        backgroundColor: white,
        body: Consumer<ChatProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.error != null) {
              return Center(child: Text('Error: ${provider.error}'));
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(
                  _scrollController.position.maxScrollExtent,
                );
              }
            });

            return Column(
              children: [
                _buildAppBar(context),
                Expanded(child: _buildMessageList(provider)),
                if (provider.messagesRef != null) _buildMessageInput(provider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('seller_status').doc(_sellerId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildDefaultAppBar("Error loading status");
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildDefaultAppBar("Offline");
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final isOnline = data?['isOnline'] ?? false;
        final lastSeen = data?['lastSeen'];

        return AppBar(
          elevation: 0.4,
          backgroundColor: darkPurple.withAlpha(200),
          iconTheme: const IconThemeData(color: white),
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: lightGrayBlack,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: mediumFont(text: "VCS"),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  mediumFont(text: "Vision Cart"),
                  smallFont(
                    text: isOnline ? "Online" : "Last seen ${_formatLastSeen(lastSeen)}",
                    overflow: TextOverflow.ellipsis,
                    color: isOnline ? Colors.green : Colors.grey,
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildDefaultAppBar(String statusText) {
    return AppBar(
      elevation: 0.4,
      backgroundColor: darkPurple.withAlpha(200),
      iconTheme: const IconThemeData(color: white),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: lightGrayBlack,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: mediumFont(text: "VCS"),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              mediumFont(text: "Vision Cart"),
              smallFont(
                text: statusText,
                overflow: TextOverflow.ellipsis,
                color: Colors.grey,
              ),
            ],
          )
        ],
      ),
    );
  }

  String _formatLastSeen(dynamic lastSeen) {
    if (lastSeen == null) return 'recently';

    DateTime lastSeenTime;
    if (lastSeen is Timestamp) {
      lastSeenTime = lastSeen.toDate();
    } else if (lastSeen is String) {
      lastSeenTime = DateTime.parse(lastSeen);
    } else {
      return 'recently';
    }

    final now = DateTime.now();
    final difference = now.difference(lastSeenTime);

    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inDays < 1) return '${difference.inHours} hours ago';
    return '${difference.inDays} days ago';
  }

  Widget _buildMessageList(ChatProvider provider) {
    if (provider.messages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        children: [
          Center(
            child: smallFont(
              text: DateFormat('d MMMM, y').format(DateTime.now()),
              color: Colors.grey.shade500,
            ),
          ),
          IntrinsicWidth(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
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
                    color: grayBlack,
                    align: TextAlign.start,
                    weight: FontWeight.w500,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      smallFont(
                        text: DateFormat('h:mm a').format(DateTime.now()),
                        color: Colors.grey.shade500,
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      itemCount: provider.messages.length,
      itemBuilder: (context, index) {
        final message = provider.messages[index];
        final isSent = message.isSender;

        DateTime dateTime;
        try {
          dateTime = DateTime.parse(message.time);
        } catch (_) {
          dateTime = DateTime.now();
        }

        final date = DateFormat('d MMMM, y').format(dateTime);
        final time = DateFormat('h:mm a').format(dateTime);

        final showDate = index == 0 ||
            DateFormat('d MMMM, y').format(
                DateTime.parse(provider.messages[index - 1].time)) !=
                date;

        return Column(
          crossAxisAlignment:
          isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showDate)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Center(
                  child: smallFont(text: date, color: Colors.grey.shade500),
                ),
              ),
            IntrinsicWidth(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: isSent ? lightPurple.withAlpha(100) : Colors.grey.shade200,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: isSent
                        ? const Radius.circular(12)
                        : const Radius.circular(0),
                    bottomRight: isSent
                        ? const Radius.circular(0)
                        : const Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    smallFont(
                      text: message.message,
                      color: grayBlack,
                      align: TextAlign.start,
                      weight: FontWeight.w500,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        smallFont(text: time, color: Colors.grey.shade500),
                        if (isSent) ...[
                          const SizedBox(width: 5),
                          _buildStatusIcon(message.status),
                        ],
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'sending':
        return const Icon(
          Icons.access_time,
          color: Colors.grey,
          size: 18,
        );
      case 'sent':
        return const Icon(
          Icons.done,
          color: Colors.grey,
          size: 18,
        );
      case 'delivered':
        return const Icon(
          Icons.done_all,
          color: Colors.grey,
          size: 18,
        );
      case 'seen':
        return const Icon(
          Icons.done_all,
          color: darkBlue,
          size: 18,
        );
      default:
        return const Icon(
          Icons.done,
          color: Colors.grey,
          size: 18,
        );
    }
  }

  Widget _buildMessageInput(ChatProvider provider) {
    final currentUser = FirebaseAuth.instance.currentUser!.displayName.toString();
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                hintText: 'Type a message',
                filled: true,
                fillColor: const Color(0xFFF0F0F0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  provider.sendMessage(text,currentUser);
                  _controller.clear();
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: () {
              if (_controller.text.trim().isNotEmpty) {
                provider.sendMessage(_controller.text,currentUser);
                _controller.clear();
              }
            },
            child: const CircleAvatar(
              radius: 25,
              backgroundColor: darkPurple2,
              child: Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}