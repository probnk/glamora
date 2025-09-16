import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/categoryCloths.dart';
import 'package:glamora/Reuse%20Widgets/loadingShimmer.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/ProductListProvider.dart';
import 'package:provider/provider.dart';

import '../../constants/reponsivness.dart';

class SingleCategory extends StatefulWidget {
  final String? category;
  final String? gender;

  const SingleCategory({super.key, this.category, this.gender});

  @override
  State<SingleCategory> createState() => _SingleCategoryState();
}

class _SingleCategoryState extends State<SingleCategory> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialFetch());
  }

  Future<void> _initialFetch() async {
    final provider = Provider.of<ProductListProvider>(context, listen: false);

    // Override provider state if parameters are passed
    if (widget.gender != null) {
      provider.setSelectedGender(widget.gender!);
    }

    if (widget.category != null) {
      provider.setSelectedCategory(widget.category!);
    }

    await fetchProducts(context);
  }

  Widget _clothList({required bool isDarkMode}) {
    final height = getResponsiveHeight(100);
    return Consumer<ProductListProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return ListView.builder(
            itemCount: 3, // Just an arbitrary number for shimmer effect items
            itemBuilder: (context, index) {
              return categoryProductCardShimmer(
                  isDarkMode: isDarkMode, context: context);
            },
          );
        }
        if (provider.productDetailsList.isEmpty) {
          return buildEmptyState(isDarkMode: isDarkMode, context: context);
        }
        return RefreshIndicator(
          onRefresh: () => fetchProducts(context),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: provider.productDetailsList.length,
            itemBuilder: (context, index) {
              return buildProductCard(context,
                  provider.productDetailsList[index], index, isDarkMode);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<DarkModeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? grayBlack : white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? lightGrayBlack : Colors.grey.shade50,
        centerTitle: true,
        title: headingFont(
            text: widget.category ?? 'Products',
            color: isDarkMode ? white : grayBlack,
            weight: FontWeight.bold),
      ),
      body: Column(
        children: [
          Container(
            color: isDarkMode ? lightGrayBlack : Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                mediumFont(
                    text: 'Gender:', color: isDarkMode ? white : grayBlack),
                const SizedBox(width: 10),
                widget.gender != null
                    ? mediumFont(
                        text: widget.gender!,
                        color: isDarkMode ? white : grayBlack)
                    : buildGenderDropdown(isDarkMode: isDarkMode),
              ],
            ),
          ),
          Expanded(child: _clothList(isDarkMode: isDarkMode)),
        ],
      ),
    );
  }
}
