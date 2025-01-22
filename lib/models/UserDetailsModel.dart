class UserDetailsModel {
   String fullName;
   String phoneNumber;
   String email;
   String address;
   String zipCode;

  UserDetailsModel({
    required this.fullName,
    required this.phoneNumber,
    required this.email,
    required this.address,
    required this.zipCode,
  });

  // Factory constructor to create a UserDetailsModel from a map (for Firestore data)
  factory UserDetailsModel.fromMap(Map<String, dynamic> map) {
    return UserDetailsModel(
      fullName: map['fullName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      zipCode: map['zipCode'] ?? '',
    );
  }

  // Method to convert the model to a map (for saving to Firestore)
  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'email': email,
      'address': address,
      'zipCode': zipCode,
    };
  }
}
