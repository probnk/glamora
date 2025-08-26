class TrackingStatusModel {
  String trackingStatus;
  String timeStamp;

  TrackingStatusModel({required this.trackingStatus, required this.timeStamp});

  factory TrackingStatusModel.fromMap(Map<String, dynamic> data) {
    return TrackingStatusModel(
      trackingStatus: data['trackingStatus'] ?? '',
      timeStamp: data['timeStamp'] ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trackingStatus': trackingStatus,
      'timeStamp': timeStamp,
    };
  }
}