import 'dart:io';
import 'package:flutter/material.dart';
import 'package:glamora/BottomNavBar/BottomNavBar.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/onBoardingProvider.dart';
import 'package:glamora/Reuse Widgets/userDetailsTexfield.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class GenderCategoryScreen extends StatelessWidget {
  GenderCategoryScreen({Key? key}) : super(key: key);

  final TextEditingController nameController = TextEditingController();
  final List<String> genders = ['Man', 'Woman'];
  final List<String> categories = ['T-Shirt', 'Pant', 'Hoodie'];

  void pickImage(BuildContext context) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      Provider.of<GenderCategoryProvider>(context, listen: false)
          .setImage(File(picked.path));
    }
  }

  void saveData(BuildContext context) async {
    final genderProvider = Provider.of<GenderCategoryProvider>(context, listen: false);
    final loadingProvider = Provider.of<GenderCategoryProvider>(context, listen: false);

    if (genderProvider.selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a gender')),
      );
      return;
    }

    if (genderProvider.selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }

    try {
      loadingProvider.setSubmitLoading(true);

      String? imageUrl;
      if (genderProvider.selectedImage != null) {
        try {
          String fileName = 'profile_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
          print('Uploading image to: $fileName');

          // Compress the image
          final compressedImage = await FlutterImageCompress.compressAndGetFile(
            genderProvider.selectedImage!.path,
            '${genderProvider.selectedImage!.path}.compressed.jpg',
            quality: 85, // Adjust quality (0-100, 85 is a good balance)
            minWidth: 1024, // Optional: Resize to max 1024px width
            minHeight: 1024, // Optional: Resize to max 1024px height
          );

          if (compressedImage == null) {
            throw Exception('Image compression failed');
          }

          // Upload the compressed image
          await Supabase.instance.client.storage
              .from('profile_images')
              .upload(fileName, File(compressedImage.path));
          imageUrl = Supabase.instance.client.storage
              .from('profile_images')
              .getPublicUrl(fileName);
          print('Image uploaded, public URL: $imageUrl');

          // Clean up temporary compressed file
          await File(compressedImage.path).delete();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading image: $e')),
          );
          print('Error uploading image: $e');
        }
      }

      String uid = FirebaseAuth.instance.currentUser!.uid;
      print('Firebase UID: $uid');

      try {
        final response = await Supabase.instance.client.rpc('set_user_id', params: {'user_id': uid});
        print('set_user_id response: $response');
        await Future.delayed(Duration(milliseconds: 100));
        final userIdCheck = await Supabase.instance.client.rpc('get_user_id', params: {});
        print('Current app.user_id: $userIdCheck');
      } catch (e) {
        print('Error calling set_user_id: $e');
        throw e;
      }

      print('Attempting to upsert data to personalization table');
      await Supabase.instance.client.from('personalization').upsert({
        'uid': uid,
        'gender': genderProvider.selectedGender,
        'categories': genderProvider.selectedCategories,
        'name': nameController.text.isEmpty
            ? FirebaseAuth.instance.currentUser!.displayName
            : nameController.text,
        'email': FirebaseAuth.instance.currentUser!.email,
        'picture': imageUrl?.isNotEmpty == true
            ? imageUrl
            : FirebaseAuth.instance.currentUser!.photoURL,
        'timestamp': DateTime.now().toIso8601String(),
      });

      genderProvider.clear();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BottomNavBar()));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Details saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving data: $e')),
      );
      print('Error saving data: $e');
    } finally {
      loadingProvider.setSubmitLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<DarkModeProvider>(context).isDarkMode;
    final genderProvider = Provider.of<GenderCategoryProvider>(context);
    final isLoading = Provider.of<GenderCategoryProvider>(context).isLoading;

    return Scaffold(
      bottomSheet: _bottomSubmitButton(context, isDarkMode: isDarkMode),
      backgroundColor: isDarkMode ? grayBlack : white,
      appBar: AppBar(
        title: headingFont(
            text: 'Select Details', color: isDarkMode ? white : grayBlack),
        centerTitle: true,
        backgroundColor: isDarkMode ? lightGrayBlack : Colors.grey.shade100,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => pickImage(context),
                  child: genderProvider.selectedImage == null
                      ? Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image, size: 40, color: Colors.grey),
                        const SizedBox(height: 10),
                        smallFont(
                          text: "Upload your Profile Image",
                          color: isDarkMode ? white : grayBlack,
                          weight: FontWeight.w500,
                        ),
                        smallFont(
                          text: "Profile Photo should be an Image",
                          color: Colors.grey,
                          weight: FontWeight.w400,
                        ),
                      ],
                    ),
                  )
                      : Center(
                    child: CircleAvatar(
                      radius: 100,
                      backgroundImage: FileImage(genderProvider.selectedImage!),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                mediumFont(
                  text: "Optional",
                  color: isDarkMode ? white : grayBlack,
                  weight: FontWeight.w500,
                ),
                const SizedBox(height: 8),
                UserDetailsTextField(
                  label: "Full Name",
                  controller: nameController,
                  hintText: "Enter Your Name",
                  inputType: 'text',
                  onChange: (value) {},
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 20),
                mediumFont(
                  text: 'Select Gender*',
                  color: isDarkMode ? white : grayBlack,
                  maxWidth: 200,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: genders.map((gender) {
                    final isSelected = genderProvider.selectedGender == gender;
                    return ChoiceChip(
                      label: smallFont(
                        text: gender,
                        color: isSelected ? white : (isDarkMode ? white : grayBlack),
                        weight: FontWeight.w500,
                      ),
                      backgroundColor: isDarkMode ? lightGrayBlack : Colors.grey.shade100,
                      selected: isSelected,
                      checkmarkColor: isDarkMode ? lightGrayBlack : lightGreen,
                      selectedColor: isDarkMode ? lightGreen : grayBlack,
                      onSelected: (_) => genderProvider.selectGender(gender),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                mediumFont(
                  text: 'Select Categories*',
                  color: isDarkMode ? white : grayBlack,
                  maxWidth: 200,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: categories.map((category) {
                    final isSelected = genderProvider.selectedCategories.contains(category);
                    return FilterChip(
                      label: smallFont(
                        text: category,
                        color: isSelected ? white : (isDarkMode ? white : grayBlack),
                        weight: FontWeight.w500,
                      ),
                      backgroundColor: isDarkMode ? lightGrayBlack : Colors.grey.shade100,
                      selected: isSelected,
                      checkmarkColor: isDarkMode ? lightGrayBlack : lightGreen,
                      selectedColor: isDarkMode ? lightGreen : grayBlack,
                      onSelected: (_) => genderProvider.toggleCategory(category),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
          if (isLoading)
            Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              color: Colors.black.withAlpha(100),
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _bottomSubmitButton(BuildContext context, {required bool isDarkMode}) {
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? lightGrayBlack : Colors.grey.shade200,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: ElevatedButton(
        onPressed: () => saveData(context),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          backgroundColor: grayBlack,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: smallFont(text: "Submit"),
      ),
    );
  }
}