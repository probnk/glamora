import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/categoryCloths.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/ProductListProvider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../Reuse Widgets/loadingShimmer.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({Key? key}) : super(key: key);

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _categories = ['T-Shirt', 'Pant', 'Hoodie'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _categories.length,
      vsync: this,
      initialIndex: 0,
    );
    _tabController.addListener(_handleTabSelection);
    WidgetsBinding.instance.addPostFrameCallback((_) => fetchProducts(context));
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) return;
    final provider = Provider.of<ProductListProvider>(context, listen: false);
    provider.setSelectedCategory(_categories[_tabController.index]);
    fetchProducts(context);
  }

  Widget _clothList({required bool isDarkMode}) {
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
            text: 'Products',
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
                buildGenderDropdown(isDarkMode: isDarkMode),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 5, right: 5),
            child: ButtonsTabBar(
              controller: _tabController,
              splashColor: lightBlue4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDarkMode
                      ? [lightOrange, darkOrange]
                      : [lightBlue, lightPurple],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              physics: const ClampingScrollPhysics(),
              elevation: 0,
              radius: 10,
              contentCenter: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              unselectedBackgroundColor: isDarkMode ? lightGrayBlack : white,
              labelStyle: GoogleFonts.exo2(
                  color: white, fontSize: 18, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.exo2(
                  color: isDarkMode ? white : grayBlack, fontSize: 16),
              tabs: _categories.map((category) => Tab(text: category)).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories
                  .map((_) => _clothList(isDarkMode: isDarkMode))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
