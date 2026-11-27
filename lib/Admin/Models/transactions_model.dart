class TransactionModel {
  final String? transactionId;
  final int numericId;

  // Stored directly on the transaction in Firebase Realtime Database
  final int? itemId;
  final String locationCode;
  final int quantity;
  final String direction; // 'IN' or 'OUT'
  final String type;
  // Maps to `createdBy` in Firebase Realtime Database
  final String stockKeeperId;
  final DateTime timestamp;

  // Hydrated from `items` / location helpers in memory
  final String itemCode;
  final String itemName;
  final String uomCode;
  final String color;
  final double length;
  final double sw;
  final double totalWeight;
  final String warehouse;
  final String rack;
  final int shelfNo;
  final int stock;

  // Audit / edit / reverse fields
  final String? editedBy;
  final DateTime? editedAt;
  final bool reversed;
  final String? reversalOf;
  final String? reversedBy;
  final DateTime? reversedAt;
  final String? reversalId;

  TransactionModel({
    this.transactionId,
    required this.numericId,
    this.itemId,
    required this.locationCode,
    required this.quantity,
    required this.direction,
    required this.type,
    required this.stockKeeperId,
    required this.timestamp,
    this.itemCode = '',
    this.itemName = '',
    this.uomCode = '',
    this.color = '',
    this.length = 0.0,
    this.sw = 0.0,
    this.totalWeight = 0.0,
    this.warehouse = '',
    this.rack = '',
    this.shelfNo = 0,
    this.stock = 0,
    this.editedBy,
    this.editedAt,
    this.reversed = false,
    this.reversalOf,
    this.reversedBy,
    this.reversedAt,
    this.reversalId,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    final resolvedTxId = map['transactionId']?.toString() ?? id;
    return TransactionModel(
      transactionId: resolvedTxId,
      numericId:
          (map['numericId'] as num?)?.toInt() ?? _numberFromId(resolvedTxId),
      itemId: (map['itemId'] as num?)?.toInt(),
      locationCode: map['locationCode']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      direction: map['direction']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      stockKeeperId:
          (map['createdBy'] ?? map['stockKeeperId'] ?? map['workerId'] ?? '')
              .toString(),
      timestamp: _parseDateTime(map['timestamp']) ?? DateTime.now(),
      itemCode: map['itemCode']?.toString() ?? '',
      itemName: map['itemName']?.toString() ?? '',
      uomCode: map['uomCode']?.toString() ?? '',
      color: map['color']?.toString() ?? '',
      length: (map['length'] as num?)?.toDouble() ?? 0.0,
      sw: (map['sw'] as num?)?.toDouble() ?? 0.0,
      totalWeight: (map['totalWeight'] as num?)?.toDouble() ?? 0.0,
      warehouse: map['warehouse']?.toString() ?? '',
      rack: map['rack']?.toString() ?? '',
      shelfNo: (map['shelfNo'] as num?)?.toInt() ?? 0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      editedBy: map['editedBy']?.toString(),
      editedAt: _parseDateTime(map['editedAt']),
      reversed: map['reversed'] == true,
      reversalOf: map['reversalOf']?.toString(),
      reversedBy: map['reversedBy']?.toString(),
      reversedAt: _parseDateTime(map['reversedAt']),
      reversalId: map['reversalId']?.toString(),
    );
  }

  TransactionModel copyWith({
    String? transactionId,
    int? numericId,
    int? itemId,
    String? locationCode,
    int? quantity,
    String? direction,
    String? type,
    String? stockKeeperId,
    DateTime? timestamp,
    String? itemCode,
    String? itemName,
    String? uomCode,
    String? color,
    double? length,
    double? sw,
    double? totalWeight,
    String? warehouse,
    String? rack,
    int? shelfNo,
    int? stock,
    String? editedBy,
    DateTime? editedAt,
    bool? reversed,
    String? reversalOf,
    String? reversedBy,
    DateTime? reversedAt,
    String? reversalId,
  }) {
    return TransactionModel(
      transactionId: transactionId ?? this.transactionId,
      numericId: numericId ?? this.numericId,
      itemId: itemId ?? this.itemId,
      locationCode: locationCode ?? this.locationCode,
      quantity: quantity ?? this.quantity,
      direction: direction ?? this.direction,
      type: type ?? this.type,
      stockKeeperId: stockKeeperId ?? this.stockKeeperId,
      timestamp: timestamp ?? this.timestamp,
      itemCode: itemCode ?? this.itemCode,
      itemName: itemName ?? this.itemName,
      uomCode: uomCode ?? this.uomCode,
      color: color ?? this.color,
      length: length ?? this.length,
      sw: sw ?? this.sw,
      totalWeight: totalWeight ?? this.totalWeight,
      warehouse: warehouse ?? this.warehouse,
      rack: rack ?? this.rack,
      shelfNo: shelfNo ?? this.shelfNo,
      stock: stock ?? this.stock,
      editedBy: editedBy ?? this.editedBy,
      editedAt: editedAt ?? this.editedAt,
      reversed: reversed ?? this.reversed,
      reversalOf: reversalOf ?? this.reversalOf,
      reversedBy: reversedBy ?? this.reversedBy,
      reversedAt: reversedAt ?? this.reversedAt,
      reversalId: reversalId ?? this.reversalId,
    );
  }

  /// How this transaction changes the item's stock:
  /// IN adds the quantity (+), OUT removes it (−).
  int get stockEffect => direction == 'IN' ? quantity : -quantity;

  /// True if THIS row is a reversal.
  bool get isReversal => reversalOf != null || type == 'reversal';

  /// The opposite direction: IN <-> OUT.
  String get oppositeDirection => direction == 'IN' ? 'OUT' : 'IN';

  /// Serializes only the fields written to `transactions/<id>` in Firebase.
  Map<String, dynamic> toJson() {
    return {
      if (transactionId != null) 'transactionId': transactionId,
      if (itemId != null) 'itemId': itemId,
      if (itemId == null && itemCode.isNotEmpty) 'itemCode': itemCode,
      if (itemId == null && length > 0) 'length': length,
      'locationCode': locationCode,
      'quantity': quantity,
      'direction': direction,
      'type': type,
      'createdBy': stockKeeperId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      if (editedAt != null) 'editedAt': editedAt!.toUtc().toIso8601String(),
      if (reversed) 'reversed': true,
      if (reversalOf != null) 'reversalOf': reversalOf,
      if (reversedBy != null) 'reversedBy': reversedBy,
      if (reversedAt != null)
        'reversedAt': reversedAt!.toUtc().toIso8601String(),
      if (reversalId != null) 'reversalId': reversalId,
    };
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

/// "tx_001" -> 1, "tx_051" -> 51. Anything else -> 0.
int _numberFromId(String id) {
  final match = RegExp(r'(\d+)$').firstMatch(id);
  return match == null ? 0 : int.parse(match.group(1)!);
}
