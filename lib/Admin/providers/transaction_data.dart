import 'dart:core';

import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:aral_project/Admin/Models/transaction_types.dart'; // kReversalType
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class InsufficientStockException implements Exception {
  const InsufficientStockException(this.message);

  final String message;

  @override
  String toString() => message;
}

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
        // NEW DB: transactions only have `itemId` → fill in the item's
        // code, length, SW … from the `items` table (see below).
        await _attachItemDetails();
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
  // LOOKUPS (items + locations)
  // ===================================================================
  //
  // How the data is stored now (Joud's NEW structure):
  //   items/0, items/1, items/2 …   → one row = one item AT ONE LENGTH
  //       { "id": 1, "Item Code": "1BMBM010-1008T", "Length": 6.3,
  //         "Stock": 184, "SW": 0.79, … }
  //   locations/0, locations/1 …    → { "Location Code": "WH1-A1-02",
  //                                     "Warehouse": "WH1", "Rack": "A1", … }
  //   transactions/tx_001           → { "itemId": 2700, "createdBy": …,
  //                                     "locationCode": …, "quantity": … }
  //
  // ---- 1) By itemId: DIRECT read, no search → O(1) ----
  //   The row number is itemId − 1 (items/0 has id 1), so we read
  //   ref('items/2699') straight away. It also always gets the EXACT row,
  //   even for the 33 items that appear twice with the same code + length.
  //
  // ---- 2) By code (QR scan): indexed SEARCH → O(log n) ----
  // To find a row we SEARCH by a field:
  //   ref('items').orderByChild('Item Code').equalTo(code)
  //   • orderByChild('Item Code') = "sort / search by this field"
  //   • equalTo(code)             = "keep only rows where it equals code"
  // With the rule  "items": { ".indexOn": ["Item Code"] }  in Firebase,
  // the SERVER uses its index and sends back ONLY the matching rows
  // (fast, O(log n)). Without the rule it would send the whole list.

  /// The name of the stock field in `items` (Joud renamed Quantity → Stock).
  /// One constant → if it's renamed again, we change ONE line.
  static const String stockField = 'Stock';

  /// Reads the item with this [itemId] DIRECTLY: items/<itemId − 1>.
  /// Always fresh from Firebase (used for the live stock on the detail page).
  Future<ItemRow?> itemById(int itemId) async {
    final key = '${itemId - 1}'; // id 2700 → row "2699"
    final snap = await FirebaseDatabase.instance.ref('items/$key').get();
    if (snap.exists && snap.value is Map) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      // Safety check: is it really the right row? (`id` must match)
      if ((data['id'] as num?)?.toInt() == itemId) {
        return ItemRow(key: key, data: data);
      }
    }
    // The rows were re-imported in another order → search by the `id`
    // field instead (needs ".indexOn": ["Item Code", "id"] in the rules).
    final found = await FirebaseDatabase.instance
        .ref('items')
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

  /// After loading the transactions: read each USED item once and copy its
  /// code / length / SW / colour into the transactions, so the list, the
  /// dashboard, search and Reports keep working without other changes.
  ///
  /// 50 transactions use ~50 items → ~50 small direct reads, NOT the whole
  /// items table (3,065 rows).
  Future<void> _attachItemDetails() async {
    // toSet() removes repeats: 3 transactions on item 39 → read it once.
    final ids = transactionDataList
        .map((t) => t.itemId)
        .whereType<int>() // drop nulls (old data without itemId)
        .toSet();

    // Future.wait = start ALL the reads at the same time, then wait for
    // all of them → much faster than one after the other.
    final rows = await Future.wait(
      ids.map((id) async {
        try {
          return MapEntry<int, ItemRow?>(id, await itemById(id));
        } catch (_) {
          return MapEntry<int, ItemRow?>(id, null); // one failed read doesn't stop the rest
        }
      }),
    );
    final byId = Map<int, ItemRow?>.fromEntries(rows);

    // Replace each transaction with a copy that has the item's details.
    transactionDataList = transactionDataList.map((t) {
      final row = t.itemId == null ? null : byId[t.itemId];
      if (row == null) return t; // not found → leave it as it is
      return t.copyWith(
        itemCode: row.code,
        length: row.length,
        sw: row.sw,
        color: row.color,
        uomCode: row.uomCode,
      );
    }).toList();
  }

  /// The item row of a transaction: by itemId when we have it (new data),
  /// otherwise by code + length (old data).
  Future<ItemRow?> itemFor(TransactionModel tx) {
    if (tx.itemId != null) return itemById(tx.itemId!);
    return findItem(tx.itemCode, tx.length);
  }

  /// Finds the row of [itemCode] with this [length] (used for QR scans).
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
  /// All warehouses are now in ONE table: `locations` (Joud's new
  /// structure replaced Warehouse1 / Warehouse2). Indexed search, so it
  /// needs  "locations": { ".indexOn": ["Location Code"] }  in the rules.
  Future<bool> locationExists(String locationCode) async {
    final snap = await FirebaseDatabase.instance
        .ref('locations')
        .orderByChild('Location Code')
        .equalTo(locationCode)
        .limitToFirst(1) // we only need to know if ONE exists
        .get();
    return snap.exists;
  }

  /// Same as [itemFor], but throws if the row is missing.
  /// Used when saving: we can't fix stock for an item we can't find.
  Future<ItemRow> _requireItem(TransactionModel tx) async {
    final row = await itemFor(tx);
    if (row == null) {
      throw StateError('Item ${tx.itemId ?? tx.itemCode} not found');
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
  ///     'items/2/Stock': ServerValue.increment(-180) }
  /// Firebase applies ALL of them or NONE → the transaction and the stock
  /// can never get out of sync (e.g. if the internet drops halfway).
  ///
  /// ServerValue.increment(n) = "add n to the current value ON THE SERVER".
  /// Safe even if a worker scans the same item at the same moment.
  ///
  /// (No editedBy: only the admin can edit, so we only save WHEN — editedAt.)
  Future<void> updateTransaction({
    required TransactionModel original,
    required TransactionModel updated,
  }) async {
    final id = original.transactionId!;
    final now = DateTime.now();
    final root = FirebaseDatabase.instance.ref();

    // 1) The fields of the transaction that may change.
    final Map<String, Object?> changes = {
      // (The item can't change — product is locked — so we don't write it.)
      'transactions/$id/locationCode': updated.locationCode,
      'transactions/$id/quantity': updated.quantity,
      'transactions/$id/direction': updated.direction,
      'transactions/$id/type':
          updated.type, // NEW: type code (e.g. 'issue_out')
      'transactions/$id/editedAt': now.toUtc().toIso8601String(),
    };

    // 2) Stock correction.
    //    stockEffect: IN 20 → +20, OUT 20 → −20 (see the model).
    //    The stock lives in items/<row>/Stock. We get the row DIRECTLY
    //    from the transaction's itemId (items/<itemId − 1>).
    final oldRow = await _requireItem(original);
    final newRow = await _requireItem(updated);

    if (oldRow.key == newRow.key) {
      // Same row (same item, same length): apply only the DIFFERENCE.
      // e.g. IN 200 → IN 20 : 20 − 200 = −180
      //      IN 20  → OUT 20: −20 − 20 = −40
      final delta = updated.stockEffect - original.stockEffect;
      if (delta != 0) {
        final resultingQuantity = newRow.quantity + delta;
        if (resultingQuantity < 0) {
          throw InsufficientStockException(
            'Insufficient stock for ${updated.itemCode}. '
            'Available: ${newRow.quantity}, required: ${-delta}',
          );
        }
        changes['items/${newRow.key}/$stockField'] = ServerValue.increment(
          delta,
        );
      }
    } else {
      // Different row: undo the effect on the OLD row,
      // apply the effect on the NEW row.
      final oldResult = oldRow.quantity - original.stockEffect;
      if (oldResult < 0) {
        throw InsufficientStockException(
          'Insufficient stock for ${original.itemCode}. '
          'Available: ${oldRow.quantity}, required: ${original.stockEffect}',
        );
      }
      final newResult = newRow.quantity + updated.stockEffect;
      if (newResult < 0) {
        throw InsufficientStockException(
          'Insufficient stock for ${updated.itemCode}. '
          'Available: ${newRow.quantity}, required: ${-updated.stockEffect}',
        );
      }
      changes['items/${oldRow.key}/$stockField'] = ServerValue.increment(
        -original.stockEffect,
      );
      changes['items/${newRow.key}/$stockField'] = ServerValue.increment(
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
      transactionDataList[index] = updated.copyWith(editedAt: now);
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

    // The new id follows Joud's format: tx_001, tx_002 … → the next number.
    final newId = await _nextTransactionId();

    // The opposite transaction.
    final reversal = TransactionModel(
      transactionId: newId,
      itemId: original.itemId, // same item (saved as itemId in Firebase)
      itemCode: original.itemCode,
      itemName: original.itemName,
      locationCode: original.locationCode,
      quantity: original.quantity, // same amount…
      direction: original.oppositeDirection, // …opposite direction
      type: kReversalType.code, // 'reversal' (shown as "عكس عملية")
      stockKeeperId: reversedBy, // the admin who reversed it
      timestamp: now,
      reversalOf: id,
      numericId: int.parse(newId.substring(3)), // "tx_051" → 51
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

    // Find the item's row (by itemId) BEFORE writing anything.
    final row = await _requireItem(original);
    final resultingQuantity = row.quantity + reversal.stockEffect;
    if (resultingQuantity < 0) {
      throw InsufficientStockException(
        'Insufficient stock for ${original.itemCode}. '
        'Available: ${row.quantity}, required: ${original.quantity}',
      );
    }

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
      'items/${row.key}/$stockField': ServerValue.increment(
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

  /// The next free id in Joud's format: if the biggest is tx_050 → "tx_051".
  ///
  /// padLeft(3, '0'): 51 → "051" (always 3 digits, so ids sort correctly).
  /// We also CHECK Firebase that the id is free, in case another device
  /// added a transaction after we loaded the list (then we try the next).
  Future<String> _nextTransactionId() async {
    // fold = walk the list keeping the biggest number seen so far.
    var next = transactionDataList.fold<int>(
          0,
          (biggest, t) => t.numericId > biggest ? t.numericId : biggest,
        ) +
        1;
    while (true) {
      final id = 'tx_${next.toString().padLeft(3, '0')}';
      final snap = await FirebaseDatabase.instance.ref('transactions/$id').get();
      if (!snap.exists) return id; // free → use it
      next++; // taken → try the next number
    }
  }
}

/// One row of the `items` list: its KEY (position, e.g. "2") + its data.
/// We need the key to write the stock: items/<key>/Stock.
class ItemRow {
  const ItemRow({required this.key, required this.data});

  final String key;
  final Map<String, dynamic> data;

  /// The real, current stock of this item (at this length).
  /// (New field name `Stock`; `Quantity` is the old name, just in case.)
  int get quantity =>
      ((data[TransactionData.stockField] ?? data['Quantity']) as num?)
          ?.toInt() ??
      0;

  /// The item code, e.g. "2MFMF-BT128".
  String get code => (data['Item Code'] ?? '').toString();

  /// Colour / finish code from the Excel (e.g. "ANOD", "MF").
  String get color => (data['COLOR'] ?? '').toString();

  /// Unit, e.g. "NOS" (= pieces).
  String get uomCode => (data['UOM Code'] ?? '').toString();

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