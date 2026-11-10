import 'dart:core';

import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:aral_project/Admin/Models/transaction_types.dart'; // kReversalType
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class TransactionData extends ChangeNotifier {
  List<TransactionModel> transactionDataList = [];
  bool isLoading = false;

  // Search and Filter states
  String _searchQuery = '';
  String? _selectedDate;
  DateTimeRange? _customDateRange;
  String? _selectedMovement;
  String? _selectedWarehouse;
  String? _selectedSort;

  // Getter that returns the filtered and sorted list of transactions
  List<TransactionModel> get transactions {
    var list = List<TransactionModel>.from(transactionDataList);

    // 1. Text Search Filter (matches item name, code, or worker name)
    if (_searchQuery.isNotEmpty) {
      list = list.where((tx) {
        final name = (tx.itemName).toLowerCase();
        final code = (tx.itemCode).toLowerCase();
        final worker = (tx.workerId).toLowerCase();

        return name.contains(_searchQuery) ||
            code.contains(_searchQuery) ||
            worker.contains(_searchQuery);
      }).toList();
    }

    // 2. Warehouse Filter ('WH1' or 'WH2')
    if (_selectedWarehouse != null) {
      list = list.where((tx) {
        final loc = (tx.locationCode).toUpperCase();
        return loc.startsWith(_selectedWarehouse!);
      }).toList();
    }

    // 3. Movement Filter (Robust matching for 'IN', 'OUT', or 'Reversals')
    if (_selectedMovement != null) {
      final selected = _selectedMovement!.toLowerCase();
      list = list.where((tx) {
        final direction = (tx.direction).toLowerCase();
        if (selected.contains('in')) {
          return direction == 'in' || direction.contains('received');
        } else if (selected.contains('out')) {
          return direction == 'out' || direction.contains('issued');
        }
        return direction.contains(selected);
      }).toList();
    }

    // 4. Date Filter
    // Inside TransactionData get transactions:
    // 4. Date Filter
    if (_selectedDate != null) {
      final now = DateTime.now();
      list = list.where((tx) {
        final txDate = tx.timestamp;

        if (_selectedDate == 'Today') {
          return txDate.year == now.year &&
              txDate.month == now.month &&
              txDate.day == now.day;
        } else if (_selectedDate == 'Yesterday') {
          final yesterday = now.subtract(const Duration(days: 1));
          return txDate.year == yesterday.year &&
              txDate.month == yesterday.month &&
              txDate.day == yesterday.day;
        } else if (_selectedDate == 'Last 7 days') {
          final difference = now.difference(txDate).inDays;
          return difference >= 0 && difference <= 7;
        } else if (_selectedDate == 'This month') {
          return txDate.year == now.year && txDate.month == now.month;
        } else if (_customDateRange != null) {
          // Proper custom range evaluation (ignoring time discrepancies)
          final startDate = DateTime(
            _customDateRange!.start.year,
            _customDateRange!.start.month,
            _customDateRange!.start.day,
          );
          final endDate = DateTime(
            _customDateRange!.end.year,
            _customDateRange!.end.month,
            _customDateRange!.end.day,
            23,
            59,
            59,
          );
          return txDate.isAfter(
                startDate.subtract(const Duration(seconds: 1)),
              ) &&
              txDate.isBefore(endDate.add(const Duration(seconds: 1)));
        }
        return true;
      }).toList();
    }
    // 5. Sorting
    if (_selectedSort != null) {
      if (_selectedSort == 'Newest first') {
        list.sort((a, b) => (b.timestamp).compareTo(a.timestamp));
      } else if (_selectedSort == 'Oldest first') {
        list.sort((a, b) => (a.timestamp).compareTo(b.timestamp));
      } else if (_selectedSort == 'Largest quantity') {
        list.sort((a, b) => b.quantity.compareTo(a.quantity));
      }
    }

    return list;
  }

  // Setters called by the search bar and filter bottom sheet
  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase().trim();
    notifyListeners();
  }

  void setFilters({
    String? date,
    DateTimeRange? customDateRange,
    String? movement, // FIX: the IN/OUT filter was never passed in
    String? warehouse,
    String? sort,
  }) {
    _selectedDate = date;
    _customDateRange = customDateRange;
    _selectedMovement = movement;
    _selectedWarehouse = warehouse;
    _selectedSort = sort;
    notifyListeners();
  }

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
      'transactions/$id/type': updated.type, // NEW: type code (e.g. 'issue_out')
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
        changes['items/${updated.itemCode}/quantity'] = ServerValue.increment(
          delta,
        );
      }
    } else {
      // Different item: undo the effect on the OLD item,
      // apply the effect on the NEW item.
      changes['items/${original.itemCode}/quantity'] = ServerValue.increment(
        -original.stockEffect,
      );
      changes['items/${updated.itemCode}/quantity'] = ServerValue.increment(
        updated.stockEffect,
      );
    }
    // (Changing only the LOCATION doesn't touch stock: stock is per item.)

    // 3) Send everything in one go. `await` waits for the server to confirm.
    //    If it fails, the error goes back to the page (it shows a message).
    await root.update(changes);

    // 4) Update our local list so every screen shows the new values.
    final index = transactionDataList.indexWhere((t) => t.transactionId == id);
    if (index != -1) {
      transactionDataList[index] = updated.copyWith(
        editedBy: editedBy,
        editedAt: now,
      );
    }
    notifyListeners(); // → the list + dashboard rebuild
  }

  // ===================================================================
  // NEW (A4): reverse a transaction (undo it WITHOUT deleting it)
  // ===================================================================

  /// Reverses [original]:
  ///   1) ADDS a new opposite transaction (IN ↔ OUT, same item/qty/location,
  ///      type "reversal", reversalOf = the original's id)
  ///   2) MARKS the original: reversed = true, reversedBy, reversedAt, reversalId
  ///   3) FIXES the stock: undoes the original's effect on the item
  /// All 3 in ONE atomic multi-path update (all or nothing).
  ///
  /// Returns the new reversal's id.
  Future<String> reverseTransaction({
    required TransactionModel original,
    required String reversedBy,
  }) async {
    // Safety: never reverse twice, never reverse a reversal.
    if (original.reversed || original.isReversal) {
      throw StateError('This transaction cannot be reversed');
    }

    final id = original.transactionId!;
    final now = DateTime.now();
    final root = FirebaseDatabase.instance.ref();

    // push() creates a NEW unique id under "transactions" (like "-Oa8x…"),
    // without writing anything yet. `.key` gives us that id.
    final newId = root.child('transactions').push().key!;

    // The opposite transaction.
    final reversal = TransactionModel(
      transactionId: newId,
      itemCode: original.itemCode,
      itemName: original.itemName,
      locationCode: original.locationCode,
      quantity: original.quantity, // same amount…
      direction: original.oppositeDirection, // …opposite direction
      type: kReversalType.code, // 'reversal' (shown as "عكس عملية")
      workerId: reversedBy, // the admin who reversed it
      timestamp: now,
      reversalOf: id, // link back to the original
    );

    final Map<String, Object?> changes = {
      // 1) the new transaction (toJson = the model as a Map)
      'transactions/$newId': reversal.toJson(),
      // 2) mark the original (it stays in the log)
      'transactions/$id/reversed': true,
      'transactions/$id/reversedBy': reversedBy,
      'transactions/$id/reversedAt': now.toUtc().toIso8601String(),
      'transactions/$id/reversalId': newId,
      // 3) stock: the reversal's effect = the opposite of the original's
      //    (IN 20 → −20 · OUT 20 → +20)
      'items/${original.itemCode}/quantity': ServerValue.increment(
        reversal.stockEffect,
      ),
    };

    await root.update(changes); // waits for the server to confirm

    // Update the local list → every screen refreshes.
    final index = transactionDataList.indexWhere((t) => t.transactionId == id);
    if (index != -1) {
      transactionDataList[index] = original.copyWith(
        reversed: true,
        reversedBy: reversedBy,
        reversedAt: now,
        reversalId: newId,
      );
    }
    transactionDataList.insert(0, reversal); // new row at the top
    notifyListeners();
    return newId;
  }
}