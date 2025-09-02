import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  final List<String> _emojis = ['👍', '❤️', '😂', '😮', '😡'];

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
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.transparent,
                backgroundImage: AssetImage("assets/icons/logo_1.png"),
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
            GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! > 0) {
                  // swiped right
                  provider.setRepliedMessage(
                      message.isSender ? "You" : "Seller", message.message);
                }
              },
              onLongPressStart: (details) {
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
                    items: _emojis
                        .map((e) => PopupMenuItem<String>(
                              value: e,
                              child:
                                  Text(e, style: const TextStyle(fontSize: 24)),
                            ))
                        .toList(),
                  ).then((value) {
                    if (value != null && message.id != null) {
                      provider.addReaction(message.id!, value);
                    }
                  });
                } else if (message.isSender) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: smallFont(
                          text: "You Can't react on Your Own Message")));
                }
              },
              child: IntrinsicWidth(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      margin: EdgeInsets.only(
                          top: 6, bottom: message.reaction.isNotEmpty ? 14 : 6),
                      padding: const EdgeInsets.all(6),
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width * 0.25,
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? (isSent ? green.withAlpha(100) : lightGrayBlack)
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
                          color: isDarkMode
                              ? (isSent ? green : Colors.grey.shade500)
                              : (isSent
                                  ? Colors.deepPurple
                                  : Colors.grey.shade500),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.repliedTo.isNotEmpty &&
                              message.repliedMessage.isNotEmpty) ...[
                            Container(
                              constraints: BoxConstraints(
                                minWidth:
                                    MediaQuery.of(context).size.width * 0.25,
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.grey.withAlpha(80)
                                    : Colors.white54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              clipBehavior: Clip.hardEdge,
                              // 👈 ensures children stay inside border
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      width: 4,
                                      color: message.isSender
                                          ? (isDarkMode ? green : purple)
                                          : (isDarkMode
                                              ? Colors.grey.shade300
                                              : Colors.grey
                                                  .shade700), // green bar inside rounded border
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          smallFont(
                                              text: message.repliedTo,
                                              color: isDarkMode
                                                  ? white
                                                  : grayBlack,
                                              weight: FontWeight
                                                  .bold // like WhatsApp bold green name
                                              ),
                                          smallFont(
                                            text: message.repliedMessage,
                                            color: isDarkMode
                                                ? white
                                                : lightGrayBlack,
                                            // lighter for reply text
                                            align: TextAlign.start,
                                            overflow: TextOverflow.ellipsis,
                                          ),
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
                              padding: EdgeInsetsGeometry.only(left: 8),
                              child: smallFont(
                                text: message.message,
                                color: isDarkMode ? white : grayBlack,
                                align: TextAlign.start,
                                weight: FontWeight.w500,
                              )),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              smallFont(
                                  text: time,
                                  color: isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade500),
                              if (isSent) ...[
                                const SizedBox(width: 5),
                                _buildStatusIcon(message.status, isDarkMode),
                              ],
                            ],
                          )
                        ],
                      ),
                    ),
                    // Modify the reaction Positioned widget in _buildMessageList to include onTap
                    if (message.reaction.isNotEmpty)
                      Positioned(
                        bottom: -7,
                        left: isSent ? null : 10,
                        right: isSent ? 7 : null,
                        child: InkWell(
                          onTap: () {
                            if (message.id != null) {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: isDarkMode ? grayBlack : white,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20)),
                                ),
                                builder: (BuildContext context) {
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header with reaction and message preview
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: isDarkMode
                                                    ? lightGrayBlack
                                                    : Colors.grey.shade200,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                message.reaction,
                                                style: const TextStyle(
                                                    fontSize: 24),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  smallFont(
                                                    text: 'Reaction on:',
                                                    color: isDarkMode
                                                        ? Colors.grey.shade400
                                                        : Colors.grey.shade600,
                                                    weight: FontWeight.bold,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  smallFont(
                                                    text: message.message,
                                                    color: isDarkMode
                                                        ? white
                                                        : grayBlack,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        // Divider
                                        Divider(
                                          color: isDarkMode
                                              ? Colors.grey.shade700
                                              : Colors.grey.shade300,
                                        ),
                                        // Remove option as a ListTile
                                        ListTile(
                                          leading: Icon(
                                            Icons.delete_outline,
                                            color: isDarkMode
                                                ? Colors.redAccent
                                                : Colors.red,
                                          ),
                                          title: smallFont(
                                            text: 'Tap to remove reaction',
                                            color:
                                                isDarkMode ? white : grayBlack,
                                          ),
                                          onTap: () {
                                            provider
                                                .removeReaction(message.id!);
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
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Text(
                                message.reaction,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ),
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
        return Icon(
          Icons.done,
          color: isDarkMode ? Colors.grey.shade300 : Colors.grey,
          size: 18,
        );
      case 'delivered':
        return Icon(
          Icons.done_all,
          color: isDarkMode ? Colors.grey.shade300 : Colors.grey,
          size: 18,
        );
      case 'seen':
        return Icon(
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
      child: Column(
        children: [
          if (provider.repliedMessage.isNotEmpty &&
              provider.repliedTo.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.hardEdge,
              // ensures bar stays inside rounded border
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left vertical colored bar
                    Container(
                      width: 4,
                      color: provider.repliedTo == "You"
                          ? (isDarkMode ? green : purple)
                          : (isDarkMode
                              ? Colors.grey.shade300
                              : Colors.grey.shade700),
                    ),
                    const SizedBox(width: 8),

                    // Reply text section
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            smallFont(
                              text: provider.repliedTo,
                              color: isDarkMode
                                  ? Colors.greenAccent
                                  : Colors.green,
                              weight: FontWeight.bold,
                            ),
                            smallFont(
                              text: provider.repliedMessage,
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black87,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Close button
                    GestureDetector(
                      onTap: () => provider.setRepliedMessageEmpty(),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: GoogleFonts.exo2(
                      fontSize: 14, color: isDarkMode ? white : grayBlack),
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
                      _sendMessage(provider);
                      _controller.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () {
                  if (_controller.text.trim().isNotEmpty) {
                    _sendMessage(provider);
                    _controller.clear();
                  }
                },
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: isDarkMode ? grayBlack : purple,
                  child: Icon(Icons.send, color: white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _sendMessage(ChatProvider provider) {
    if (_controller.text.trim().isEmpty) return;
    provider.sendMessage(_controller.text.trim(),
        FirebaseAuth.instance.currentUser!.displayName.toString(),
        repliedTo: provider.repliedTo ?? '',
        repliedMessage: provider.repliedMessage ?? '');
    _controller.clear();
    provider.setRepliedMessageEmpty();
  }
}
