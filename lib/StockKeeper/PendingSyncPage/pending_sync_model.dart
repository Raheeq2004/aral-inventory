import 'package:flutter/foundation.dart';

// =====================================================================
// ARAL Inventory – Pending sync (worker side)
// =====================================================================
// This file = the DATA + LOGIC behind the Pending sync page.
// The page (pending_sync_page.dart) only DRAWS what is in here.
//
// For now it runs on DEMO data so the UI can be tested alone.
// Everything the team must connect later is marked:  // TODO(integrate)
// =====================================================================

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

/// Holds the list + runs the sync. Used with `provider`:
///   context.watch<PendingSyncController>()  → rebuilds the page
///   context.read<PendingSyncController>()    → call a method (no rebuild)
class PendingSyncController extends ChangeNotifier {
  PendingSyncController([List<PendingTransaction> items = const []])
    : _items = List.of(items);

  /// DEMO data = the same 5 rows as the Figma mock-up.
  /// TODO(integrate): delete this factory once the real queue is connected.
  factory PendingSyncController.demo() {
    final now = DateTime.now();
    DateTime at(int h, int m) => DateTime(now.year, now.month, now.day, h, m);
    return PendingSyncController([
      PendingTransaction(
        id: 'd1',
        itemName: 'Aluminum Profile 6063-T5',
        direction: 'IN',
        quantity: 20,
        location: 'WH1 / B3 / S2',
        savedAt: at(10, 42),
      ),
      PendingTransaction(
        id: 'd2',
        itemName: 'Aluminum Sheet 1050 – 2mm',
        direction: 'OUT',
        quantity: 6,
        location: 'WH1 / A1 / S4',
        savedAt: at(10, 42),
      ),
      PendingTransaction(
        id: 'd3',
        itemName: 'Window Frame Profile 45mm',
        direction: 'IN',
        quantity: 40,
        location: 'WH2 / C2 / S1',
        savedAt: at(10, 30),
        status: SyncStatus.synced,
        syncedAt: at(10, 58),
      ),
      PendingTransaction(
        id: 'd4',
        itemName: 'Door Handle Set – Black',
        direction: 'OUT',
        quantity: 12,
        location: 'WH1 / D4 / S3',
        savedAt: at(10, 20),
        status: SyncStatus.synced,
        syncedAt: at(10, 58),
      ),
      PendingTransaction(
        id: 'd5',
        itemName: 'Aluminum Profile 6060-T6',
        direction: 'OUT',
        quantity: 30,
        location: 'WH1 / B1 / S1',
        savedAt: at(10, 10),
        status: SyncStatus.failed,
        error: 'Could not reach the server',
      ),
    ]);
  }

  final List<PendingTransaction> _items;
  bool _isOnline = true;
  bool _isSyncing = false;
  int _syncDone = 0;
  int _syncTotal = 0;

  // ---------------- what the page reads ----------------
  List<PendingTransaction> get items => List.unmodifiable(_items);
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get syncDone => _syncDone; // the "2" in "2 of 3"
  int get syncTotal => _syncTotal; // the "3" in "2 of 3"

  /// Rows still waiting to be sent (the number in "2 transactions waiting").
  int get waitingCount =>
      _items.where((t) => t.status == SyncStatus.pending).length;

  // ---------------- what other pages / services call ----------------

  /// Call after a worker saves a transaction (quantity page → Save).
  /// TODO(integrate): the real save flow should write to the local queue
  /// FIRST, then call this so the page shows the new row.
  void add(PendingTransaction t) {
    _items.insert(0, t);
    notifyListeners();
  }

  /// Call from the connectivity stream (see the notes in the handoff).
  /// Going back online starts the sync by itself.
  void setOnline(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    notifyListeners();
    if (online && waitingCount > 0) syncAll();
  }

  /// "Sync now" button.
  Future<void> syncAll() => _sync(
    _items
        .where((t) => t.status == SyncStatus.pending)
        .map((t) => t.id)
        .toList(),
  );

  /// Tap on a "Sync failed" row.
  Future<void> retry(String id) async {
    _replace(id, (t) => t.copyWith(status: SyncStatus.pending));
    notifyListeners();
    await _sync([id]);
  }

  // ---------------- internals ----------------

  Future<void> _sync(List<String> ids) async {
    if (_isSyncing || !_isOnline || ids.isEmpty) return;
    _isSyncing = true;
    _syncDone = 0;
    _syncTotal = ids.length;
    notifyListeners();

    for (final id in ids) {
      final result = await _pushToServer(id);
      _replace(
        id,
        (t) => result == null
            ? t.copyWith(status: SyncStatus.synced, syncedAt: DateTime.now())
            : t.copyWith(status: SyncStatus.failed, error: result),
      );
      _syncDone++;
      notifyListeners();
    }

    _isSyncing = false;
    notifyListeners();
  }

  /// Sends ONE transaction to Firebase.
  /// Returns null on success, or an error message on failure.
  ///
  /// TODO(integrate): replace the fake delay with the real write, e.g.
  ///   try {
  ///     await transactionsRepository.push(queueItemFor(id));
  ///     return null;
  ///   } catch (e) {
  ///     return e.toString();
  ///   }
  Future<String?> _pushToServer(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return null; // demo: always succeeds
  }

  void _replace(
    String id,
    PendingTransaction Function(PendingTransaction) change,
  ) {
    final i = _items.indexWhere((t) => t.id == id);
    if (i != -1) _items[i] = change(_items[i]);
  }
}
