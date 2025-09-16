import 'package:cloud_firestore/cloud_firestore.dart';

class ChatUser {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final String chatDbUrl;
  final DateTime createdAt;

  const ChatUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.chatDbUrl,
    required this.createdAt,
  });

  factory ChatUser.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle Timestamp to DateTime conversion
    DateTime parseFirestoreDate(dynamic date) {
      if (date is Timestamp) {
        return date.toDate();
      } else if (date is String) {
        return DateTime.parse(date);
      }
      return DateTime.now();
    }

    return ChatUser(
      uid: doc.id,
      name: data['name'] ?? 'Unknown',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      chatDbUrl: data['chatDbUrl'] ?? '',
      createdAt: parseFirestoreDate(data['createdAt']),
    );
  }

  factory ChatUser.fromMap(Map<String, dynamic> map) {
    return ChatUser(
      uid: map['uid'],
      name: map['name'],
      email: map['email'],
      photoUrl: map['photoUrl'],
      chatDbUrl: map['chatDbUrl'],
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'chatDbUrl': chatDbUrl,
      'createdAt': createdAt,
    };
  }
}
