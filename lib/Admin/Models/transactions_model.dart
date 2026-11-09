class TransactionModel {
  final String? transactionId;
  final String itemCode;
  final String itemName;
  final String locationCode;
  final int quantity;
  final String direction; // 'IN' or 'OUT'
  final String type;
  final String workerId;
  final DateTime timestamp;
 
  // ---- NEW (A3 – edit / A4 – reverse) ----
  // `?` = nullable: these are empty (null) until someone edits/reverses.
  final String? editedBy; // who last edited this transaction (audit trail)
  final DateTime? editedAt; // when it was last edited
  final bool reversed; // true after the admin reverses it (A4)
  final String? reversalOf; // on a reversal row: the id of the original
 
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
    this.editedBy,
    this.editedAt,
    this.reversed = false, // default: not reversed
    this.reversalOf,
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
      // NEW fields: older transactions don't have them → null / false.
      editedBy: map['editedBy'] as String?,
      // tryParse returns null (instead of crashing) if the text is missing
      // or not a valid date.
      editedAt: DateTime.tryParse(map['editedAt']?.toString() ?? ''),
      reversed: map['reversed'] == true,
      reversalOf: map['reversalOf'] as String?,
    );
  }
 
  /// copyWith = make a NEW TransactionModel that is the same as this one,
  /// except for the fields you pass.
  /// Example: tx.copyWith(quantity: 20) → same transaction, quantity 20.
  /// We never change the original object (all fields are `final`);
  /// we create an updated copy instead. Common Dart/Flutter pattern.
  ///
  /// `??` = "if the new value is null, keep the old one".
  TransactionModel copyWith({
    String? itemCode,
    String? itemName,
    String? locationCode,
    int? quantity,
    String? direction,
    String? editedBy,
    DateTime? editedAt,
    bool? reversed,
  }) {
    return TransactionModel(
      transactionId: transactionId,
      itemCode: itemCode ?? this.itemCode,
      itemName: itemName ?? this.itemName,
      locationCode: locationCode ?? this.locationCode,
      quantity: quantity ?? this.quantity,
      direction: direction ?? this.direction,
      type: type,
      workerId: workerId,
      timestamp: timestamp,
      editedBy: editedBy ?? this.editedBy,
      editedAt: editedAt ?? this.editedAt,
      reversed: reversed ?? this.reversed,
      reversalOf: reversalOf,
    );
  }
 
  /// How this transaction changes the item's stock:
  /// IN adds the quantity (+), OUT removes it (−).
  /// A `get`ter: used like a field → tx.stockEffect
  int get stockEffect => direction == 'IN' ? quantity : -quantity;
 
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
      // Only add the optional fields when they have a value.
      // `if (...)` inside a map literal = "collection if".
      if (editedBy != null) 'editedBy': editedBy,
      if (editedAt != null) 'editedAt': editedAt!.toUtc().toIso8601String(),
      if (reversed) 'reversed': true,
      if (reversalOf != null) 'reversalOf': reversalOf,
    };
  }
}
 