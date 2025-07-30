class MessageModel {
  final String message;
  final String time;
  final String date;
  final bool isSender; // true for customer, false for seller
  final String status; // 'sending', 'sent', 'delivered', 'seen'

  MessageModel({
    required this.message,
    required this.time,
    required this.date,
    required this.isSender,
    required this.status,
  });

  factory MessageModel.fromMap(Map<String, dynamic> data) {
    return MessageModel(
      message: data['message'],
      time: data['time'],
      date: data['date'],
      isSender: data['isSender'] ?? true,
      status: data['status'] ?? 'sending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'time': time,
      'date': date,
      'isSender': isSender,
      'status': status,
    };
  }
}