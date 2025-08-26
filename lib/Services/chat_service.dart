import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glamora/models/productModel.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _deepSeekKey = 'sk-b6e60a84fd5943afbab4735d55eee55c'; // Replace with your key
  final String _deepSeekUrl = 'https://api.deepseek.com/v1/chat/completions';

  Future<List<ClothingProductModel>> fetchProducts({
    required String gender,
    required String category,
    int? minPrice,
    int? maxPrice,
    String? color,
    String? size,
  }) async {
    try {
      // Convert category to match your Firestore structure
      String firestoreCategory = _convertToFirestoreCategory(category);

      CollectionReference productsRef = _firestore
          .collection('Cloths')
          .doc(gender)
          .collection(firestoreCategory);

      Query query = productsRef;

      // Apply price filters
      if (minPrice != null) {
        query = query.where('price', isGreaterThanOrEqualTo: minPrice);
      }
      if (maxPrice != null) {
        query = query.where('price', isLessThanOrEqualTo: maxPrice);
      }

      // Apply color filter
      if (color != null) {
        query = query.where('variants.colors', arrayContains: color.toLowerCase());
      }

      // Apply size filter
      if (size != null) {
        query = query.where('variants.sizes.size', isEqualTo: size.toUpperCase());
      }

      final snapshot = await query.limit(10).get();

      return snapshot.docs.map((doc) {
        return ClothingProductModel.fromSnapshot(doc);
      }).toList();
    } catch (e) {
      print("Error fetching products: $e");
      return [];
    }
  }

  String _convertToFirestoreCategory(String category) {
    switch (category.toLowerCase()) {
      case 'tshirt':
      case 't-shirt':
        return 'T Shirt';
      case 'pant':
      case 'pants':
        return 'Pant';
      case 'hoodie':
      case 'hoodies':
        return 'Hoodie';
      default:
        return category;
    }
  }

  Future<String> getAIResponse(List<Map<String, dynamic>> messages) async {
    final response = await http.post(
      Uri.parse(_deepSeekUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_deepSeekKey',
      },
      body: jsonEncode({
        'model': 'deepseek-chat',
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 500,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to get AI response: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getStorePolicies() async {
    final doc = await _firestore.collection('store_info').doc('policies').get();
    return doc.data() ?? {
      'return': '30 days return policy',
      'exchange': '15 days exchange policy',
      'shipping': 'Free shipping on orders above 5000 PKR',
      'delivery': '3-5 business days',
    };
  }
}