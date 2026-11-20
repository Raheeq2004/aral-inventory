import 'package:aral_project/Admin/Models/item_row.dart';
import 'package:aral_project/Admin/Models/transaction_types.dart';
import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:aral_project/Admin/providers/items_repository.dart';
import 'package:aral_project/Admin/providers/locations_repository.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class TransactionData extends ChangeNotifier {
  TransactionData({
    ItemsRepository? itemsRepo,
    LocationsRepository? locationsRepo,
  }) : _itemsRepo = itemsRepo ?? ItemsRepository(),
       _locationsRepo = locationsRepo ?? LocationsRepository();

  final ItemsRepository _itemsRepo;
  final LocationsRepository _locationsRepo;

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

  // Delegated helpers so existing UI callers (like TransactionDetailPage) keep working
  Future<ItemRow?> itemFor(TransactionModel tx) => _itemsRepo.itemFor(tx);
  Future<bool> locationExists(String locationCode) =>
      _locationsRepo.locationExists(locationCode);

  // Getter that returns the filtered and sorted list of transactions
  List<TransactionModel> get transactions {
    var list = List<TransactionModel>.from(transactionDataList);

    if (_searchQuery.isNotEmpty) {
      list = list.where((tx) {
        return tx.itemName.toLowerCase().contains(_searchQuery) ||
            tx.itemCode.toLowerCase().contains(_searchQuery) ||
            tx.stockKeeperId.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    if (_selectedWarehouse != null) {
      list = list
          .where(
            (tx) =>
                tx.locationCode.toUpperCase().startsWith(_selectedWarehouse!),
          )
          .toList();
    }

    if (_selectedMovement != null) {
      final selected = _selectedMovement!.toLowerCase();
      list = list.where((tx) {
        final direction = tx.direction.toLowerCase();
        if (selected.contains('in')) {
          return direction == 'in' || direction.contains('received');
        } else if (selected.contains('out')) {
          return direction == 'out' || direction.contains('issued');
        }
        return direction.contains(selected);
      }).toList();
    }

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

    if (_selectedLength != null) {
      list = list.where((tx) => tx.length == _selectedLength).toList();
    }

    if (_selectedSort != null) {
      if (_selectedSort == 'Newest first') {
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } else if (_selectedSort == 'Oldest first') {
        list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      } else if (_selectedSort == 'Largest quantity') {
        list.sort((a, b) => b.quantity.compareTo(a.quantity));
      }
    }

    return list;
  }

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
      final snapshot = await FirebaseDatabase.instance
          .ref('transactions')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        transactionDataList.clear();
        final extractedData = snapshot.value as Map<dynamic, dynamic>;

        extractedData.forEach((key, value) {
          final transactionMap = Map<String, dynamic>.from(value);
          transactionDataList.add(
            TransactionModel.fromMap(transactionMap, key.toString()),
          );
        });
        await _attachItemDetails();
      } else {
        debugPrint(
          'DEBUG: Node "transactions" is empty or does not exist in Firebase.',
        );
      }
    } catch (e) {
      debugPrint('DEBUG ERROR: Failed to fetch data: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _attachItemDetails() async {
    final ids = transactionDataList
        .map((t) => t.itemId)
        .whereType<int>()
        .toSet();

    final rows = await Future.wait(
      ids.map((id) async {
        try {
          return MapEntry<int, ItemRow?>(id, await _itemsRepo.itemById(id));
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

    final oldRow = await _itemsRepo.requireItem(original);
    final newRow = await _itemsRepo.requireItem(updated);
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
        changes['items/${newRow.key}/${ItemRow.stockField}'] =
            ServerValue.increment(delta);
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

      changes['items/${oldRow.key}/${ItemRow.stockField}'] =
          ServerValue.increment(-original.stockEffect);
      changes['items/${newRow.key}/${ItemRow.stockField}'] =
          ServerValue.increment(updated.stockEffect);
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

    final row = await _itemsRepo.requireItem(original);
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
      'items/${row.key}/${ItemRow.stockField}': ServerValue.increment(
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
