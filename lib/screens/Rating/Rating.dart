import 'package:flutter/material.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/ReviewsModel.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/RatingProvider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class Rating extends StatefulWidget {
  List<ProductReviewModel> reviews;

  Rating({super.key, required this.reviews});

  @override
  State<Rating> createState() => _RatingState();
}

class _RatingState extends State<Rating> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RatingProvider>().countStarRatings(widget.reviews);
    });
  }


  _reviewBody({required bool isDarkMode, required RatingProvider rating}) {
    if (widget.reviews.isNotEmpty)
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
                    headingFont(
                        text: widget.reviews[0].rating.toString(),
                        color: isDarkMode ? white : grayBlack),
                    _buildStarRating(widget.reviews[0].rating.toDouble()),
                    mediumFont(
                        text: ("(${widget.reviews.length} Reviews)"),
                        color: Colors.grey,
                        maxWidth: MediaQuery.of(context).size.width * .4)
                  ],
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      _buildRatingBar(5, rating.fifthCount),
                      _buildRatingBar(4, rating.fourthCount),
                      _buildRatingBar(3, rating.thirdCount),
                      _buildRatingBar(2, rating.secondCount),
                      _buildRatingBar(1, rating.firstCount),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            ListView.builder(
                itemCount: widget.reviews.length,
                shrinkWrap: true,
                reverse: true,
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  return _reviewCardDesign(
                      ratingModel: widget.reviews[index],
                      isDarkMode: isDarkMode);
                })
          ],
        ),
      );
    else
      Center(child: mediumFont(text: "No Review Found Yet",color: white));
  }

  _buildRatingBar(int rating, int count) {
    return Row(
      children: [
        smallFont(text: rating.toString(),color: white),
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

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(
            Icons.star_rounded,
            color: Colors.yellow.shade700,
            size: 20,
          );
        } else if (index == rating.floor() && rating % 1 >= 0.5) {
          return Icon(
            Icons.star_half_rounded,
            color: Colors.yellow.shade700,
            size: 20,
          );
        } else {
          return Icon(
            Icons.star_outline_rounded,
            color: Colors.yellow.shade700,
            size: 20,
          );
        }
      }),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM, yyyy').format(date);
  }

  // New time formatting method
  String _formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  _reviewCardDesign(
      {required ProductReviewModel ratingModel, required bool isDarkMode}) {
    DateTime tempDate =
        new DateFormat("yyyy-MM-dd hh:mm:ss").parse(ratingModel.reviewDate);
    final date = _formatDate(tempDate);
    final time = _formatTime(tempDate);
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
                      backgroundImage: NetworkImage(ratingModel.profilePhoto),
                    ),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        productTitle(
                            text: "${ratingModel.reviewerName}",
                            color: isDarkMode ? white : grayBlack),
                        smallFont(
                            text: "$date",
                            color: Colors.grey,
                            weight: FontWeight.w600)
                      ],
                    )
                  ],
                ),
               Column(
                 crossAxisAlignment: CrossAxisAlignment.end,
                 children: [
                   _buildStarRating(ratingModel.rating.toDouble()),
                   smallFont(
                     text: time,
                     color: Colors.grey,
                     weight: FontWeight.w600,
                   ),
                 ],
               )
              ],
            ),
            SizedBox(height: 16),
            smallFont(
                text: "${ratingModel.comment}",
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
    final ratingProvider = Provider.of<RatingProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
      appBar: AppBar(
        backgroundColor: themeProvider.isDarkMode ? lightGrayBlack : white,
        iconTheme:
            IconThemeData(color: themeProvider.isDarkMode ? white : grayBlack),
        centerTitle: true,
        title: titleFont(
            text: "Reviews",
            color: themeProvider.isDarkMode ? white : grayBlack),
      ),
      body: _reviewBody(isDarkMode: themeProvider.isDarkMode, rating:ratingProvider),
    );
  }
}
