class TransactionModel {
  final String? transactionId;
  final String itemCode;
  final String itemName;
  final String locationCode;
  final int quantity;
  final String direction;
  final String type;
  final String workerId;
  final DateTime timestamp;

  TransactionModel({
    this.transactionId,
    required this.itemCode,
    required this.itemName,
    required this.locationCode,
    required this.quantity,
    required this.direction,
    required this.type,
    required this.workerId,
    required this.timestamp,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      transactionId: id,
      itemCode: map['itemCode'] ?? '',
      itemName: map['itemName'] ?? '',
      locationCode: map['locationCode'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      direction: map['direction'] ?? '',
      type: map['type'] ?? '',
      workerId: map['workerId'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'itemCode': itemCode,
      'itemName': itemName,
      'locationCode': locationCode,
      'quantity': quantity,
      'direction': direction,
      'type': type,
      'workerId': workerId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
