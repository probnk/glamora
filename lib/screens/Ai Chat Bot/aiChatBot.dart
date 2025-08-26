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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AIChatBotProvider>(context, listen: false).initConversation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<DarkModeProvider>(context).isDarkMode;
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
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isDarkMode ? purple : lightGrayBlack,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: mediumFont(text: "VCS", weight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                mediumFont(
                    text: "Vision Cart Assistant", weight: FontWeight.w600),
                smallFont(
                  text: "ready to Assist You",
                  overflow: TextOverflow.ellipsis,
                  color:
                      isDarkMode ? Colors.grey.shade400 : Colors.grey.shade200,
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
              icon: Icon(Icons.search)),
        ],
      ),
      body: Column(
        children: [
          _buildSearchSuggestions(isDarkMode: isDarkMode),
          Expanded(
            child: Consumer<AIChatBotProvider>(
              builder: (context, provider, child) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom(animated: false);
                });

                return SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: ListView.builder(
                    controller: _scrollController,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount:
                        provider.messages.length + (provider.isLoading ? 1 : 0),
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, index) {
                      if (index < provider.messages.length) {
                        final message = provider.messages[index];
                        if (message['type'] == 'products') {
                          return _ProductResults(
                              message: message, isDarkMode: isDarkMode);
                        }
                        return _ChatBubble(
                          text: message['text'],
                          isUser: message['isUser'],
                          timestamp: message['timestamp'],
                          isDarkMode: isDarkMode,
                        );
                      } else {
                        return _TypingIndicator(isDarkMode: isDarkMode);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          _InputField(controller: _controller, isDarkMode: isDarkMode),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestions({required bool isDarkMode}) {
    return Consumer<AIChatBotProvider>(
      builder: (context, provider, child) {
        if (provider.messages.isNotEmpty) return SizedBox.shrink();

        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              productTitle(
                  text: "Trending Searches",
                  weight: FontWeight.bold,
                  color: isDarkMode ? white : grayBlack),
              SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: provider.popularSearches.map((search) {
                  return FilterChip(
                    label: smallFont(
                        text: search, color: isDarkMode ? white : grayBlack),
                    onSelected: (_) => _applySearch(search),
                    backgroundColor: isDarkMode ? grayBlack : white,
                    selectedColor: isDarkMode ? grayBlack : white,
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              productTitle(
                  text: "Recent Searches",
                  weight: FontWeight.bold,
                  color: isDarkMode ? white : grayBlack),
              SizedBox(height: 10),
              if (provider.searchHistory.isEmpty)
                productTitle(
                    text: "No recent searches",
                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey),
              ...provider.searchHistory.map((search) {
                return ListTile(
                  leading: Icon(Icons.history,
                      color: isDarkMode ? Colors.grey.shade300 : Colors.grey),
                  title: smallFont(
                      text: search, color: isDarkMode ? white : grayBlack),
                  onTap: () => _applySearch(search),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _applySearch(String search) {
    _controller.text = search;
    Provider.of<AIChatBotProvider>(context, listen: false).sendMessage(search);
  }

  void _showSearchFilters(BuildContext context, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _SearchFilters(isDarkMode: isDarkMode);
      },
    );
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      final position = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(position);
      }
    }
  }
}

class _SearchFilters extends StatelessWidget {
  final bool isDarkMode;

  _SearchFilters({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AIChatBotProvider>(context);

    final TextEditingController priceController = TextEditingController();
    double v = 0.00;
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
      color: isDarkMode ? grayBlack : white,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleFont(text: "Advanced Search",color: isDarkMode ? white : grayBlack),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: provider.getFilterGender,
              dropdownColor: isDarkMode ? grayBlack : white,
              borderRadius: BorderRadius.circular(16),
              style: GoogleFonts.exo2(
                  color: isDarkMode ? white : Colors.grey),
              decoration: InputDecoration(
                labelText: "Gender",
                labelStyle: GoogleFonts.exo2(
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
                focusedBorder:OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: isDarkMode ? white : grayBlack,
                  ),
                ) ,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: Colors.grey,
                  ),
                ),
              ),
              items: ['Man', 'Woman'].map((gender) {
                return DropdownMenuItem(
                  value: gender,
                  child: smallFont(text: gender,color: isDarkMode ? white : lightGrayBlack),
                );
              }).toList(),
              onChanged: (value) => provider.setFilterGender(value),
            ),
            SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: provider.getFilterCategory,
              dropdownColor: isDarkMode ? grayBlack : white,
              borderRadius: BorderRadius.circular(16),
              style: GoogleFonts.exo2(
                  color: isDarkMode ? white : Colors.grey),
              decoration: InputDecoration(
                labelText: "Gender",
                labelStyle: GoogleFonts.exo2(
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: isDarkMode ? white : grayBlack,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: Colors.grey,
                  ),
                ),
              ),
              items: [
                'T-Shirt',
                'Pant',
                'Hoodie',
              ].map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: smallFont(text: cat,color: isDarkMode ? white : lightGrayBlack),
                );
              }).toList(),
              onChanged: (value) => provider.setFilterCategory(value),
            ),
            SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: provider.getFilterColorName,
                    dropdownColor: isDarkMode ? grayBlack : white,
                    borderRadius: BorderRadius.circular(16),
                    style: GoogleFonts.exo2(
                        color: isDarkMode ? white : Colors.grey),
                    decoration: InputDecoration(
                      labelText: "Gender",
                      labelStyle: GoogleFonts.exo2(
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDarkMode ? white : grayBlack,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    items: [
                      'Red',
                      'Blue',
                      'Green',
                      'Black',
                      'White',
                      'Gray',
                      'Pink',
                      'Purple',
                      'Yellow',
                      'Orange',
                      'Brown',
                      'Multi-color'
                    ].map((color) {
                      return DropdownMenuItem(
                        value: color,
                        child: smallFont(text: color,color: isDarkMode ? white : lightGrayBlack),
                      );
                    }).toList(),
                    onChanged: (value) => provider.setFilterColorName(value),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: provider.getFilterSize,
                    dropdownColor: isDarkMode ? grayBlack : white,
                    borderRadius: BorderRadius.circular(16),
                    style: GoogleFonts.exo2(
                        color: isDarkMode ? white : Colors.grey),
                    decoration: InputDecoration(
                      labelText: "Gender",
                      labelStyle: GoogleFonts.exo2(
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDarkMode ? white : grayBlack,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    items: ['S', 'M', 'L', 'XL'].map((size) {
                      return DropdownMenuItem(
                        value: size,
                        child: smallFont(text: size,color: isDarkMode ? white : lightGrayBlack),
                      );
                    }).toList(),
                    onChanged: (value) => provider.setFilterSize(value),
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            TextField(
              controller: priceController,
              enabled: true,
              style:GoogleFonts.exo2(
                fontSize: 14,
                  color: isDarkMode ? white : grayBlack) ,
              decoration: InputDecoration(
                hintText: 'Enter the price',
                hintStyle: GoogleFonts.exo2(
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: isDarkMode ? white : grayBlack,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: Colors.grey,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode ? lightGrayBlack : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                prefixStyle:GoogleFonts.exo2(color: Colors.grey,fontSize: 14) ,
                prefixText:"Rs. "
              ),
              minLines: 1,
              keyboardType: TextInputType.number,
              autofocus: true,
              onChanged: (value) {
                v = v + double.parse(value);
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                provider.setFilterMaxPrice(v);
                provider.applyFilters();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? white : lightGrayBlack,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Center(
                  child: productTitle(
                      text: "Search Products",
                      color: isDarkMode ? grayBlack : white,
                      maxWidth: MediaQuery.of(context).size.width * .5)),
            ),
          ],
        ),
      ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    return IntrinsicWidth(
      child: Container(
        margin: isUser
            ? EdgeInsets.only(left: screenWidth * .25, top: 10, bottom: 10)
            : EdgeInsets.only(right: screenWidth * .25, top: 10, bottom: 10),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxWidth: screenWidth * 0.75,
        ),
        decoration: BoxDecoration(
          color: isDarkMode
              ? (isUser ? lightPurple.withAlpha(150) : lightGrayBlack)
              : (isUser ? lightPurple.withAlpha(80) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode
                ? (isUser ? Colors.deepPurple : Colors.grey.shade100)
                : (isUser ? Colors.deepPurple : Colors.grey.shade500),
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
                  color: isDarkMode ? white : lightGrayBlack,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('h:mm a').format(timestamp),
              style: GoogleFonts.exo2(
                fontSize: 10,
                color: isDarkMode ? Colors.grey.shade300 : Colors.grey,
              ),
            ),
          ],
        ),
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

    return Container(
      margin: EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: productTitle(
                  maxWidth: 300,
                  text: message['text'] ?? "Recommended Products",
                  color: isDarkMode ? white : grayBlack,
                  weight: FontWeight.bold)),
          SizedBox(height: 12),
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: mediumFont(
                  text: "No products found matching your criteria",
                  color: isDarkMode ? white : grayBlack,
                  weight: FontWeight.bold),
            )
          else
            SizedBox(
              height: MediaQuery.of(context).size.height * .5,
              child: ListView.builder(
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                physics: BouncingScrollPhysics(),
                itemCount: products.length,
                padding: EdgeInsets.symmetric(horizontal: 12),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return InkWell(
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
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
          SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  final bool isDarkMode;

  _TypingIndicator({required this.isDarkMode});

  @override
  _TypingIndicatorState createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: widget.isDarkMode ? green : Colors.deepOrange,
                child: Icon(Icons.smart_toy, color: Colors.white),
              ),
              SizedBox(width: 12),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? Colors.green.withAlpha(150)
                      : Colors.deepOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: widget.isDarkMode ? green : Colors.deepOrange,
                      width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDot(0, widget.isDarkMode),
                    _buildDot(1, widget.isDarkMode),
                    _buildDot(2, widget.isDarkMode),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDot(int index, bool isDarkMode) {
    return FadeTransition(
      opacity: _animation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isDarkMode ? green : Colors.deepOrange,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDarkMode;

  const _InputField({required this.controller, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AIChatBotProvider>();
    final isLoading = provider.isLoading;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? lightGrayBlack : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: true,
              style:GoogleFonts.exo2(
                  fontSize: 14,
                  color: isDarkMode ? white : grayBlack) ,
              decoration: InputDecoration(
                hintText: 'Ask anything in English or Roman Urdu...',
                hintStyle: GoogleFonts.exo2(
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDarkMode ? grayBlack : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                prefixIcon: Icon(Icons.search,
                    color: isDarkMode ? Colors.grey : Colors.deepPurple),
              ),
              minLines: 1,
              maxLines: 3,
              autofocus: true,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:grayBlack,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(
                isLoading ? Icons.close : Icons.send,
                color: isDarkMode ? white : grayBlack,
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
