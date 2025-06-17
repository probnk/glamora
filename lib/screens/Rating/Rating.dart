import 'package:flutter/material.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/ReviewsModel.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/RatingProvider.dart';
import 'package:provider/provider.dart';

class Rating extends StatefulWidget {
  const Rating({super.key});

  @override
  State<Rating> createState() => _RatingState();
}

class _RatingState extends State<Rating> {
  _reviewBody({required bool isDarkMode}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        shrinkWrap: true,
        physics: ScrollPhysics(),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  headingFont(text: "4.5", color: isDarkMode ? white : grayBlack),
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          color: Colors.yellow.shade700, size: 30),
                      Icon(Icons.star_rounded,
                          color: Colors.yellow.shade700, size: 30),
                      Icon(Icons.star_rounded,
                          color: Colors.yellow.shade700, size: 30),
                      Icon(Icons.star_rounded,
                          color: Colors.yellow.shade700, size: 30),
                      Icon(Icons.star_half_rounded,
                          color: Colors.yellow.shade700, size: 30),
                    ],
                  ),
                  mediumFont(
                      text: "(107 Reviews)",
                      color: Colors.grey,
                      maxWidth: MediaQuery.of(context).size.width * .4)
                ],
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _buildRatingBar(5, 16),
                    _buildRatingBar(4, 3),
                    _buildRatingBar(3, 1),
                    _buildRatingBar(2, 1),
                    _buildRatingBar(1, 1),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Consumer<RatingProvider>(
              builder: (context, value, child) {
            return ListView.builder(
                itemCount: value.ratingList.length,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  return _reviewCardDesign(ratingModel: value.ratingList[index],isDarkMode: isDarkMode);
                });
          })
        ],
      ),
    );
  }

  _buildRatingBar(int rating, int count) {
    return Row(
      children: [
        Text('$rating', style: TextStyle(fontSize: 16)),
        SizedBox(width: 8),
        Expanded(
          child: LinearProgressIndicator(
            borderRadius: BorderRadius.circular(8),
            value: count / 5,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  _reviewCardDesign({required ProductReviewModel ratingModel,required bool isDarkMode}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? lightGrayBlack : white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.transparent,
                      backgroundImage: AssetImage("assets/images/${ratingModel.profilePhoto}"),
                    ),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        productTitle(text: "${ratingModel.reviewerName}",color: isDarkMode ? white : grayBlack),
                        smallFont(
                            text: "${ratingModel.reviewDate}",
                            color: Colors.grey,
                            weight: FontWeight.w600)
                      ],
                    )
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.star_rounded,
                        color: Colors.yellow.shade700, size: 20),
                    Icon(Icons.star_rounded,
                        color: Colors.yellow.shade700, size: 20),
                    Icon(Icons.star_rounded,
                        color: Colors.yellow.shade700, size: 20),
                    Icon(Icons.star_rounded,
                        color: Colors.yellow.shade700, size: 20),
                    Icon(Icons.star_rounded,
                        color: Colors.yellow.shade700, size: 20),
                  ],
                )
              ],
            ),
            SizedBox(height: 16),
            smallFont(
                text:"${ratingModel.comment}",
                color: Colors.grey,
                align: TextAlign.start)
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
      appBar: AppBar(
        backgroundColor: themeProvider.isDarkMode ? lightGrayBlack : white,
        iconTheme: IconThemeData(
          color: themeProvider.isDarkMode ? white : grayBlack
        ),
        centerTitle: true,
        title: titleFont(text: "Reviews",color: themeProvider.isDarkMode ? white : grayBlack),
      ),
      body: _reviewBody(isDarkMode:themeProvider.isDarkMode),
    );
  }
}
