// // supabase_services.dart
//
// class SupabaseService {
//   final SupabaseClient _client = Supabase.instance.client;
//
//   Future<void> insertUserData({
//     required String uid,
//     required String gender,
//     required List<String> categories,
//     required String name,
//     required String email,
//     required String? picture,
//   }) async {
//     final response = await _client.from('personalization').insert({
//       'id': uid,
//       'gender': gender,
//       'categories': categories,
//       'name': name,
//       'email': email,
//       'picture': picture,
//     });
//
//     if (response.error != null) {
//       throw response.error!;
//     }
//   }
//
//   Future<bool> isUserPersonalized(String uid) async {
//     final response = await _client
//         .from('personalization')
//         .select()
//         .eq('id', uid)
//         .maybeSingle();
//
//     return response != null;
//   }
// }
