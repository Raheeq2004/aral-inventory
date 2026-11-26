/// The 3 states a saved transaction can be in.
enum SyncStatus { pending, synced, failed }

/// One row on the Pending sync page.
/// Small on purpose: it only holds what the page SHOWS. The real
/// transaction (item id, location, createdBy …) stays in the offline queue.
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
    );
  }
}
