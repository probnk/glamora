import 'package:cloud_firestore/cloud_firestore.dart';

enum ReturnStatus {
  pending,
  approved,
  rejected,
  processing,
  completed,
}

extension ReturnStatusX on ReturnStatus {
  String get label {
    switch (this) {
      case ReturnStatus.pending:    return 'Pending';
      case ReturnStatus.approved:   return 'Approved';
      case ReturnStatus.rejected:   return 'Rejected';
      case ReturnStatus.processing: return 'Processing';
      case ReturnStatus.completed:  return 'Completed';
    }
  }

  static ReturnStatus fromString(String s) {
    return ReturnStatus.values.firstWhere(
          (e) => e.name == s,
      orElse: () => ReturnStatus.pending,
    );
  }
}

class ReturnedItemModel {
  final String productId;
  final String title;
  final String imageUrl;
  final String size;
  final String color;
  final int pieces;
  final int price;

  ReturnedItemModel({
    required this.productId,
    required this.title,
    required this.imageUrl,
    required this.size,
    required this.color,
    required this.pieces,
    required this.price,
  });

  factory ReturnedItemModel.fromMap(Map<String, dynamic> data) {
    return ReturnedItemModel(
      productId: data['productId'] ?? '',
      title:     data['title']     ?? '',
      imageUrl:  data['imageUrl']  ?? '',
      size:      data['size']      ?? '',
      color:     data['color']     ?? '',
      pieces:    data['pieces']    ?? 1,
      price:     data['price']     ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'title':     title,
    'imageUrl':  imageUrl,
    'size':      size,
    'color':     color,
    'pieces':    pieces,
    'price':     price,
  };
}

class ReturnRequest {
  final String returnId;       // Firestore doc ID under requests/
  final String orderId;
  final String uid;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final List<ReturnedItemModel> items;
  final String reason;
  final String? additionalNote;
  final String submittedDate;  // human-readable display
  final String createdAt;      // ISO8601 — used for ordering
  ReturnStatus status;
  String? sellerNote;
  String? resolvedDate;

  ReturnRequest({
    required this.returnId,
    required this.orderId,
    required this.uid,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.items,
    required this.reason,
    this.additionalNote,
    required this.submittedDate,
    required this.createdAt,
    required this.status,
    this.sellerNote,
    this.resolvedDate,
  });

  ReturnRequest copyWith({
    ReturnStatus? status,
    String? sellerNote,
    String? resolvedDate,
  }) {
    return ReturnRequest(
      returnId:       returnId,
      orderId:        orderId,
      uid:            uid,
      customerName:   customerName,
      customerEmail:  customerEmail,
      customerPhone:  customerPhone,
      items:          items,
      reason:         reason,
      additionalNote: additionalNote,
      submittedDate:  submittedDate,
      createdAt:      createdAt,
      status:         status      ?? this.status,
      sellerNote:     sellerNote  ?? this.sellerNote,
      resolvedDate:   resolvedDate ?? this.resolvedDate,
    );
  }

  factory ReturnRequest.fromMap(Map<String, dynamic> data) {
    return ReturnRequest(
      returnId:      data['returnId']      ?? '',
      orderId:       data['orderId']       ?? '',
      uid:           data['uid']           ?? '',
      customerName:  data['customerName']  ?? '',
      customerEmail: data['customerEmail'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      items: (data['items'] as List<dynamic>? ?? [])
          .map((e) => ReturnedItemModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      reason:         data['reason']         ?? '',
      additionalNote: data['additionalNote'],
      submittedDate:  data['submittedDate']  ?? '',
      createdAt:      data['createdAt']      ?? DateTime.now().toIso8601String(),
      status:         ReturnStatusX.fromString(data['status'] ?? 'pending'),
      sellerNote:     data['sellerNote'],
      resolvedDate:   data['resolvedDate'],
    );
  }

  Map<String, dynamic> toMap() => {
    'returnId':      returnId,
    'orderId':       orderId,
    'uid':           uid,
    'customerName':  customerName,
    'customerEmail': customerEmail,
    'customerPhone': customerPhone,
    'items':         items.map((e) => e.toMap()).toList(),
    'reason':        reason,
    'additionalNote':additionalNote,
    'submittedDate': submittedDate,
    'createdAt':     createdAt,
    'status':        status.name,
    'sellerNote':    sellerNote,
    'resolvedDate':  resolvedDate,
  };

  factory ReturnRequest.fromSnapshot(DocumentSnapshot snapshot) {
    return ReturnRequest.fromMap(snapshot.data() as Map<String, dynamic>);
  }
}