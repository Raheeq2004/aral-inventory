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
  double? _selectedLength;
  String? _selectedSort;

  // Getter that returns the filtered and sorted list of transactions
  List<TransactionModel> get transactions {
    var list = List<TransactionModel>.from(transactionDataList);

    // 1. Text Search Filter (matches item name, code, or worker name)
    if (_searchQuery.isNotEmpty) {
      list = list.where((tx) {
        final name = (tx.itemName).toLowerCase();
        final code = (tx.itemCode).toLowerCase();
        final worker = (tx.stockKeeperId).toLowerCase();

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
    // 5. Length Filter (NEW)
    if (_selectedLength != null) {
      list = list.where((tx) => tx.length == _selectedLength).toList();
    }
    // 6. Sorting
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
    double? length,
  }) {
    _selectedDate = date;
    _customDateRange = customDateRange;
    _selectedMovement = movement;
    _selectedWarehouse = warehouse;
    _selectedSort = sort;
    _selectedLength = length;
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
  // LOOKUPS (items + locations) — uses the Firebase INDEX
  // ===================================================================
  //
  // How the data is stored now (Joud's structure):
  //   items/0, items/1, items/2 …   → one row = one item AT ONE LENGTH
  //       { "Item Code": "1BMBM010-1008T", "Length": 6.3, "Quantity": 184, … }
  //   Warehouse1/0, Warehouse1/1 …  → { "Location Code": "WH1-A1-02", … }
  //   Warehouse2/…                  → same, for WH2
  //
  // To find a row we SEARCH by a field:
  //   ref('items').orderByChild('Item Code').equalTo(code)
  //   • orderByChild('Item Code') = "sort / search by this field"
  //   • equalTo(code)             = "keep only rows where it equals code"
  // With the rule  "items": { ".indexOn": ["Item Code"] }  in Firebase,
  // the SERVER uses its index and sends back ONLY the matching rows
  // (fast, O(log n)). Without the rule it would send the whole list.

  /// Finds the row of [itemCode] with this [length].
  /// Returns an [ItemRow] (its key, e.g. "2", + its data) or null.
  ///
  /// Why code AND length? The same code can exist in several rows with
  /// different lengths, and each length has its OWN stock.
  Future<ItemRow?> findItem(String itemCode, double length) async {
    final snap = await FirebaseDatabase.instance
        .ref('items')
        .orderByChild('Item Code')
        .equalTo(itemCode)
        .get();
    if (!snap.exists) return null; // no row with this code at all

    // snap.children = the matching rows (usually 1–3, one per length).
    // Each child has a `key` (the row number, e.g. "2") and a `value`.
    final rows = snap.children.toList();

    for (final child in rows) {
      final data = Map<String, dynamic>.from(child.value as Map);
      final rowLength = (data['Length'] as num?)?.toDouble();
      // Compare decimals with a tiny tolerance: 6.3 can be stored as
      // 6.2999999… in a computer, so we never use == on doubles.
      if (rowLength != null && (rowLength - length).abs() < 0.001) {
        return ItemRow(key: child.key!, data: data);
      }
    }

    // Old transactions may have no length (0). If the code has exactly
    // ONE row, there's no doubt which one it is → use it.
    if (length <= 0 && rows.length == 1) {
      final only = rows.first;
      return ItemRow(
        key: only.key!,
        data: Map<String, dynamic>.from(only.value as Map),
      );
    }
    return null; // the code exists, but not in this length
  }

  /// true if [locationCode] (e.g. "WH1-A1-02") exists.
  /// The number after "WH" tells us which node to search:
  /// WH1 → Warehouse1, WH2 → Warehouse2 (and WH3 → Warehouse3 later).
  Future<bool> locationExists(String locationCode) async {
    // RegExp: "WH" + digits at the START of the text → group(1) = the digits
    final match = RegExp(r'^WH(\d+)-').firstMatch(locationCode);
    if (match == null) return false; // not a valid location code
    final node = 'Warehouse${match.group(1)}';

    final snap = await FirebaseDatabase.instance
        .ref(node)
        .orderByChild('Location Code')
        .equalTo(locationCode)
        .limitToFirst(1) // we only need to know if ONE exists
        .get();
    return snap.exists;
  }

  /// Same as [findItem], but throws if the row is missing.
  /// Used when saving: we can't fix stock for an item we can't find.
  Future<ItemRow> _requireItem(String itemCode, double length) async {
    final row = await findItem(itemCode, length);
    if (row == null) {
      throw StateError('Item $itemCode (length $length) not found');
    }
    return row;
  }

  // ===================================================================
  // NEW (A3): save an admin's edit + fix the stock
  // ===================================================================

  /// Saves the edited transaction AND adjusts the items' stock,
  /// in ONE atomic "multi-path update".
  ///
  /// Multi-path update = one `update()` on the ROOT with several paths:
  ///   { 'transactions/tx_001/quantity': 20,
  ///     'items/2/Quantity': ServerValue.increment(-180) }
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
      'transactions/$id/type':
          updated.type, // NEW: type code (e.g. 'issue_out')
      'transactions/$id/editedBy': editedBy,
      'transactions/$id/editedAt': now.toUtc().toIso8601String(),
    };

    // 2) Stock correction.
    //    stockEffect: IN 20 → +20, OUT 20 → −20 (see the model).
    //    The stock lives in items/<row>/Quantity, so first we FIND the row
    //    (item code + length) with the indexed search.
    final oldRow = await _requireItem(original.itemCode, original.length);
    final newRow = await _requireItem(updated.itemCode, updated.length);

    if (oldRow.key == newRow.key) {
      // Same row (same item, same length): apply only the DIFFERENCE.
      // e.g. IN 200 → IN 20 : 20 − 200 = −180
      //      IN 20  → OUT 20: −20 − 20 = −40
      final delta = updated.stockEffect - original.stockEffect;
      if (delta != 0) {
        changes['items/${newRow.key}/Quantity'] = ServerValue.increment(delta);
      }
    } else {
      // Different row: undo the effect on the OLD row,
      // apply the effect on the NEW row.
      changes['items/${oldRow.key}/Quantity'] = ServerValue.increment(
        -original.stockEffect,
      );
      changes['items/${newRow.key}/Quantity'] = ServerValue.increment(
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
      stockKeeperId: reversedBy, // the admin who reversed it
      timestamp: now,
      reversalOf: id,
      numericId: original.numericId,
      uomCode: original.uomCode,
      color: original.color,
      length: original.length,
      sw: original.sw,
      totalWeight: original.totalWeight,
      warehouse: original.warehouse,
      rack: original.rack,
      shelfNo: original.shelfNo,
      stock: original.stock, // link back to the original
    );

    // Find the item's row (code + length) BEFORE writing anything.
    final row = await _requireItem(original.itemCode, original.length);

    final Map<String, Object?> changes = {
      // 1) the new transaction (toJson = the model as a Map)
      'transactions/$newId': reversal.toJson(),
      // 2) mark the original (it stays in the log)
      'transactions/$id/reversed': true,
      'transactions/$id/reversedBy': reversedBy,
      'transactions/$id/reversedAt': now.toUtc().toIso8601String(),
      'transactions/$id/reversalId': newId,
      // 3) stock: the reversal's effect = the opposite of the original's
      //    (IN 20 → −20 · OUT 20 → +20), on the item's row.
      'items/${row.key}/Quantity': ServerValue.increment(reversal.stockEffect),
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

/// One row of the `items` list: its KEY (position, e.g. "2") + its data.
/// We need the key to write the stock: items/<key>/Quantity.
class ItemRow {
  const ItemRow({required this.key, required this.data});

  final String key;
  final Map<String, dynamic> data;

  /// The real, current stock of this item (at this length).
  int get quantity => (data['Quantity'] as num?)?.toInt() ?? 0;

  /// The item's name, if the row has one (fallback: "Item <code>").
  String nameOr(String code) =>
      (data['Name'] ?? data['name'] ?? 'Item $code').toString();

  /// The name stored in the row, or null if the row has no name field
  /// (Joud's current import has no "Name" column yet).
  String? get name => (data['Name'] ?? data['name'])?.toString();

  /// SW = specific weight: kilograms per METRE of this profile.
  double get sw => (data['SW'] as num?)?.toDouble() ?? 0;

  /// Bar length in metres.
  double get length => (data['Length'] as num?)?.toDouble() ?? 0;

  /// Total weight of ALL pieces in stock, in kg, CALCULATED from the live
  /// stock: pieces × metres per piece × kg per metre.
  /// (We calculate it instead of trusting the stored "Total Weight",
  ///  which doesn't change when the stock changes.)
  double get totalWeightKg => quantity * length * sw;
}