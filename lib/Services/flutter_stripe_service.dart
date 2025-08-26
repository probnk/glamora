// import 'dart:convert';
// import 'package:flutter_stripe/flutter_stripe.dart';
// import 'package:flutter/material.dart';
//
// import 'package:http/http.dart' as http;
//
// class StripePaymentHandler {
//   static const String _stripeSecretKey =
//       'sk_test_51QhSrZCRS2WvYGsl9QNas2ll2NbuaQXPehMEJkqwtSRWEmwM2RT0yCf8zK0dM8zKfjivyXORLGIqgfR71gCKyciG000aWjrJ0l';
//   static const String _stripePublishableKey =
//       'pk_test_51QhSrZCRS2WvYGslbo7iM9ntEkqq6hTAynDd0sA85oTyif8FVmmm6d04Aib2mzZx54JbtqLHfrDGMzYOGXHAFSPF00bLX0Po5m';
//
//   static Future<void> init() async {
//     Stripe.publishableKey = _stripePublishableKey;
//     Stripe.merchantIdentifier = 'merchant.flutter.clothing.app';
//     await Stripe.instance.applySettings();
//   }
//
//   static Future<void> makePayment({
//     required int amount,
//     required String currency,
//     required String clothingItemName,
//   }) async {
//     try {
//       // 1. Create payment intent on your server
//       final paymentIntent = await _createPaymentIntent(amount, currency);
//
//       // 2. Initialize the payment sheet
//       await Stripe.instance.initPaymentSheet(
//         paymentSheetParameters: SetupPaymentSheetParameters(
//           paymentIntentClientSecret: paymentIntent['client_secret'],
//           merchantDisplayName: 'Fashion Store',
//           style: ThemeMode.light,
//           customerId: paymentIntent['customer'],
//           customerEphemeralKeySecret: paymentIntent['ephemeralKey'],
//           appearance: PaymentSheetAppearance(
//             colors: PaymentSheetAppearanceColors(
//               primary: Colors.purple,
//               // Match your app theme
//               background: Colors.white,
//               componentText: Colors.grey[200]!,
//               componentBorder: Colors.grey[300]!,
//               componentDivider: Colors.grey[300]!,
//             ),
//             shapes: PaymentSheetShape(
//               borderWidth: 1,
//               shadow: PaymentSheetShadowParams(color: Colors.black12),
//             ),
//             primaryButton: PaymentSheetPrimaryButtonAppearance(
//               shapes: PaymentSheetPrimaryButtonShape(blurRadius: 8),
//               colors: PaymentSheetPrimaryButtonTheme(
//                 light: PaymentSheetPrimaryButtonThemeColors(
//                   background: Colors.purple,
//                   text: Colors.white,
//                   border: Colors.purple,
//                 ),
//               ),
//             ),
//           ),
//         ),
//       );
//
//       // 3. Display the payment sheet
//       await Stripe.instance.presentPaymentSheet();
//
//       // 4. Payment successful
//       print('Payment successful!');
//       // You can show a success message or navigate to a success screen
//     } on StripeException catch (e) {
//       print('Stripe Error: ${e.error.localizedMessage}');
//       // Handle stripe specific errors
//     } catch (e) {
//       print('Error: $e');
//       // Handle generic errors
//     }
//   }
//
//   static Future<Map<String, dynamic>> _createPaymentIntent(
//       int amount, String currency) async {
//     try {
//       // In a real app, you should call your backend here
//       // This is just for demonstration - never expose your secret key in the app!
//
//       final url = Uri.parse('https://api.stripe.com/v1/payment_intents');
//       final response = await http.post(
//         url,
//         headers: {
//           'Authorization': 'Bearer $_stripeSecretKey',
//           'Content-Type': 'application/x-www-form-urlencoded',
//         },
//         body: {
//           'amount': (amount * 100).toString(), // Convert to cents
//           'currency': currency.toLowerCase(),
//           'payment_method_types[]': 'card',
//           'description': 'Clothing purchase',
//         },
//       );
//
//       return json.decode(response.body);
//     } catch (e) {
//       print('Error creating payment intent: $e');
//       rethrow;
//     }
//   }
// }
