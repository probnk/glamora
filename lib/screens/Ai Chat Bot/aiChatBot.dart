import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/aiChatBotProvider.dart';
import 'package:glamora/screens/Live Chat Support/MessagingScreen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _showScrollToBottomButton = false;

  /// True when user has manually scrolled up — suppresses auto-scroll to bottom.
  bool _userScrolledUp = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AIChatBotProvider>(context, listen: false)
          .initConversation();
    });

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final atBottom = pos.pixels >= pos.maxScrollExtent - 60;

      // User is dragging upward
      if (pos.userScrollDirection == ScrollDirection.forward) {
        _userScrolledUp = true;
      }
      // User reached bottom — reset flag
      if (atBottom) {
        _userScrolledUp = false;
      }

      final shouldShow = !atBottom;
      if (_showScrollToBottomButton != shouldShow) {
        setState(() => _showScrollToBottomButton = shouldShow);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    _userScrolledUp = false;
    if (!_scrollController.hasClients) return;
    if (animated) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    Provider.of<AIChatBotProvider>(context, listen: false)
        .sendMessage(trimmed);
    _controller.clear();
    _focusNode.unfocus();
    // User just sent a message — they want to see the reply, so reset flag
    _userScrolledUp = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<DarkModeProvider>(context).isDarkMode;

    // Auto-scroll only when new messages arrive AND user hasn't scrolled up
    final msgCount =
    context.select<AIChatBotProvider, int>((p) => p.messages.length);
    if (msgCount != _lastMessageCount) {
      _lastMessageCount = msgCount;
      if (!_userScrolledUp) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());
      }
    }

    return Scaffold(
      backgroundColor: isDarkMode ? grayBlack : white,
      appBar: _buildAppBar(isDarkMode),
      body: GestureDetector(
        onTap: () => _focusNode.unfocus(),
        child: Stack(
          children: [
            Column(
              children: [
                // ── Message list — performant ListView.builder
                Expanded(child: _MessageList(
                  scrollController: _scrollController,
                  isDarkMode: isDarkMode,
                  onScrolledAway: (v) {
                    if (_showScrollToBottomButton != v) {
                      setState(() => _showScrollToBottomButton = v);
                    }
                  },
                  onNavigateToSeller: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MessagingScreen()),
                  ),
                )),

                // ── Input
                _InputField(
                  controller: _controller,
                  isDarkMode: isDarkMode,
                  focusNode: _focusNode,
                  onSend: _sendMessage,
                ),
              ],
            ),

            // ── Scroll-to-bottom FAB
            if (_showScrollToBottomButton)
              Positioned(
                bottom: 80,
                right: 16,
                child: FloatingActionButton.small(
                  backgroundColor: isDarkMode ? green : purple,
                  onPressed: _scrollToBottom,
                  child:
                  const Icon(Icons.arrow_downward, color: white, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(bool isDarkMode) {
    return AppBar(
      elevation: 0.4,
      backgroundColor: isDarkMode ? lightGrayBlack : darkPurple.withAlpha(200),
      iconTheme: const IconThemeData(color: white),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.transparent,
            backgroundImage: const AssetImage("assets/icons/logo_1.png"),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              mediumFont(
                text: "Vision Cart Assistant",
                weight: FontWeight.w600,
                color: white,
              ),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  smallFont(text: "Online 24/7", color: Colors.grey.shade300),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Sentiment icon — read-only indicator, lightweight
        Selector<AIChatBotProvider, UserSentiment>(
          selector: (_, p) => p.currentSentiment,
          builder: (_, sentiment, __) => _SentimentIcon(sentiment: sentiment),
        ),
        IconButton(
          onPressed: () => _showSearchFilters(context, isDarkMode),
          icon: const Icon(Icons.filter_alt, color: white),
          tooltip: "Advanced Filters",
        ),
      ],
    );
  }

  void _showSearchFilters(BuildContext ctx, bool isDarkMode) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDarkMode ? grayBlack : white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _SearchFilters(isDarkMode: isDarkMode),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MESSAGE LIST — isolated widget, uses ListView.builder for performance
// RepaintBoundary per bubble so scroll doesn't repaint the whole list
// ══════════════════════════════════════════════════════════════════════════════

class _MessageList extends StatelessWidget {
  final ScrollController scrollController;
  final bool isDarkMode;
  final void Function(bool) onScrolledAway;
  final VoidCallback onNavigateToSeller;

  const _MessageList({
    required this.scrollController,
    required this.isDarkMode,
    required this.onScrolledAway,
    required this.onNavigateToSeller,
  });

  @override
  Widget build(BuildContext context) {
    // Selector: only rebuilds when message count or loading state changes
    return Selector<AIChatBotProvider,
        ({int count, bool loading, bool showEscalation})>(
      selector: (_, p) => (
      count: p.messages.length,
      loading: p.isLoading,
      showEscalation: p.showEscalationButton,
      ),
      builder: (ctx, state, __) {
        final provider = Provider.of<AIChatBotProvider>(ctx, listen: false);
        final messages = provider.messages;
        if (state.loading) {
          return _ChatShimmer(isDarkMode: isDarkMode);
        }
        if (messages.isEmpty && !state.loading) {
          return _SearchSuggestions(
            isDarkMode: isDarkMode,
            popularSearches: provider.popularSearches,
            searchHistory: provider.searchHistory,
            onSearch: (t) => provider.sendMessage(t),
          );
        }

        final itemCount =
            messages.length + (state.loading ? 1 : 0);

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          // cacheExtent: keep more items in memory for smooth fling
          cacheExtent: 600,
          itemCount: itemCount,
          itemBuilder: (ctx, index) {
            // Typing indicator at the end
            if (index == messages.length) {
              return const RepaintBoundary(child: _TypingIndicator());
            }

            final msg = messages[index];
            final isLast = index == messages.length - 1;

            return RepaintBoundary(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ChatBubble(
                    text: msg['text'] ?? '',
                    isUser: msg['isUser'] ?? false,
                    timestamp: msg['timestamp'] ?? DateTime.now(),
                    isDarkMode: isDarkMode,
                  ),
                  // Escalation button on last bot message when triggered
                  if (isLast &&
                      !(msg['isUser'] ?? false) &&
                      state.showEscalation)
                    _EscalationButton(
                      isDarkMode: isDarkMode,
                      onTap: onNavigateToSeller,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ESCALATION BUTTON — appears below last bot message when sentiment triggers
// ══════════════════════════════════════════════════════════════════════════════

class _EscalationButton extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onTap;

  const _EscalationButton({required this.isDarkMode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 52, right: 16, bottom: 8, top: 4),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.support_agent, size: 18,color: Colors.white70,),
        label: mediumFont(
          text: "Chat with Seller",
          color: white,
          weight: FontWeight.w600,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDarkMode ? darkRed : lightRed,
          padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SENTIMENT ICON — AppBar only, lightweight
// ══════════════════════════════════════════════════════════════════════════════

class _SentimentIcon extends StatelessWidget {
  final UserSentiment sentiment;
  const _SentimentIcon({required this.sentiment});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (sentiment) {
      case UserSentiment.happy:
        icon = Icons.sentiment_very_satisfied;
        color = Colors.greenAccent;
        break;
      case UserSentiment.confused:
        icon = Icons.sentiment_neutral;
        color = Colors.amberAccent;
        break;
      case UserSentiment.frustrated:
        icon = Icons.sentiment_dissatisfied;
        color = Colors.orangeAccent;
        break;
      case UserSentiment.angry:
        icon = Icons.sentiment_very_dissatisfied;
        color = Colors.redAccent;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SEARCH SUGGESTIONS — shown when no messages yet
// ══════════════════════════════════════════════════════════════════════════════

class _SearchSuggestions extends StatelessWidget {
  final bool isDarkMode;
  final List<String> popularSearches;
  final List<String> searchHistory;
  final void Function(String) onSearch;

  const _SearchSuggestions({
    required this.isDarkMode,
    required this.popularSearches,
    required this.searchHistory,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          productTitle(
            text: "Trending Searches",
            weight: FontWeight.bold,
            color: isDarkMode ? white : grayBlack,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: popularSearches
                .map((s) => ActionChip(
              label: smallFont(
                  text: s, color: isDarkMode ? white : grayBlack),
              onPressed: () => onSearch(s),
              backgroundColor:
              isDarkMode ? lightGrayBlack : Colors.grey[100],
              labelPadding:
              const EdgeInsets.symmetric(horizontal: 12),
            ))
                .toList(),
          ),
          const SizedBox(height: 24),
          productTitle(
            text: "Recent Searches",
            weight: FontWeight.bold,
            color: isDarkMode ? white : grayBlack,
          ),
          const SizedBox(height: 12),
          if (searchHistory.isEmpty)
            productTitle(
              text: "No recent searches",
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
            ),
          ...searchHistory.map((s) => ListTile(
            leading: Icon(Icons.history,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
            title:
            smallFont(text: s, color: isDarkMode ? white : grayBlack),
            onTap: () => onSearch(s),
            contentPadding: EdgeInsets.zero,
          )),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TYPING INDICATOR — single StatefulWidget, no per-dot AnimationControllers
// Uses a single controller + TweenSequence for all 3 dots
// This was the main scroll lag source in the original code
// ══════════════════════════════════════════════════════════════════════════════

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  _TypingIndicatorState createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<DarkModeProvider>(context).isDarkMode;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDarkMode ? green : Colors.deepOrange,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy, color: white, size: 20),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDarkMode ? lightGrayBlack : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      // Stagger: dot i peaks at progress (i * 0.2 + 0.2)
                      final peak = (i * 0.25 + 0.15).clamp(0.0, 1.0);
                      final dist = (_ctrl.value - peak).abs();
                      final opacity = (1.0 - dist * 4.0).clamp(0.3, 1.0);
                      return Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isDarkMode ? green : purple,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CHAT BUBBLE — const-friendly, RepaintBoundary applied by parent ListView
// ══════════════════════════════════════════════════════════════════════════════

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isDarkMode;

  const _ChatBubble({
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.only(
        bottom: 12,
        left: isUser ? screenWidth * 0.15 : 0,
        right: !isUser ? screenWidth * 0.15 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isDarkMode ? green : purple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy, color: white, size: 18),
            ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: screenWidth * 0.75),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? (isUser ? Colors.grey.shade800 : lightGrayBlack)
                    : (isUser ? Colors.blue.shade50 : Colors.grey.shade100),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: text,
                    softLineBreak: true,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.exo2(
                        fontSize: 14,
                        color: isDarkMode ? white : grayBlack,
                        height: 1.5,
                      ),
                      strong: GoogleFonts.exo2(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? white : grayBlack,
                      ),
                      em: GoogleFonts.exo2(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: isDarkMode ? white : grayBlack,
                      ),
                      listBullet: GoogleFonts.exo2(
                        fontSize: 14,
                        color: isDarkMode ? white : grayBlack,
                      ),
                      a: GoogleFonts.exo2(
                        fontSize: 14,
                        color: isDarkMode ? green : purple,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('h:mm a').format(timestamp),
                    style: GoogleFonts.exo2(
                      fontSize: 10,
                      color: isDarkMode
                          ? Colors.grey.shade500
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.blue.shade800
                    : Colors.blue.shade200,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: white, size: 18),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SEARCH FILTERS BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _SearchFilters extends StatefulWidget {
  final bool isDarkMode;
  const _SearchFilters({required this.isDarkMode});

  @override
  __SearchFiltersState createState() => __SearchFiltersState();
}

class __SearchFiltersState extends State<_SearchFilters> {
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AIChatBotProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              titleFont(
                  text: "Advanced Filters",
                  color: widget.isDarkMode ? white : grayBlack),
              IconButton(
                icon: Icon(Icons.close,
                    color: widget.isDarkMode ? white : grayBlack),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildFilterField(
            title: "Gender",
            value: provider.getFilterGender,
            items: ['Man', 'Woman', 'Unisex'],
            onChanged: provider.setFilterGender,
          ),
          const SizedBox(height: 16),
          _buildFilterField(
            title: "Category",
            value: provider.getFilterCategory,
            items: ['T-Shirt', 'Hoodie', 'Pant'],
            onChanged: provider.setFilterCategory,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFilterField(
                  title: "Color",
                  value: provider.getFilterColorName,
                  items: [
                    'Red', 'Blue', 'Green', 'Black', 'White',
                    'Gray', 'Pink', 'Purple', 'Yellow', 'Orange', 'Brown',
                  ],
                  onChanged: provider.setFilterColorName,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFilterField(
                  title: "Size",
                  value: provider.getFilterSize,
                  items: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
                  onChanged: provider.setFilterSize,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            decoration: InputDecoration(
              labelText: 'Maximum Price (PKR)',
              labelStyle: GoogleFonts.exo2(
                color: widget.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey,
              ),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: widget.isDarkMode ? green : purple, width: 2),
              ),
              prefixText: "Rs. ",
              prefixStyle: GoogleFonts.exo2(
                  color: widget.isDarkMode ? white : grayBlack),
            ),
            style:
            GoogleFonts.exo2(color: widget.isDarkMode ? white : grayBlack),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_priceController.text.isNotEmpty) {
                  provider
                      .setFilterMaxPrice(double.tryParse(_priceController.text));
                }
                provider.applyFilters();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isDarkMode ? green : purple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: mediumFont(
                text: "Apply Filters & Search",
                color: white,
                weight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                provider.clearFilters();
                _priceController.clear();
              },
              child: smallFont(
                text: "Clear All Filters",
                color: widget.isDarkMode
                    ? Colors.grey.shade400
                    : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterField({
    required String title,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        smallFont(
          text: title,
          color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey,
          weight: FontWeight.w500,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.isDarkMode
                  ? Colors.grey.shade700
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: widget.isDarkMode ? grayBlack : white,
            style: GoogleFonts.exo2(
                color: widget.isDarkMode ? white : grayBlack),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: smallFont(
                  text: "Select $title",
                  color: widget.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey,
                ),
              ),
              ...items.map((item) => DropdownMenuItem<String>(
                value: item,
                child: smallFont(
                    text: item,
                    color: widget.isDarkMode ? white : grayBlack),
              )),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// INPUT FIELD
// ══════════════════════════════════════════════════════════════════════════════

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDarkMode;
  final FocusNode focusNode;
  final void Function(String) onSend;

  const _InputField({
    required this.controller,
    required this.isDarkMode,
    required this.focusNode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading =
    context.select<AIChatBotProvider, bool>((p) => p.isLoading);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? grayBlack : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? lightGrayBlack : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    Icons.message,
                    color: isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: GoogleFonts.exo2(
                        fontSize: 14,
                        color: isDarkMode ? white : grayBlack,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ask me anything about our clothes...',
                        hintStyle: GoogleFonts.exo2(
                          color: isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                        const EdgeInsets.symmetric(vertical: 14),
                      ),
                      minLines: 1,
                      maxLines: 3,
                      onSubmitted: (t) {
                        if (!isLoading) onSend(t);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              if (isLoading) {
                context
                    .read<AIChatBotProvider>()
                    .cancelRequest();
              } else {
                onSend(controller.text);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isLoading
                    ? Colors.red.shade400
                    : (isDarkMode ? green : purple),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                isLoading ? Icons.close : Icons.send_rounded,
                color: white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _ChatShimmer extends StatelessWidget {
  final bool isDarkMode;
  const _ChatShimmer({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final baseColor =
    isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor =
    isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          // Message 1 — user (right aligned, short)
          _ShimmerBubble(isUser: true, widthFactor: 0.45, lines: 1),
          SizedBox(height: 14),
          // Message 2 — bot (left aligned, longer with 3 lines)
          _ShimmerBubble(isUser: false, widthFactor: 0.75, lines: 3),
          SizedBox(height: 14),
          // Message 3 — user (right aligned, medium)
          _ShimmerBubble(isUser: true, widthFactor: 0.55, lines: 2),
          SizedBox(height: 14),
          // Message 4 — bot (left aligned, medium)
          _ShimmerBubble(isUser: false, widthFactor: 0.68, lines: 2),
          SizedBox(height: 14),

          _ShimmerBubble(isUser: true, widthFactor: 0.55, lines: 1),
          SizedBox(height: 14),
          // Message 4 — bot (left aligned, medium)
          _ShimmerBubble(isUser: false, widthFactor: 0.68, lines:4),
        ],
      ),
    );
  }
}

class _ShimmerBubble extends StatelessWidget {
  final bool isUser;
  final double widthFactor; // fraction of screen width
  final int lines;

  const _ShimmerBubble({
    required this.isUser,
    required this.widthFactor,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleWidth = screenWidth * widthFactor;
    const lineHeight = 12.0;
    const lineSpacing = 8.0;
    const avatarSize = 32.0;

    return Row(
      mainAxisAlignment:
      isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Bot avatar placeholder
        if (!isUser) ...[
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],

        // Bubble
        Container(
          width: bubbleWidth,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < lines; i++) ...[
                Container(
                  height: lineHeight,
                  width: i == lines - 1 && lines > 1
                      ? bubbleWidth * 0.6  // last line shorter
                      : double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                if (i < lines - 1) const SizedBox(height: lineSpacing),
              ],
              const SizedBox(height: 8),
              // Timestamp placeholder
              Container(
                height: 8,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),

        // User avatar placeholder
        if (isUser) ...[
          const SizedBox(width: 8),
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}