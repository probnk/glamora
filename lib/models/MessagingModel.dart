class MessageModel {
  final String? id;
  final String message;
  final String time;
  final String date;
  final bool isSender; // true for customer, false for seller
  final String status; // 'sending', 'sent', 'delivered', 'seen'
  final String reaction;
  final String repliedTo;
  final String repliedMessage;

  MessageModel({
    this.id,
    required this.message,
    required this.time,
    required this.date,
    required this.isSender,
    required this.status,
    this.reaction = '',
    this.repliedTo = '',
    this.repliedMessage = ''
  });

  factory MessageModel.fromMap(Map<String, dynamic> data, {String? id}) {
    return MessageModel(
      id: id,
      message: data['message'] ?? '',
      time: data['time'] ?? DateTime.now().toIso8601String(),
      date: data['date'] ?? DateTime.now().toIso8601String(),
      isSender: data['isSender'] ?? false,
      status: data['status'] ?? 'sent',
      reaction: data['reaction'] ?? '',
      repliedTo: data['repliedTo'] ?? '',
      repliedMessage: data['repliedMessage'] ?? '',
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
      'repliedMessage':repliedMessage
    };
  }
}