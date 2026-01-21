import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/ProductCard.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/aiChatBotProvider.dart';
import 'package:glamora/screens/Product%20Details/ProductDetails.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottomButton = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AIChatBotProvider>(context, listen: false).initConversation();
    });

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final isAtBottom = _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 50;
        setState(() {
          _showScrollToBottomButton = !isAtBottom;
        });
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<DarkModeProvider>(context).isDarkMode;
    final provider = Provider.of<AIChatBotProvider>(context);

    return Scaffold(
      backgroundColor: isDarkMode ? grayBlack : white,
      appBar: AppBar(
        elevation: 0.4,
        backgroundColor:
        isDarkMode ? lightGrayBlack : darkPurple.withAlpha(200),
        iconTheme: const IconThemeData(color: white),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.transparent,
              backgroundImage: AssetImage("assets/icons/logo_1.png"),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                mediumFont(
                    text: "Vision Cart Assistant",
                    weight: FontWeight.w600,
                    color: white
                ),
                smallFont(
                  text: "Online 24/7",
                  overflow: TextOverflow.ellipsis,
                  color: Colors.grey.shade300,
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              _showSearchFilters(context, isDarkMode);
            },
            icon: Icon(Icons.filter_alt, color: white),
            tooltip: "Advanced Filters",
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => _focusNode.unfocus(),
        child: Stack(
          children: [
            Column(
              children: [
                if (provider.messages.isEmpty)
                  _buildSearchSuggestions(isDarkMode: isDarkMode),
                Expanded(
                  child: Consumer<AIChatBotProvider>(
                    builder: (context, provider, child) {
                      return Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  children: [
                                    ...provider.messages.map((message) {
                                      if (message['type'] == 'products') {
                                        return _ProductResults(
                                          message: message,
                                          isDarkMode: isDarkMode,
                                        );
                                      }
                                      return _ChatBubble(
                                        text: message['text'],
                                        isUser: message['isUser'],
                                        timestamp: message['timestamp'],
                                        isDarkMode: isDarkMode,
                                      );
                                    }).toList(),
                                    if (provider.isLoading)
                                      const _TypingIndicator(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                _InputField(
                  controller: _controller,
                  isDarkMode: isDarkMode,
                  focusNode: _focusNode,
                ),
              ],
            ),
            if (_showScrollToBottomButton)
              Positioned(
                bottom: 80,
                right: 16,
                child: FloatingActionButton.small(
                  backgroundColor: isDarkMode ? green : purple,
                  onPressed: _scrollToBottom,
                  child: Icon(Icons.arrow_downward, color: white, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions({required bool isDarkMode}) {
    final provider = Provider.of<AIChatBotProvider>(context, listen: false);

    return Container(
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
            children: provider.popularSearches.map((search) {
              return ActionChip(
                label: smallFont(
                    text: search,
                    color: isDarkMode ? white : grayBlack
                ),
                onPressed: () => _applySearch(search),
                backgroundColor: isDarkMode ? lightGrayBlack : Colors.grey[100],
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          productTitle(
            text: "Recent Searches",
            weight: FontWeight.bold,
            color: isDarkMode ? white : grayBlack,
          ),
          const SizedBox(height: 12),
          if (provider.searchHistory.isEmpty)
            productTitle(
              text: "No recent searches",
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
            ),
          ...provider.searchHistory.map((search) {
            return ListTile(
              leading: Icon(Icons.history,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
              title: smallFont(
                  text: search,
                  color: isDarkMode ? white : grayBlack
              ),
              onTap: () => _applySearch(search),
              contentPadding: EdgeInsets.zero,
            );
          }),
        ],
      ),
    );
  }

  void _applySearch(String search) {
    _controller.text = search;
    _focusNode.requestFocus();
    Provider.of<AIChatBotProvider>(context, listen: false).sendMessage(search);
  }

  void _showSearchFilters(BuildContext context, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? grayBlack : white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: _SearchFilters(isDarkMode: isDarkMode),
        );
      },
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

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
              child: Icon(Icons.smart_toy, color: white, size: 20),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? lightGrayBlack
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TypingDot(delay: 0, isDarkMode: isDarkMode),
                  _TypingDot(delay: 200, isDarkMode: isDarkMode),
                  _TypingDot(delay: 400, isDarkMode: isDarkMode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  final bool isDarkMode;

  const _TypingDot({required this.delay, required this.isDarkMode});

  @override
  _TypingDotState createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? green : purple,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

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
                color: widget.isDarkMode ? white : grayBlack,
              ),
              IconButton(
                icon: Icon(Icons.close, color: widget.isDarkMode ? white : grayBlack),
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
                    'Gray', 'Pink', 'Purple', 'Yellow', 'Orange', 'Brown'
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
                color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: widget.isDarkMode ? green : purple,
                  width: 2,
                ),
              ),
              prefixText: "Rs. ",
              prefixStyle: GoogleFonts.exo2(
                color: widget.isDarkMode ? white : grayBlack,
              ),
            ),
            style: GoogleFonts.exo2(
              color: widget.isDarkMode ? white : grayBlack,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_priceController.text.isNotEmpty) {
                  provider.setFilterMaxPrice(double.parse(_priceController.text));
                }
                provider.applyFilters();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isDarkMode ? green : purple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey,
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
              color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: widget.isDarkMode ? grayBlack : white,
            style: GoogleFonts.exo2(
              color: widget.isDarkMode ? white : grayBlack,
            ),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: smallFont(
                  text: "Select $title",
                  color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey,
                ),
              ),
              ...items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: smallFont(
                    text: item,
                    color: widget.isDarkMode ? white : grayBlack,
                  ),
                );
              }).toList(),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

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
    return Container(
      margin: EdgeInsets.only(
        bottom: 12,
        left: isUser ? MediaQuery.of(context).size.width * 0.15 : 0,
        right: !isUser ? MediaQuery.of(context).size.width * 0.15 : 0,
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
              child: Icon(Icons.smart_toy, color: white, size: 18),
            ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(16),
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
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: text,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.exo2(
                        fontSize: 14,
                        color: isDarkMode ? white : grayBlack,
                        height: 1.5,
                      ),
                      a: GoogleFonts.exo2(
                        fontSize: 14,
                        color: isDarkMode ? green : purple,
                        decoration: TextDecoration.underline,
                      ),
                      strong: GoogleFonts.exo2(
                        fontSize: 14,
                        color: isDarkMode ? white : grayBlack,
                        fontWeight: FontWeight.bold,
                      ),
                      em: GoogleFonts.exo2(
                        fontSize: 14,
                        color: isDarkMode ? white : grayBlack,
                        fontStyle: FontStyle.italic,
                      ),
                      listBullet: GoogleFonts.exo2(
                        fontSize: 14,
                        color: isDarkMode ? white : grayBlack,
                      ),
                      code: GoogleFonts.robotoMono(
                        fontSize: 13,
                        color: isDarkMode ? Colors.orange : Colors.deepPurple,
                        backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('h:mm a').format(timestamp),
                    style: GoogleFonts.exo2(
                      fontSize: 10,
                      color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
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
                color: isDarkMode ? Colors.blue.shade800 : Colors.blue.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: white, size: 18),
            ),
        ],
      ),
    );
  }
}

class _ProductResults extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isDarkMode;

  const _ProductResults({required this.message, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final List<ClothingProductModel> products =
        (message['products'] as List<dynamic>?)?.cast<ClothingProductModel>() ??
            [];

    if (products.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: productTitle(
              text: message['text'] ?? "Recommended for you",
              color: isDarkMode ? white : grayBlack,
              weight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: MediaQuery.of(context).size.height * .37,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Container(
                  color: Colors.transparent,
                  width: 180,
                  margin: const EdgeInsets.only(right: 16),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetails(
                            id: product.id,
                            gender: product.gender,
                            category: product.category,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: ProductCard(
                      context: context,
                      index: index,
                      cloth: product,
                      currentUser: FirebaseAuth.instance.currentUser,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: smallFont(
              text: "${products.length} products found",
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDarkMode;
  final FocusNode focusNode;

  const _InputField({
    required this.controller,
    required this.isDarkMode,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AIChatBotProvider>();
    final isLoading = provider.isLoading;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? grayBlack : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 1,
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
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    Icons.message,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
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
                        hintText: 'Type your message...',
                        hintStyle: GoogleFonts.exo2(
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      minLines: 1,
                      maxLines: 3,
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty && !isLoading) {
                          provider.sendMessage(text.trim());
                          controller.clear();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isLoading
                  ? Colors.red.shade400
                  : (isDarkMode ? green : purple),
              borderRadius: BorderRadius.circular(25),
            ),
            child: IconButton(
              icon: Icon(
                isLoading ? Icons.close : Icons.send_rounded,
                color: white,
                size: 22,
              ),
              onPressed: () {
                if (isLoading) {
                  provider.cancelRequest();
                } else {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    provider.sendMessage(text);
                    controller.clear();
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}