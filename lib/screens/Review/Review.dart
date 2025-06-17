import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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
  final String title;

  Review({super.key, required this.title});

  @override
  State<Review> createState() => _ReviewState();
}

class _ReviewState extends State<Review> {
  final _commentController = TextEditingController();
  final uploadProductPhoto = FirebaseFirestore.instance.collection("Products");

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      final productProvider = context.read<ReviewProvider>();
      if (pickedFile == null) return;

      File imageFile = File(pickedFile.path);

      // Compress the image
      final dir = await getTemporaryDirectory();
      final targetPath =
          "${dir.path}/${path.basenameWithoutExtension(imageFile.path)}_compressed.jpg";

      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      if (compressedXFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Image compression failed"))
        );
        return;
      }

      final File compressedFile = File(compressedXFile.path);
      productProvider.setImageFile(compressedFile);

      final fileName = path.basename(productProvider.imageFile!.path);
      final storageRef =
      FirebaseStorage.instance.ref().child('${widget.title} Reviews/$fileName');

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
  Widget _reviewBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          mediumFont(
              text: "Rate Us",
              color: lightGrayBlack,
              weight: FontWeight.w600,
              align: TextAlign.start),
          _giveRatingRow(),
          SizedBox(height: 20),
          _imagePreview(),
          SizedBox(height: 20),
          UserDetailsTextField(
              label: "Write Your Comment",
              controller: _commentController,
              hintText: "Comment",
              inputType: "text",
              onChange: (value) {},
              validator: _validateField,
              isDarkMode: context.read<DarkModeProvider>().isDarkMode),
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

  Widget _imagePreview() {
    return Container(
      height: 100, // Set a fixed height for the image preview container
      child: Row(
        children: [
          // Display images in a horizontally scrollable list
          Consumer<ReviewProvider>(
              builder: (context,value,child){
            return Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal, // Horizontal scroll
                itemCount: value.productPhotoUrls.length, // Number of images
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0), // Spacing between images
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.network(
                        value.productPhotoUrls[index],
                        width: 100, // Image width
                        height: 100, // Image height
                        fit: BoxFit.cover, // Ensure the image covers the given space
                      ),
                    ),
                  );
                },
              ),
            );
          }),
          SizedBox(width: 10), // Add some space between the images and the add button
          InkWell(
            onTap: _pickImage, // Trigger the image picking when tapped
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: lightGrayBlack, width: 2),
              ),
              child: Center(
                child: Icon(
                  IconlyBold.plus, // Add icon
                  color: lightGrayBlack,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    return Scaffold(
        appBar: AppBar(
          backgroundColor: white,
          title: headingFont(
              text: "Write Review",
              color: lightGrayBlack,
              weight: FontWeight.bold),
        ),
        backgroundColor: white,
        body: _reviewBody());
  }
}
