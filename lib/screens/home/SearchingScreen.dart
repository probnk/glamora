import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/loadingShimmer.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/constants/reponsivness.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/SearchProvider.dart';
import 'package:provider/provider.dart';

import '../../Reuse Widgets/categoryCloths.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  void _onSearchChanged() {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    searchProvider.setQuery(_searchController.text);

    // Mark that user has started searching
    if (_searchController.text.isNotEmpty && !_hasSearched) {
      setState(() {
        _hasSearched = true;
      });
    }
  }

  void _onSuggestionTapped(String suggestion) {
    _searchController.text = suggestion;
    setState(() {
      _hasSearched = true;
    });
    _searchFocus.requestFocus();
  }

  void _onClearText() {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    _searchController.clear();
    searchProvider.clearText(); // Only clear text, keep results
    _searchFocus.requestFocus();
  }

  void _onBackPressed() {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    searchProvider.clearSearch(); // Clear everything when going back
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<DarkModeProvider>(context).isDarkMode;
    final searchProvider = Provider.of<SearchProvider>(context);
    final screenWidth = getResponsiveWidth(MediaQuery.of(context).size.width);

    return Scaffold(
      backgroundColor: isDarkMode ? grayBlack : white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? lightGrayBlack : Colors.grey.shade50,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? white : grayBlack),
          onPressed: _onBackPressed,
        ),
        title: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            style: TextStyle(color: isDarkMode ? white : grayBlack),
            decoration: InputDecoration(
              hintText: 'Search products, categories, or tags...',
              hintStyle: TextStyle(
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search,
                  color: isDarkMode ? white : grayBlack),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear,
                    color: isDarkMode ? white : grayBlack),
                onPressed: _onClearText,
              )
                  : null,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Suggestions - Always show when available
          if (searchProvider.suggestions.isNotEmpty)
            Container(
              color: isDarkMode ? lightGrayBlack : Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: searchProvider.suggestions.map((suggestion) {
                  return ActionChip(
                    label: mediumFont(
                      text: suggestion,
                      color: isDarkMode ? white : grayBlack,
                    ),
                    backgroundColor:
                    isDarkMode ? Colors.grey.shade700 : white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isDarkMode
                            ? Colors.grey.shade600
                            : Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                    onPressed: () => _onSuggestionTapped(suggestion),
                  );
                }).toList(),
              ),
            ),
          // Search Results
          Expanded(
            child: StreamBuilder<List<ClothingProductModel>>(
              stream: searchProvider.searchStream,
              builder: (context, snapshot) {
                // Show loading state
                if (searchProvider.isLoading) {
                  return ListView.builder(
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return categoryProductCardShimmer(
                          isDarkMode: isDarkMode, context: context);
                    },
                  );
                }

                // Show error state
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 50,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        mediumFont(
                          text: 'Error loading search results',
                          color: isDarkMode ? white : grayBlack,
                        ),
                      ],
                    ),
                  );
                }

                final hasData = snapshot.hasData && snapshot.data!.isNotEmpty;
                final isEmpty = snapshot.hasData && snapshot.data!.isEmpty;

                // Show empty state only if user searched and found nothing
                if (isEmpty && _hasSearched) {
                  return buildEmptyState(
                    isDarkMode: isDarkMode,
                    context: context,
                    message: 'No products found for "${searchProvider.query}".',
                  );
                }

                // Show initial state when no search has been performed
                if (!hasData && !_hasSearched) {
                  return Center(
                    child: mediumFont(
                      text: 'Start typing to search for products...',
                      color: isDarkMode ? white : grayBlack,
                    ),
                  );
                }

                // Show search results
                final products = snapshot.data ?? [];
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    return buildProductCard(
                        context, products[index], index, isDarkMode);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Custom empty state widget
Widget buildEmptyState({
  required bool isDarkMode,
  required BuildContext context,
  String message = 'No products found.',
}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.search_off,
          size: 50,
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            message,
            style: TextStyle(
              color: isDarkMode ? white : grayBlack,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}