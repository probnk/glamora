import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:glamora/models/UserDetailsModel.dart';

class UserDetailsProvider with ChangeNotifier {
  // Store the user details
  UserDetailsModel _userDetails = UserDetailsModel(
    fullName: '',
    phoneNumber: '',
    email: '',
    address: '',
    zipCode: '',
  );

  // Getter for user details
  UserDetailsModel get userDetails => _userDetails;

  // Function to save user details to Firestore
  Future<void> saveUserDetails(UserDetailsModel userDetails) async {
    try {
      final userUid = FirebaseAuth.instance.currentUser!.uid;

      if (userUid != null) {
        // Get a reference to the Firestore document
        final docRef = FirebaseFirestore.instance
            .collection("UserDetails")
            .doc(userUid) // Use email as document ID
            .collection("Details")
            .doc("details"); // You can specify the document ID if needed

        // Convert the UserDetailsModel to a map and save to Firestore
        await docRef.set(userDetails.toMap());

        // Update local provider state with the new user details
        _userDetails = userDetails;
        notifyListeners();
        print("User details saved successfully");
      }
    } catch (e) {
      print("Error saving user details: $e");
    }
  }

  // Function to fetch user details from Firestore and store them in the provider
  Future<void> fetchUserDetails() async {
    try {
      final userUid = FirebaseAuth.instance.currentUser!.uid;

      if (userUid != null) {
        // Fetch user data from Firestore
        final docSnapshot = await FirebaseFirestore.instance
            .collection("UserDetails")
            .doc(userUid)
            .collection("Details")
            .doc("details").get();  // Specify the document ID if needed

        // Check if the document exists
        if (docSnapshot.exists) {
          // Convert Firestore data to UserDetailsModel
          _userDetails = UserDetailsModel.fromMap(docSnapshot.data()!);

          // Notify listeners that the data has been updated
          notifyListeners();
        } else {
          print("No user details found for this email");
        }
      }
    } catch (e) {
      print("Error fetching user details: $e");
    }
  }

  // Setter method for full name
  void setFullName(String fullName) {
    _userDetails.fullName = fullName;
    notifyListeners();
  }

  // Setter method for phone number
  void setPhoneNumber(String phoneNumber) {
    _userDetails.phoneNumber = phoneNumber;
    notifyListeners();
  }

  // Setter method for email
  void setEmail(String email) {
    _userDetails.email = email;
    notifyListeners();
  }

  // Setter method for address
  void setAddress(String address) {
    _userDetails.address = address;
    notifyListeners();
  }

  // Setter method for zip code
  void setZipCode(String zipCode) {
    _userDetails.zipCode = zipCode;
    notifyListeners();
  }

  // Method to set all user details at once (when fetching data from Firestore)
  void setUserDetails(UserDetailsModel user) {
    _userDetails.fullName = user.fullName;
    _userDetails.phoneNumber = user.phoneNumber;
    _userDetails.email = user.email;
    _userDetails.address = user.address;
    _userDetails.zipCode = user.zipCode;
    notifyListeners();
  }

  void clearUserDetails() {
    _userDetails.fullName = "";
    _userDetails.phoneNumber = "";
    _userDetails.email = "";
    _userDetails.address = "";
    _userDetails.zipCode = "";
    notifyListeners();
  }
}
