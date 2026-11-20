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
    String? movement,
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

  static const String stockField = 'Stock';

  Future<ItemRow?> itemById(int itemId) async {
    final key = '${itemId - 1}';
    final snap = await FirebaseDatabase.instance.ref('items/$key').get();
    if (snap.exists && snap.value is Map) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      if ((data['id'] as num?)?.toInt() == itemId) {
        return ItemRow(key: key, data: data);
      }
    }
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

  Future<void> _attachItemDetails() async {
    final ids = transactionDataList
        .map((t) => t.itemId)
        .whereType<int>()
        .toSet();

    final rows = await Future.wait(
      ids.map((id) async {
        try {
          return MapEntry<int, ItemRow?>(id, await itemById(id));
        } catch (_) {
          return MapEntry<int, ItemRow?>(id, null);
        }
      }),
    );
    final byId = Map<int, ItemRow?>.fromEntries(rows);

    transactionDataList = transactionDataList.map((t) {
      final row = t.itemId == null ? null : byId[t.itemId];
      if (row == null) return t;
      return t.copyWith(
        itemCode: row.code,
        length: row.length,
        sw: row.sw,
        color: row.color,
        uomCode: row.uomCode,
        stock: row.quantity,
      );
    }).toList();
  }

  void _syncItemStockInList({required int? itemId, required int newStock}) {
    if (itemId == null) return;
    transactionDataList = transactionDataList.map((t) {
      return t.itemId == itemId ? t.copyWith(stock: newStock) : t;
    }).toList();
  }

  void _ensureSufficientStock({
    required int resultingQuantity,
    required String itemCode,
    required int available,
    required int required,
  }) {
    if (resultingQuantity < 0) {
      throw InsufficientStockException(
        'Insufficient stock for $itemCode. '
        'Available: $available, required: $required',
      );
    }
  }

  Future<ItemRow?> itemFor(TransactionModel tx) {
    if (tx.itemId != null) return itemById(tx.itemId!);
    return findItem(tx.itemCode, tx.length);
  }

  Future<ItemRow?> findItem(String itemCode, double length) async {
    final snap = await FirebaseDatabase.instance
        .ref('items')
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

  Future<bool> locationExists(String locationCode) async {
    final snap = await FirebaseDatabase.instance
        .ref('locations')
        .orderByChild('Location Code')
        .equalTo(locationCode)
        .limitToFirst(1)
        .get();
    return snap.exists;
  }

  Future<ItemRow> _requireItem(TransactionModel tx) async {
    final row = await itemFor(tx);
    if (row == null) {
      throw StateError('Item ${tx.itemId ?? tx.itemCode} not found');
    }
    return row;
  }

  Future<void> updateTransaction({
    required TransactionModel original,
    required TransactionModel updated,
  }) async {
    final id = original.transactionId!;
    final now = DateTime.now();
    final root = FirebaseDatabase.instance.ref();

    final Map<String, Object?> changes = {
      'transactions/$id/locationCode': updated.locationCode,
      'transactions/$id/quantity': updated.quantity,
      'transactions/$id/direction': updated.direction,
      'transactions/$id/type': updated.type,
      'transactions/$id/editedAt': now.toUtc().toIso8601String(),
    };

    final oldRow = await _requireItem(original);
    final newRow = await _requireItem(updated);
    final oldItemId = (oldRow.data['id'] as num?)?.toInt() ?? original.itemId;
    final newItemId = (newRow.data['id'] as num?)?.toInt() ?? updated.itemId;

    int? syncedOldStock;
    int? syncedNewStock;

    if (oldRow.key == newRow.key) {
      final delta = updated.stockEffect - original.stockEffect;
      if (delta != 0) {
        final resultingQuantity = newRow.quantity + delta;
        _ensureSufficientStock(
          resultingQuantity: resultingQuantity,
          itemCode: updated.itemCode,
          available: newRow.quantity,
          required: -delta,
        );
        changes['items/${newRow.key}/$stockField'] = ServerValue.increment(
          delta,
        );
        syncedNewStock = resultingQuantity;
      }
    } else {
      final oldResult = oldRow.quantity - original.stockEffect;
      _ensureSufficientStock(
        resultingQuantity: oldResult,
        itemCode: original.itemCode,
        available: oldRow.quantity,
        required: original.stockEffect,
      );

      final newResult = newRow.quantity + updated.stockEffect;
      _ensureSufficientStock(
        resultingQuantity: newResult,
        itemCode: updated.itemCode,
        available: newRow.quantity,
        required: -updated.stockEffect,
      );

      changes['items/${oldRow.key}/$stockField'] = ServerValue.increment(
        -original.stockEffect,
      );
      changes['items/${newRow.key}/$stockField'] = ServerValue.increment(
        updated.stockEffect,
      );
      syncedOldStock = oldResult;
      syncedNewStock = newResult;
    }

    await root.update(changes);

    final index = transactionDataList.indexWhere((t) => t.transactionId == id);
    if (index != -1) {
      transactionDataList[index] = updated.copyWith(
        editedAt: now,
        stock: syncedNewStock ?? transactionDataList[index].stock,
      );
    }

    if (oldRow.key == newRow.key) {
      if (syncedNewStock != null) {
        _syncItemStockInList(itemId: newItemId, newStock: syncedNewStock);
      }
    } else {
      if (syncedOldStock != null) {
        _syncItemStockInList(itemId: oldItemId, newStock: syncedOldStock);
      }
      if (syncedNewStock != null) {
        _syncItemStockInList(itemId: newItemId, newStock: syncedNewStock);
      }
    }

    notifyListeners();
  }

  Future<String> reverseTransaction({
    required TransactionModel original,
    required String reversedBy,
  }) async {
    if (original.reversed || original.isReversal) {
      throw StateError('This transaction cannot be reversed');
    }

    final id = original.transactionId!;
    final now = DateTime.now();
    final root = FirebaseDatabase.instance.ref();

    final newId = await _nextTransactionId();

    final reversal = TransactionModel(
      transactionId: newId,
      itemId: original.itemId,
      itemCode: original.itemCode,
      itemName: original.itemName,
      locationCode: original.locationCode,
      quantity: original.quantity,
      direction: original.oppositeDirection,
      type: kReversalType.code,
      stockKeeperId: reversedBy,
      timestamp: now,
      reversalOf: id,
      numericId: int.parse(newId.substring(3)),
      uomCode: original.uomCode,
      color: original.color,
      length: original.length,
      sw: original.sw,
      totalWeight: original.totalWeight,
      warehouse: original.warehouse,
      rack: original.rack,
      shelfNo: original.shelfNo,
      stock: original.stock,
    );

    final row = await _requireItem(original);
    final resultingQuantity = row.quantity + reversal.stockEffect;
    _ensureSufficientStock(
      resultingQuantity: resultingQuantity,
      itemCode: original.itemCode,
      available: row.quantity,
      required: original.quantity,
    );

    final Map<String, Object?> changes = {
      'transactions/$newId': reversal.toJson(),
      'transactions/$id/reversed': true,
      'transactions/$id/reversedBy': reversedBy,
      'transactions/$id/reversedAt': now.toUtc().toIso8601String(),
      'transactions/$id/reversalId': newId,
      'items/${row.key}/$stockField': ServerValue.increment(
        reversal.stockEffect,
      ),
    };

    await root.update(changes);

    final index = transactionDataList.indexWhere((t) => t.transactionId == id);
    if (index != -1) {
      transactionDataList[index] = original.copyWith(
        reversed: true,
        reversedBy: reversedBy,
        reversedAt: now,
        reversalId: newId,
        stock: resultingQuantity,
      );
    }
    transactionDataList.insert(0, reversal.copyWith(stock: resultingQuantity));

    final itemId = (row.data['id'] as num?)?.toInt() ?? original.itemId;
    _syncItemStockInList(itemId: itemId, newStock: resultingQuantity);

    notifyListeners();
    return newId;
  }

  Future<String> _nextTransactionId() async {
    var next =
        transactionDataList.fold<int>(
          0,
          (biggest, t) => t.numericId > biggest ? t.numericId : biggest,
        ) +
        1;
    while (true) {
      final id = 'tx_${next.toString().padLeft(3, '0')}';
      final snap = await FirebaseDatabase.instance
          .ref('transactions/$id')
          .get();
      if (!snap.exists) return id;
      next++;
    }
  }
}

class ItemRow {
  const ItemRow({required this.key, required this.data});

  final String key;
  final Map<String, dynamic> data;

  int get quantity =>
      ((data[TransactionData.stockField] ?? data['Quantity']) as num?)
          ?.toInt() ??
      0;

  String get code => (data['Item Code'] ?? '').toString();

  String get color => (data['COLOR'] ?? '').toString();

  String get uomCode => (data['UOM Code'] ?? '').toString();

  String nameOr(String code) =>
      (data['Name'] ?? data['name'] ?? 'Item $code').toString();

  String? get name => (data['Name'] ?? data['name'])?.toString();

  double get sw => (data['SW'] as num?)?.toDouble() ?? 0;

  double get length => (data['Length'] as num?)?.toDouble() ?? 0;

  double get totalWeightKg => quantity * length * sw;
}
