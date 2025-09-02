import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> trackPersonalization(String uid, String category, String action) async{
  Supabase.instance.client.functions.invoke(
      'updatePersonalizationScore',
      body: {
        "uid": uid,
        "category": category,
        "action": action, // "view", "wishlist", "cart", "order"
      }
  );
}
