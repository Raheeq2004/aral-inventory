import 'package:aral_project/Admin/Models/item_row.dart';

/// The 3 states a saved transaction can be in.
enum SyncStatus { pending, synced, failed }

class PendingTransaction {
  const PendingTransaction({
    required this.id,
    required this.itemName,
    required this.direction, // 'IN' or 'OUT'
    required this.quantity,
    required this.location, // already formatted, e.g. "WH1 / B3 / S2"
    required this.savedAt,
    this.status = SyncStatus.pending,
    this.syncedAt,
    this.error,
    this.item,
    this.type,
  });

  final String id;
  final String itemName;
  final String direction;
  final int quantity;
  final String location;
  final DateTime savedAt;
  final SyncStatus status;
  final DateTime? syncedAt;
  final String? error; // only used when status == failed

  /// What the real send needs (TransactionData.createTransaction):
  /// the full item row and the transaction type the worker picked.
  final ItemRow? item;
  final String? type;

  PendingTransaction copyWith({
    SyncStatus? status,
    DateTime? syncedAt,
    String? error,
  }) {
    final s = status ?? this.status;
    return PendingTransaction(
      id: id,
      itemName: itemName,
      direction: direction,
      quantity: quantity,
      location: location,
      savedAt: savedAt,
      status: s,
      syncedAt: syncedAt ?? this.syncedAt,
      // the error text only lives while the row is "failed"
      error: s == SyncStatus.failed ? (error ?? this.error) : null,
      item: item,
      type: type,
    );
  }
}
