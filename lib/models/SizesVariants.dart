class ClothingSizesModel {
  final String size;
  final int stock;

  ClothingSizesModel({
    required this.size,
    required this.stock,
  });

  factory ClothingSizesModel.fromMap(Map<String, dynamic> data) {
    return ClothingSizesModel(
      size: data['size'] ?? '',
      stock: data['stock'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'size': size,
      'stock': stock,
    };
  }
}