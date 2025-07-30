import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:glamora/models/ReviewsModel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/userDetailsTexfield.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/ReviewProvider.dart';
import 'package:iconly/iconly.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class Review extends StatefulWidget {
  final String gender;
  final String category;
  final String docId;

  Review(
      {super.key,
      required this.gender,
      required this.category,
      required this.docId});

  @override
  State<Review> createState() => _ReviewState();
}

class _ReviewState extends State<Review> {
  final _commentController = TextEditingController();

  Future<void> _pickImage() async {
    try {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      final productProvider = context.read<ReviewProvider>();
      if (pickedFile == null) return;

      File imageFile = File(pickedFile.path);

      // Compress the image
      final dir = await getTemporaryDirectory();
      final targetPath =
          "${dir.path}/${path.basenameWithoutExtension(imageFile.path)}_compressed.jpg";

      final XFile? compressedXFile =
          await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      if (compressedXFile == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Image compression failed")));
        return;
      }

      final File compressedFile = File(compressedXFile.path);
      productProvider.setImageFile(compressedFile);

      final fileName = path.basename(productProvider.imageFile!.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('${widget.docId} Reviews/$fileName');

      await storageRef.putFile(productProvider.imageFile!);
      final url = await storageRef.getDownloadURL();
      productProvider.setProductPhoto(url);
      productProvider.toggleLoading(false);
    } catch (e) {
      context.read<ReviewProvider>().toggleLoading(false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      context.read<ReviewProvider>().toggleLoading(false);
    }
  }

  // UI components for review section
  Widget _reviewBody({required bool isDarkMode}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          mediumFont(
              text: "Rate Us",
              color: isDarkMode ? white : lightGrayBlack,
              weight: FontWeight.w600,
              align: TextAlign.start),
          _giveRatingRow(),
          SizedBox(height: 20),
          _imagePreview(isDarkMode: isDarkMode),
          SizedBox(height: 20),
          UserDetailsTextField(
              label: "Write Your Comment",
              controller: _commentController,
              hintText: "Comment",
              inputType: "text",
              onChange: (value) {},
              validator: _validateField,
              isDarkMode: isDarkMode),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
            child: ElevatedButton(
                onPressed: () async {
                  final currentUser = await FirebaseAuth.instance.currentUser;
                  final reviewProvider = context.read<ReviewProvider>();
                  final newReview = ProductReviewModel(
                    reviewerName: currentUser!.displayName.toString(),
                    reviewDate: DateTime.now().toString(),
                    profilePhoto: currentUser.photoURL.toString(),
                    comment: _commentController.text,
                    reviewImages: reviewProvider.productPhotoUrls,
                    rating: reviewProvider.selectedStarRating,
                  );

                  await reviewProvider.submitReview(
                    docId: widget.docId,
                    gender: widget.gender,
                    category: widget.category,
                    newReview: newReview,
                  );

                  _commentController.clear();
                  reviewProvider.clearImages();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Review submitted")),
                  );
                },
                style: ElevatedButton.styleFrom(
                    elevation: 4,
                    backgroundColor: isDarkMode ? darkGreen : grayBlack),
                child: smallFont(
                    text: "Submit", color: white, weight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // Rating row for user to give stars
  Widget _giveRatingRow() {
    return Consumer<ReviewProvider>(
      builder: (context, value, child) {
        return Container(
          height: 40,
          child: ListView.builder(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                return IconButton(
                    onPressed: () {
                      value.setStarRating(index);
                    },
                    icon: Icon(
                      value.selectedStarRating >= index
                          ? IconlyBold.star
                          : IconlyLight.star,
                      color: Colors.yellow.shade800,
                      size: 30,
                    ));
              }),
        );
      },
    );
  }

  Widget _imagePreview({required bool isDarkMode}) {
    return Consumer<ReviewProvider>(builder: (context, value, child) {
      // Clear data when widget is disposed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final route = ModalRoute.of(context);
        if (route?.isCurrent == false) {
          value.productPhotoUrls.clear();
          value.clearImages();
        }
      });

      // If no images, show just the add button
      if (value.productPhotoUrls.isEmpty) {
        return Container(
          height: 100,
          child: InkWell(
            onTap: _pickImage,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode ? Colors.grey.shade200 : lightGrayBlack,
                  width: 2,
                ),
              ),
              child: Center(
                child: value.isLoading
                    ? CircularProgressIndicator()
                    : Icon(
                        IconlyBold.plus,
                        color:
                            isDarkMode ? Colors.grey.shade200 : lightGrayBlack,
                      ),
              ),
            ),
          ),
        );
      }

      // Calculate how many rows we need (3 images per row)
      int itemCount = value.productPhotoUrls.length;
      int rowCount = (itemCount / 3).ceil();

      return Column(
        children: [
          // For each row of images
          for (int row = 0; row < rowCount; row++)
            Container(
              height: 100,
              margin: EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Images for this row (max 3)
                  for (int i = row * 3; i < (row + 1) * 3 && i < itemCount; i++)
                    Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.yellow, width: 2),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.network(
                              value.productPhotoUrls[i],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          if (value.isLoading && i == itemCount - 1)
                            Center(
                              child: CircularProgressIndicator(),
                            ),
                        ],
                      ),
                    ),

                  // Add button if this is the last row and we have space
                  if (row == rowCount - 1 && itemCount % 3 != 0)
                    InkWell(
                      onTap: _pickImage,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.grey.shade200
                                : lightGrayBlack,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: value.isLoading
                              ? CircularProgressIndicator()
                              : Icon(
                                  IconlyBold.plus,
                                  color: isDarkMode
                                      ? Colors.grey.shade200
                                      : lightGrayBlack,
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // If we have exactly 3, 6, 9... images, show add button in new row
          if (itemCount % 3 == 0)
            Container(
              height: 100,
              child: InkWell(
                onTap: _pickImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDarkMode ? Colors.grey.shade200 : lightGrayBlack,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: value.isLoading
                        ? CircularProgressIndicator()
                        : Icon(
                            IconlyBold.plus,
                            color: isDarkMode
                                ? Colors.grey.shade200
                                : lightGrayBlack,
                          ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  // Validate the comment field
  String? _validateField(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a comment';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkModeProvider = Provider.of<DarkModeProvider>(context);
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          iconTheme: IconThemeData(
              color: isDarkModeProvider.isDarkMode ? white : grayBlack),
          backgroundColor:
              isDarkModeProvider.isDarkMode ? lightGrayBlack : white,
          title: headingFont(
              text: "Write Review",
              color: isDarkModeProvider.isDarkMode ? white : lightGrayBlack,
              weight: FontWeight.bold),
        ),
        backgroundColor: isDarkModeProvider.isDarkMode ? grayBlack : white,
        body: _reviewBody(isDarkMode: isDarkModeProvider.isDarkMode));
  }

  @override
  void dispose() {
    final reviewProvider = context.read<ReviewProvider>();
    reviewProvider.clearImages();
    super.dispose();
  }
}
