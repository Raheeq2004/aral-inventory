import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class TransactionData extends ChangeNotifier {
  List<TransactionModel> transactionDataList = [];
  bool isLoading = false;

  Future<void> getTransactions() async {
    isLoading = true;
    notifyListeners();
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref('transactions');
      DataSnapshot snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        transactionDataList.clear();

        Map<dynamic, dynamic> extractedData =
            snapshot.value as Map<dynamic, dynamic>;

        extractedData.forEach((key, value) {
          final transactionMap = Map<String, dynamic>.from(value);
          transactionDataList.add(
            TransactionModel.fromMap(transactionMap, key.toString()),
          );
        });
      } else {
        print(
          'DEBUG: Node "transactions" is empty or does not exist in Firebase.',
        );
      }
    } catch (e) {
      print('DEBUG ERROR: Failed to fetch data: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ===================================================================
  // NEW (A3): checks used before saving an edit
  // ===================================================================

  /// Reads ONE item directly by its code: items/<itemCode>.
  /// Returns the item's data (a Map) or null if no such item exists.
  /// Possible because items are now stored under their code.
  Future<Map<String, dynamic>?> findItem(String itemCode) async {
    final snap = await FirebaseDatabase.instance.ref('items/$itemCode').get();
    if (!snap.exists || snap.value == null) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }

  /// true if locations/<locationCode> exists (e.g. WH1-B3-02).
  Future<bool> locationExists(String locationCode) async {
    final snap = await FirebaseDatabase.instance
        .ref('locations/$locationCode')
        .get();
    return snap.exists;
  }

  // ===================================================================
  // NEW (A3): save an admin's edit + fix the stock
  // ===================================================================

  /// Saves the edited transaction AND adjusts the items' stock,
  /// in ONE atomic "multi-path update".
  ///
  /// Multi-path update = one `update()` on the ROOT with several paths:
  ///   { 'transactions/tx_001/quantity': 20,
  ///     'items/1BMBM010-BABY1/quantity': ServerValue.increment(-180) }
  /// Firebase applies ALL of them or NONE → the transaction and the stock
  /// can never get out of sync (e.g. if the internet drops halfway).
  ///
  /// ServerValue.increment(n) = "add n to the current value ON THE SERVER".
  /// Safe even if a worker scans the same item at the same moment.
  Future<void> updateTransaction({
    required TransactionModel original,
    required TransactionModel updated,
    required String editedBy,
  }) async {
    final id = original.transactionId!;
    final now = DateTime.now();
    final root = FirebaseDatabase.instance.ref();

    // 1) The fields of the transaction that may change.
    final Map<String, Object?> changes = {
      'transactions/$id/itemCode': updated.itemCode,
      'transactions/$id/itemName': updated.itemName,
      'transactions/$id/locationCode': updated.locationCode,
      'transactions/$id/quantity': updated.quantity,
      'transactions/$id/direction': updated.direction,
      'transactions/$id/editedBy': editedBy,
      'transactions/$id/editedAt': now.toUtc().toIso8601String(),
    };

    // 2) Stock correction.
    //    stockEffect: IN 20 → +20, OUT 20 → −20 (see the model).
    if (original.itemCode == updated.itemCode) {
      // Same item: apply only the DIFFERENCE.
      // e.g. IN 200 → IN 20 : 20 − 200 = −180
      //      IN 20  → OUT 20: −20 − 20 = −40
      final delta = updated.stockEffect - original.stockEffect;
      if (delta != 0) {
        changes['items/${updated.itemCode}/quantity'] =
            ServerValue.increment(delta);
      }
    } else {
      // Different item: undo the effect on the OLD item,
      // apply the effect on the NEW item.
      changes['items/${original.itemCode}/quantity'] =
          ServerValue.increment(-original.stockEffect);
      changes['items/${updated.itemCode}/quantity'] =
          ServerValue.increment(updated.stockEffect);
    }
    // (Changing only the LOCATION doesn't touch stock: stock is per item.)

    // 3) Send everything in one go. `await` waits for the server to confirm.
    //    If it fails, the error goes back to the page (it shows a message).
    await root.update(changes);

    // 4) Update our local list so every screen shows the new values.
    final index = transactionDataList.indexWhere(
      (t) => t.transactionId == id,
    );
    if (index != -1) {
      transactionDataList[index] = updated.copyWith(
        editedBy: editedBy,
        editedAt: now,
      );
    }
    notifyListeners(); // → the list + dashboard rebuild
  }
}