class ChatUser {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final String chatDbUrl;
  final String createdAt;
  final bool isOnline;
  final String lastSeen;

  const ChatUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.chatDbUrl,
    required this.createdAt,
    required this.isOnline,
    required this.lastSeen,
  });

  factory ChatUser.fromMap(Map<String, dynamic> map) {
    return ChatUser(
      uid: map['uid'],
      name: map['name'],
      email: map['email'],
      photoUrl: map['photoUrl'],
      chatDbUrl: map['chatDbUrl'],
      createdAt: map['createdAt'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] ?? DateTime.now().toIso8601String(),
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
      'isOnline': isOnline,
      'lastSeen': lastSeen,
    };
  }
}