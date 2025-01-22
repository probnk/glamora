import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glamora/BottomNavBar/BottomNavBar.dart';
import 'package:glamora/Reuse%20Widgets/userDetailsTexfield.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/UserDetailsModel.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/UserDetailsProvider.dart';
import 'package:provider/provider.dart';

class UserDetails extends StatefulWidget {
  const UserDetails({super.key});

  @override
  State<UserDetails> createState() => _UserDetailsState();
}

class _UserDetailsState extends State<UserDetails> {
  final _fullNameController = TextEditingController();
  final _AddressController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _emailAddressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Fetch user details from Firestore and update provider
    _fetchAndUpdateUserDetails();
  }

// Fetch user details from Firestore and update the provider
  _fetchAndUpdateUserDetails() async {
    final userDetailsProvider = context.read<UserDetailsProvider>();
    await userDetailsProvider.fetchUserDetails(); // Fetch data from Firestore

    // Once the data is fetched, update the text controllers
    _fullNameController.text = userDetailsProvider.userDetails.fullName;
    _AddressController.text = userDetailsProvider.userDetails.address;
    _phoneNumberController.text = userDetailsProvider.userDetails.phoneNumber;
    _emailAddressController.text = userDetailsProvider.userDetails.email;
    _zipCodeController.text = userDetailsProvider.userDetails.zipCode;
  }

  _userDetailsBody({required bool isDarkMode}) {
    return Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        children: [
          _detailsCard(isDarkMode: isDarkMode),
          SizedBox(height: 10),
          _textFieldFunctionCalls(isDarkMode: isDarkMode),
          SizedBox(height: 20),
          _addDetailsButton(isDarkMode: isDarkMode)
        ],
      ),
    );
  }

  _detailsCard({required bool isDarkMode}) {
    return Consumer<UserDetailsProvider>(
      builder: (context, value, child) {
        return Card(
          elevation: 3,
          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          color: isDarkMode ? lightGrayBlack : white,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleFont(
                    text: value.userDetails.fullName,
                    color: isDarkMode ? white : grayBlack),
                mediumFont(
                    text: value.userDetails.email,
                    maxWidth: MediaQuery.of(context).size.width * .8,
                    color: isDarkMode ? white : grayBlack),
                smallFont(
                    text: value.userDetails.address,
                    align: TextAlign.start,
                    color: isDarkMode ? white : grayBlack),
                productTitle(
                    text: value.userDetails.phoneNumber,
                    color: isDarkMode ? white : grayBlack),
                headingFont(
                    text: value.userDetails.zipCode,
                    color: isDarkMode ? white : grayBlack),
              ],
            ),
          ),
        );
      },
    );
  }

  _textFieldFunctionCalls({required bool isDarkMode}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserDetailsTextField(
          isDarkMode: isDarkMode,
          label: 'Full Name (required*)',
          controller: _fullNameController,
          hintText: "Muhammad ALi",
          inputType: "text",
          validator: _validateField,
          onChange: (String val) {
            context.read<UserDetailsProvider>().setFullName(val);
          },
        ),
        UserDetailsTextField(
          isDarkMode: isDarkMode,
          label: 'Email (optional)',
          controller: _emailAddressController,
          hintText: "xyz123@gmail.com",
          inputType: "text",
          onChange: (String val) {
            context.read<UserDetailsProvider>().setEmail(val);
          },
        ),
        UserDetailsTextField(
          isDarkMode: isDarkMode,
          label: 'Full Address (required*)',
          controller: _AddressController,
          hintText:
              "House No 21/B Block E Near Anar Kali Bazar, Lahore, Pakistan",
          inputType: "text",
          validator: _validateField,
          onChange: (String val) {
            context.read<UserDetailsProvider>().setAddress(val);
          },
        ),
        Row(
          children: [
            Container(
              width: MediaQuery.of(context).size.width * .64,
              child: UserDetailsTextField(
                isDarkMode: isDarkMode,
                label: 'Phone number (required*)',
                controller: _phoneNumberController,
                hintText: "03xxxxxxxxx",
                inputType: "number",
                validator: _validatePhoneNumber,
                onChange: (String val) {
                  context.read<UserDetailsProvider>().setPhoneNumber(val);
                },
              ),
            ),
            SizedBox(width: 10),
            Container(
              width: MediaQuery.of(context).size.width * .32,
              child: UserDetailsTextField(
                isDarkMode: isDarkMode,
                label: 'Zip Code',
                controller: _zipCodeController,
                hintText: "12345",
                inputType: "zip",
                validator: _validateZipCode,
                onChange: (String val) {
                  context.read<UserDetailsProvider>().setZipCode(val);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter phone number';
    }
    if (!value.startsWith('03') || value.length != 11) {
      return 'Invalid phone number';
    }
    return null;
  }

  String? _validateZipCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter zip code';
    }
    if (value.length != 5) {
      return 'Invalid zip code';
    }
    return null;
  }

  String? _validateField(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter this field';
    }
    return null;
  }

  _addDetailsButton({required bool isDarkMode}) {
    return Consumer<UserDetailsProvider>(
      builder: (context, value, child) {
        return Center(
          child: ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final data = UserDetailsModel(
                      fullName: _fullNameController.text,
                      phoneNumber: _phoneNumberController.text,
                      email: _emailAddressController.text.isEmpty
                          ? FirebaseAuth.instance.currentUser!.email.toString()
                          : _emailAddressController.text.toString(),
                      address: _AddressController.text,
                      zipCode: _zipCodeController.text);
                  value.saveUserDetails(data);
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: grayBlack,
                  elevation: 8,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: Container(
                  width: MediaQuery.of(context).size.width * .7,
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 40),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: isDarkMode
                              ? [white, white]
                              : [lightBlack, darkBlack])),
                  child: smallFont(
                      text: "Save Details",
                      color: isDarkMode ? grayBlack : white))),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
      appBar: AppBar(
        backgroundColor:
            themeProvider.isDarkMode ? lightGrayBlack : Colors.grey.shade50,
        centerTitle: true,
        title: titleFont(
            text: "User Details",
            color: themeProvider.isDarkMode ? white : grayBlack),
        iconTheme:
            IconThemeData(color: themeProvider.isDarkMode ? white : grayBlack),
      ),
      body: _userDetailsBody(isDarkMode: themeProvider.isDarkMode),
    );
  }
}
