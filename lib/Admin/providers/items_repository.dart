import 'package:aral_project/Admin/Models/item_row.dart';
import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:firebase_database/firebase_database.dart';

class ItemsRepository {
  final DatabaseReference _itemsRef = FirebaseDatabase.instance.ref('items');

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
