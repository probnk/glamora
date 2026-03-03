import 'package:firebase_auth/firebase_auth.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
      final searchProvider = Provider.of<SearchProvider>(context, listen: false);
      searchProvider.initialize();
    });
  }

  void _onSearchChanged(String value) {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    searchProvider.setQuery(value);
  }

  void _onSuggestionTapped(String suggestion) {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    _searchController.text = suggestion;
    searchProvider.setQuery(suggestion);
    searchProvider.performSearch();
    _searchFocus.requestFocus();
  }

  void _onClearText() {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    _searchController.clear();
    searchProvider.clearText();
    _searchFocus.requestFocus();
  }

  void _onBackPressed() {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    searchProvider.clearSearch();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Widget _buildEmptyState(bool isDarkMode) {
    final hasSearched = _searchController.text.isNotEmpty;
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    final isInvalidSearch = searchProvider.isInvalidSearch();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isInvalidSearch ? Icons.store_outlined : (hasSearched ? Icons.search_off : Icons.manage_search),
            size: 64,
            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            isInvalidSearch
                ? 'Sorry, we don\'t sell this'
                : (hasSearched ? 'No products found' : 'Start searching for clothes'),
            style: TextStyle(
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              isInvalidSearch
                  ? 'We only sell T-Shirts, Pants, and Hoodies.\nTry searching for these items.'
                  : (hasSearched
                  ? 'Try different keywords like:\n"men t-shirt" or "women hoodie"'
                  : 'Try "men t-shirt", "women hoodie", or "pant"'),
              style: TextStyle(
                color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (isInvalidSearch) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.text = 'men t-shirt';
                searchProvider.setQuery('men t-shirt');
                searchProvider.performSearch();
              },
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Browse T-Shirts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                foregroundColor: isDarkMode ? white : grayBlack,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<DarkModeProvider>(context).isDarkMode;
    final searchProvider = Provider.of<SearchProvider>(context);
    final screenWidth = getResponsiveWidth(MediaQuery.of(context).size.width);

    return Scaffold(
      backgroundColor: isDarkMode ? grayBlack : white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDarkMode ? lightGrayBlack : Colors.grey.shade50,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? white : grayBlack),
          onPressed: _onBackPressed,
        ),
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade800 : white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: _onSearchChanged,
            style: TextStyle(
              color: isDarkMode ? white : grayBlack,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: 'Search for clothes...',
              hintStyle: TextStyle(
                color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
                fontSize: 15,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              prefixIcon: Icon(
                Icons.search,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                size: 22,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  size: 20,
                ),
                onPressed: _onClearText,
              )
                  : null,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Suggestions Chips
          if (searchProvider.suggestions.isNotEmpty)
            Container(
              width: double.infinity,
              color: isDarkMode ? lightGrayBlack : Colors.grey.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: searchProvider.suggestions.map((suggestion) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _onSuggestionTapped(suggestion),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey.shade800 : white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 16,
                                  color: isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  suggestion,
                                  style: TextStyle(
                                    color: isDarkMode ? white : grayBlack,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Search Results
          Expanded(
            child: searchProvider.isLoading
                ? ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: 4,
              itemBuilder: (context, index) {
                return categoryProductCardShimmer(
                  isDarkMode: isDarkMode,
                  context: context,
                );
              },
            )
                : searchProvider.searchResults.isEmpty
                ? _buildEmptyState(isDarkMode)
                : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: searchProvider.searchResults.length,
              itemBuilder: (context, index) {
                return buildProductCard(
                  context,
                  searchProvider.searchResults[index],
                  index,
                  isDarkMode,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}