class MessageModel {
  final String? id;
  final String message;
  final String time;
  final String date;
  final bool isSender;
  final String status;
  final String reaction;
  final String repliedTo;
  final String repliedMessage;
  final String repliedType;
  final String messageType;

  MessageModel({
    this.id,
    required this.message,
    required this.time,
    required this.date,
    required this.isSender,
    required this.status,
    required this.reaction,
    required this.repliedTo,
    required this.repliedMessage,
    required this.repliedType,
    required this.messageType,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return MessageModel(
      id: id,
      message: map['message'] ?? '',
      time: map['time'] ?? '',
      date: map['date'] ?? '',
      isSender: map['isSender'] ?? false,
      status: map['status'] ?? 'sent',
      reaction: map['reaction'] ?? '',
      repliedTo: map['repliedTo'] ?? '',
      repliedMessage: map['repliedMessage'] ?? '',
      repliedType: map['repliedType'] ?? '',
      messageType: map['messageType'] ?? 'text',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'time': time,
      'date': date,
      'isSender': isSender,
      'status': status,
      'reaction': reaction,
      'repliedTo': repliedTo,
      'repliedMessage': repliedMessage,
      'repliedType': repliedType,
      'messageType': messageType,
    };
  }

  MessageModel copyWith({
    String? id,
    String? message,
    String? time,
    String? date,
    bool? isSender,
    String? status,
    String? reaction,
    String? repliedTo,
    String? repliedMessage,
    String? repliedType,
    String? messageType,
  }) {
    return MessageModel(
      id: id ?? this.id,
      message: message ?? this.message,
      time: time ?? this.time,
      date: date ?? this.date,
      isSender: isSender ?? this.isSender,
      status: status ?? this.status,
      reaction: reaction ?? this.reaction,
      repliedTo: repliedTo ?? this.repliedTo,
      repliedMessage: repliedMessage ?? this.repliedMessage,
      repliedType: repliedType ?? this.repliedType,
      messageType: messageType ?? this.messageType,
    );
  }
}