import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:glamora/constants/reponsivness.dart';
import 'package:glamora/providers/ChatProvider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/DarkModeProvider.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<DarkModeProvider>(context).isDarkMode;
    return ChangeNotifierProvider(
      create: (_) => ChatProvider()..initializeChat(),
      child: Scaffold(
        backgroundColor: isDarkMode ? grayBlack : white,
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
                _buildAppBar(context, isDarkMode),
                Expanded(child: _buildMessageList(provider, isDarkMode)),
                if (provider.messagesRef != null)
                  _buildMessageInput(provider, isDarkMode),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('seller_status').snapshots(),
      builder: (context, snapshot) {
        String statusText = 'Offline';
        Color statusColor = Colors.grey.shade300;

        if (snapshot.hasError) {
          statusText = 'Error loading status';
        } else if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final doc = snapshot.data!.docs.first;
          final data = doc.data() as Map<String, dynamic>?;
          final isOnline = data?['isOnline'] ?? false;
          final lastSeen = data?['lastSeen'];

          if (isOnline) {
            statusText = 'Online';
            statusColor = Colors.green;
          } else {
            statusText = 'Last seen ${_formatLastSeen(lastSeen)}';
          }
        }
        final screenHeight = getResponsiveHeight(70);
        return AppBar(
          toolbarHeight: screenHeight,
          elevation: 0.4,
          backgroundColor: isDarkMode ? lightGrayBlack : purple,
          iconTheme: const IconThemeData(color: white),
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isDarkMode ? purple : lightGrayBlack,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: mediumFont(
                    text: "VCS",
                    color: white,
                    weight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  mediumFont(text: "Vision Cart", color: white),
                  smallFont(
                    text: statusText,
                    overflow: TextOverflow.ellipsis,
                    color: statusColor,
                  ),
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

  Widget _buildMessageList(ChatProvider provider, bool isDarkMode) {
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
                    text:
                        "👋 Welcome to Vision Cart!\nWe're excited to assist you with your fashion needs.\nFeel free to ask anything!",
                    color: isDarkMode ? white : grayBlack,
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
                padding: const EdgeInsets.all(12),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? (isSent
                          ? lightPurple.withAlpha(150)
                          : lightGrayBlack)
                      : (isSent
                          ? lightPurple.withAlpha(80)
                          : Colors.grey.shade200),
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
                  border: Border.all(
                    color: isSent ? Colors.deepPurple : Colors.grey.shade500,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    smallFont(
                      text: message.message,
                      color: isDarkMode ? white : grayBlack,
                      align: TextAlign.start,
                      weight: FontWeight.w500,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        smallFont(text: time, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500),
                        if (isSent) ...[
                          const SizedBox(width: 5),
                          _buildStatusIcon(message.status,isDarkMode),
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

  Widget _buildStatusIcon(String status, bool isDarkMode) {
    switch (status) {
      case 'sending':
        return Icon(
          Icons.access_time,
          color: isDarkMode ? Colors.grey.shade300 : Colors.grey,
          size: 18,
        );
      case 'sent':
        return  Icon(
          Icons.done,
          color: isDarkMode ? Colors.grey.shade300 : Colors.grey,
          size: 18,
        );
      case 'delivered':
        return  Icon(
          Icons.done_all,
          color: isDarkMode ? Colors.grey.shade300 : Colors.grey,
          size: 18,
        );
      case 'seen':
        return  Icon(
          Icons.done_all,
          color: isDarkMode ? lightGreen : darkBlue,
          size: 18,
        );
      default:
        return Icon(
          Icons.done,
          color: isDarkMode ? Colors.grey.shade300 : Colors.grey,
          size: 18,
        );
    }
  }

  Widget _buildMessageInput(ChatProvider provider, bool isDarkMode) {
    final currentUser =
        FirebaseAuth.instance.currentUser!.displayName.toString();
    return Container(
      padding: const EdgeInsets.all(8),
      color: isDarkMode ? lightGrayBlack : white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                hintText: 'Type a message',
                hintStyle: GoogleFonts.exo2(
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
                filled: true,
                fillColor: isDarkMode ? grayBlack : const Color(0xFFF0F0F0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  provider.sendMessage(text, currentUser);
                  _controller.clear();
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: () {
              if (_controller.text.trim().isNotEmpty) {
                provider.sendMessage(_controller.text, currentUser);
                _controller.clear();
              }
            },
            child: CircleAvatar(
              radius: 25,
              backgroundColor: isDarkMode ? grayBlack : darkPurple2,
              child: Icon(Icons.send,
                  color: isDarkMode ? Colors.white : grayBlack),
            ),
          ),
        ],
      ),
    );
  }
}
