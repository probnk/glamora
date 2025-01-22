class NotificationModel {
  final String photoUrl;
  final String title;
  final String subTitle;
  final String time;
  String status;

  NotificationModel(
      {required this.photoUrl,
        required this.title,
        required this.subTitle,
        required this.time,
        required this.status});
}
