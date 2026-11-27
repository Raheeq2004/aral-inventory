String? validateTransactionQuantity(
  String? rawValue, {
  required String direction,
  int? availableStock,
  bool enforceStockLimit = true,
}) {
  final trimmed = (rawValue ?? '').trim();
  if (trimmed.isEmpty) return 'Enter quantity';

  final qty = int.tryParse(trimmed);
  if (qty == null || qty <= 0) return 'Must be greater than 0';

  if (enforceStockLimit &&
      direction == 'OUT' &&
      availableStock != null &&
      qty > availableStock) {
    return 'Exceeds available stock ($availableStock pcs)';
  }

  return null;
}
