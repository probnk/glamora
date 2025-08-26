// import 'package:flutter/material.dart';
// import 'package:glamora/Services/flutter_stripe_service.dart';
//
// class PaymentButton extends StatefulWidget {
//   final double amount;
//   final String currency;
//   final String itemName;
//
//   const PaymentButton({
//     Key? key,
//     required this.amount,
//     this.currency = 'USD',
//     required this.itemName,
//   }) : super(key: key);
//
//   @override
//   _PaymentButtonState createState() => _PaymentButtonState();
// }
//
// class _PaymentButtonState extends State<PaymentButton> {
//   bool _isLoading = false;
//
//   @override
//   Widget build(BuildContext context) {
//     return ElevatedButton(
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.purple,
//         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//       ),
//       onPressed: _isLoading ? null : _handlePayment,
//       child: _isLoading
//           ? const CircularProgressIndicator(
//         valueColor: AlwaysStoppedAnimation(Colors.white),
//       )
//           : Text(
//         'BUY NOW \$${widget.amount.toStringAsFixed(2)}',
//         style: const TextStyle(
//           fontSize: 18,
//           fontWeight: FontWeight.bold,
//           color: Colors.white,
//         ),
//       ),
//     );
//   }
//
//   Future<void> _handlePayment() async {
//     setState(() => _isLoading = true);
//
//     try {
//       await StripePaymentHandler.makePayment(
//         amount: widget.amount.toInt(),
//         currency: widget.currency,
//         clothingItemName: widget.itemName,
//       );
//
//       // Show success message
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Payment successful!'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Payment failed: ${e.toString()}'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }
// }