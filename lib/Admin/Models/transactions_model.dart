class TransactionModel {
  final String? transactionId;
  final int numericId;
  final String itemCode;
  final String itemName;

  // ---- NEW: Item & Location Metadata Columns ----
  final String uomCode;
  final String color;
  final double length;
  final double sw;
  final double totalWeight;
  final String locationCode;
  final String warehouse;
  final String rack;
  final int shelfNo;
  final int stock;

  final int quantity;
  final String direction; // 'IN' or 'OUT'
  final String type;
  final String stockKeeperId;
  final DateTime timestamp;

  // ---- Audit / Edit / Reverse Fields ----
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
    required this.itemCode,
    required this.itemName,
    required this.uomCode,
    required this.color,
    required this.length,
    required this.sw,
    required this.totalWeight,
    required this.locationCode,
    required this.warehouse,
    required this.rack,
    required this.shelfNo,
    required this.stock,
    required this.quantity,
    required this.direction,
    required this.type,
    required this.stockKeeperId,
    required this.timestamp,
    this.editedBy,
    this.editedAt,
    this.reversed = false,
    this.reversalOf,
    this.reversedBy,
    this.reversedAt,
    this.reversalId,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      transactionId: map['transactionId'] ?? id,
      numericId: (map['numericId'] as num?)?.toInt() ?? 0,
      itemCode: map['itemCode'] ?? '',
      itemName: map['itemName'] ?? '',
      uomCode: map['uomCode'] ?? '',
      color: map['color'] ?? '',
      length: (map['length'] as num?)?.toDouble() ?? 0.0,
      sw: (map['sw'] as num?)?.toDouble() ?? 0.0,
      totalWeight: (map['totalWeight'] as num?)?.toDouble() ?? 0.0,
      locationCode: map['locationCode'] ?? '',
      warehouse: map['warehouse'] ?? '',
      rack: map['rack'] ?? '',
      shelfNo: (map['shelfNo'] as num?)?.toInt() ?? 0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      direction: map['direction'] ?? '',
      type: map['type'] ?? '',
      stockKeeperId: map['stockKeeperId'] ?? map['workerId'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      editedBy: map['editedBy'] as String?,
      editedAt: DateTime.tryParse(map['editedAt']?.toString() ?? ''),
      reversed: map['reversed'] == true,
      reversalOf: map['reversalOf'] as String?,
      reversedBy: map['reversedBy'] as String?,
      reversedAt: DateTime.tryParse(map['reversedAt']?.toString() ?? ''),
      reversalId: map['reversalId'] as String?,
    );
  }

  TransactionModel copyWith({
    String? itemCode,
    String? itemName,
    String? uomCode,
    String? color,
    double? length,
    double? sw,
    double? totalWeight,
    String? locationCode,
    String? warehouse,
    String? rack,
    int? shelfNo,
    int? stock,
    int? quantity,
    String? direction,
    String? type,
    String? stockKeeperId,
    String? editedBy,
    DateTime? editedAt,
    bool? reversed,
    String? reversedBy,
    DateTime? reversedAt,
    String? reversalId,
  }) {
    return TransactionModel(
      transactionId: transactionId,
      numericId: numericId,
      itemCode: itemCode ?? this.itemCode,
      itemName: itemName ?? this.itemName,
      uomCode: uomCode ?? this.uomCode,
      color: color ?? this.color,
      length: length ?? this.length,
      sw: sw ?? this.sw,
      totalWeight: totalWeight ?? this.totalWeight,
      locationCode: locationCode ?? this.locationCode,
      warehouse: warehouse ?? this.warehouse,
      rack: rack ?? this.rack,
      shelfNo: shelfNo ?? this.shelfNo,
      stock: stock ?? this.stock,
      quantity: quantity ?? this.quantity,
      direction: direction ?? this.direction,
      type: type ?? this.type,
      stockKeeperId: stockKeeperId ?? this.stockKeeperId,
      timestamp: timestamp,
      editedBy: editedBy ?? this.editedBy,
      editedAt: editedAt ?? this.editedAt,
      reversed: reversed ?? this.reversed,
      reversalOf: reversalOf,
      reversedBy: reversedBy ?? this.reversedBy,
      reversedAt: reversedAt ?? this.reversedAt,
      reversalId: reversalId ?? this.reversalId,
    );
  }

  /// How this transaction changes the item's stock:
  /// IN adds the quantity (+), OUT removes it (−).
  int get stockEffect => direction == 'IN' ? quantity : -quantity;

  /// true if THIS row is a reversal.
  bool get isReversal => reversalOf != null || type == 'reversal';

  /// The opposite direction: IN ↔ OUT
  String get oppositeDirection => direction == 'IN' ? 'OUT' : 'IN';

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'numericId': numericId,
      'itemCode': itemCode,
      'itemName': itemName,
      'uomCode': uomCode,
      'color': color,
      'length': length,
      'sw': sw,
      'totalWeight': totalWeight,
      'locationCode': locationCode,
      'warehouse': warehouse,
      'rack': rack,
      'shelfNo': shelfNo,
      'stock': stock,
      'quantity': quantity,
      'direction': direction,
      'type': type,
      'stockKeeperId': stockKeeperId,
      'timestamp': timestamp.toIso8601String(),
      if (editedBy != null) 'editedBy': editedBy,
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
