class InsufficientStockException implements Exception {
  const InsufficientStockException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ItemRow {
  const ItemRow({required this.key, required this.data});

  static const String stockField = 'Stock';

  final String key;
  final Map<String, dynamic> data;

  int get quantity =>
      ((data[stockField] ?? data['Quantity']) as num?)?.toInt() ?? 0;

  /// The item's unique number (the `id` field, NOT the Firebase key).
  /// Key and id are different: key = id - 1 (items/0 holds id 1).
  /// `as num?` → the value may be missing (null) or an int/double;
  /// `?.toInt()` only runs when it isn't null.
  int? get id => (data['id'] as num?)?.toInt();

  String get code => (data['Item Code'] ?? '').toString();
  String get color => (data['COLOR'] ?? '').toString();
  String get uomCode => (data['UOM Code'] ?? '').toString();

  String nameOr(String code) =>
      (data['Name'] ?? data['name'] ?? 'Item $code').toString();

  String? get name => (data['Name'] ?? data['name'])?.toString();

  double get sw => (data['SW'] as num?)?.toDouble() ?? 0;
  double get length => (data['Length'] as num?)?.toDouble() ?? 0;
  double get totalWeightKg => quantity * length * sw;
}