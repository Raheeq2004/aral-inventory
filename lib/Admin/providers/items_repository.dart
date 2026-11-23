import 'package:aral_project/Admin/Models/item_row.dart';
import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:firebase_database/firebase_database.dart';

class ItemsRepository {
  final DatabaseReference _itemsRef = FirebaseDatabase.instance.ref('items');

  // WHOLE TABLE (used by the Reports page)
  List<ItemRow>? _cache;
  List<ItemRow>? get cachedAll => _cache;

  /// Reads the WHOLE `items` table (ONE read) and keeps it in [cachedAll].
  /// Always goes to Firebase, because `Stock` changes all the time.
  Future<List<ItemRow>> loadAll() async {
    final snap = await _itemsRef.get();
    final rows = <ItemRow>[];

    void add(String key, Object? value) {
      if (value is Map) {
        rows.add(ItemRow(key: key, data: Map<String, dynamic>.from(value)));
      }
    }

    if (snap.exists && snap.value != null) {
      // Firebase returns a List when keys are 0,1,2... and a Map otherwise
      // (a List can contain nulls where a row was deleted).
      final raw = snap.value;
      if (raw is Map) {
        raw.forEach((k, v) => add('$k', v));
      } else if (raw is List) {
        for (var i = 0; i < raw.length; i++) {
          add('$i', raw[i]);
        }
      }
    }
    return _cache = rows;
  }

  /// Reads the item with [itemId] directly: items/<itemId - 1>, falling back to an indexed query.
  Future<ItemRow?> itemById(int itemId) async {
    final key = '${itemId - 1}';
    final snap = await _itemsRef.child(key).get();
    if (snap.exists && snap.value is Map) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      if ((data['id'] as num?)?.toInt() == itemId) {
        return ItemRow(key: key, data: data);
      }
    }

    final found = await _itemsRef
        .orderByChild('id')
        .equalTo(itemId)
        .limitToFirst(1)
        .get();
    if (!found.exists || found.children.isEmpty) return null;

    final child = found.children.first;
    return ItemRow(
      key: child.key!,
      data: Map<String, dynamic>.from(child.value as Map),
    );
  }

  /// ALL rows of [itemCode] (one row per LENGTH) — used by the keeper's QR scan.
  ///
  /// The QR label holds only the item code, and the same code can exist at
  /// several lengths (e.g. 1BMBM010-AR801 at 5 m, 6 m and 7 m). So we return
  /// every matching row and let the scanner decide:
  ///   0 rows → not found · 1 row → done · 2+ rows → ask "which length?"
  /// Indexed search (".indexOn": ["Item Code"]) → only the matches are sent.
  Future<List<ItemRow>> findAllByCode(String itemCode) async {
    final snap = await _itemsRef
        .orderByChild('Item Code')
        .equalTo(itemCode)
        .get();
    if (!snap.exists) return const [];
    return [
      for (final child in snap.children)
        if (child.value is Map)
          ItemRow(
            key: child.key!,
            data: Map<String, dynamic>.from(child.value as Map),
          ),
    ];
  }

  /// Finds the row matching [itemCode] and [length] (used for QR scans & legacy transactions).
  Future<ItemRow?> findItem(String itemCode, double length) async {
    final snap = await _itemsRef
        .orderByChild('Item Code')
        .equalTo(itemCode)
        .get();
    if (!snap.exists) return null;

    final rows = snap.children.toList();

    for (final child in rows) {
      final data = Map<String, dynamic>.from(child.value as Map);
      final rowLength = (data['Length'] as num?)?.toDouble();
      if (rowLength != null && (rowLength - length).abs() < 0.001) {
        return ItemRow(key: child.key!, data: data);
      }
    }

    if (length <= 0 && rows.length == 1) {
      final only = rows.first;
      return ItemRow(
        key: only.key!,
        data: Map<String, dynamic>.from(only.value as Map),
      );
    }
    return null;
  }

  /// Resolves the item row for a given [tx] (by itemId first, otherwise code + length).
  Future<ItemRow?> itemFor(TransactionModel tx) {
    if (tx.itemId != null) return itemById(tx.itemId!);
    return findItem(tx.itemCode, tx.length);
  }

  /// Same as [itemFor], but throws if the item row does not exist.
  Future<ItemRow> requireItem(TransactionModel tx) async {
    final row = await itemFor(tx);
    if (row == null) {
      throw StateError('Item ${tx.itemId ?? tx.itemCode} not found');
    }
    return row;
  }
}