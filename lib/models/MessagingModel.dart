class MessageModel {
  final String? id;
  final String message;
  final String time;
  final String date;
  final bool isSender; // Boolean field
  final String status;
  final String reaction;
  final String repliedTo;
  final String repliedMessage;
  final String repliedType;
  final String messageType;
  final String? localPath;

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
    this.localPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message': message,
      'time': time,
      'date': date,
      'isSender': isSender, // Store as bool
      'status': status,
      'reaction': reaction,
      'repliedTo': repliedTo,
      'repliedMessage': repliedMessage,
      'repliedType': repliedType,
      'messageType': messageType,
      'localPath': localPath,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return MessageModel(
      id: id ?? map['id'],
      message: map['message'] ?? '',
      time: map['time'] ?? '',
      date: map['date'] ?? '',
      isSender: map['isSender'] is bool
          ? map['isSender']
          : (map['isSender'] == 1 || map['isSender'] == '1'), // Convert int or String to bool
      status: map['status'] ?? '',
      reaction: map['reaction'] ?? '',
      repliedTo: map['repliedTo'] ?? '',
      repliedMessage: map['repliedMessage'] ?? '',
      repliedType: map['repliedType'] ?? '',
      messageType: map['messageType'] ?? 'text',
      localPath: map['localPath'],
    );
  }
}