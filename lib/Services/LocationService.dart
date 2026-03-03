import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:glamora/providers/ProductListProvider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

Future<void> storeUserLocation(BuildContext context) async {
  try {
    // Request location permission
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      print('Location permission denied');
      return;
    } else if(permission == LocationPermission.always || permission == LocationPermission.whileInUse){
      print('Location permission allowed always');
    }
    // Get current position
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Get city and country from coordinates
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    Placemark place = placemarks[0];
    String city = place.locality ?? 'Unknown';
    String country = place.country ?? 'Unknown';

    // Get current timestamp
    String timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    // Reference to Firebase Realtime Database
    DatabaseReference ref = FirebaseDatabase.instance.ref('location/');

    // Generate unique key for each entry
    String? key = ref.push().key;
    final genderProvider = Provider.of<ProductListProvider>(context,listen: false);
    // Store data
    await ref.child(key!).set({
      'city': city,
      'country': country,
      'gender':genderProvider.gender,
      'timestamp': timestamp,
    });

    print('Location stored successfully: $city, $country at $timestamp');
  } catch (e) {
    print('Error storing location: $e');
  }
}