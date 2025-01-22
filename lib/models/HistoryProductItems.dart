class HistoryProductItems {
  String pieces;
  String total;
  String? title;
  int? newPrice;
  int? discount;
  bool reviewed;
  String? imageUrl;

  HistoryProductItems({
    required this.title,
    required this.pieces,
    required this.newPrice,
    required this.discount,
    required this.total,
    required this.reviewed,
    required this.imageUrl,
  });

  // Factory method to create a HistoryProductItems object from Firestore data
  factory HistoryProductItems.fromMap(Map<String, dynamic> data) {
    return HistoryProductItems(
      title: data['title'] ?? '',
      pieces: data['pieces'] ?? '1',
      newPrice: data['newPrice'] ?? 0,
      discount: data['discount'] ?? 0,
      total: data['total'] ?? '0',
      reviewed: data['reviewed'] ?? false,
      imageUrl: data['imageUrls'] ?? ""
    );
  }

  // Method to convert HistoryProductItems to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'pieces': pieces,
      'newPrice': newPrice,
      'discount': discount,
      'total': total,
      'imageUrls':imageUrl,
      'reviewed':reviewed
    };
  }
}