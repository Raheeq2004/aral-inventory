import 'dart:async'; // TimeoutException

import 'package:aral_project/Admin/Models/item_row.dart';
import 'package:aral_project/Admin/providers/items_repository.dart';
import 'package:aral_project/StockKeeper/models/scan_session.dart';
import 'package:flutter/foundation.dart'; // ChangeNotifier

/// What happened when we looked up a scanned product code.
/// An `enum` = a fixed list of possible values (like 'IN' / 'OUT', but
/// checked by Dart: a typo is a compile error, not a silent bug).
enum LookupStatus {
  found, // exactly ONE row → go on to Step 2
  chooseLength, // 2+ rows (same code, several lengths) → ask the keeper
  notFound, // no row with this code
  offline, // no answer from Firebase (no internet)
}

/// The result of [ScanFlowProvider.lookupProduct]: the status + the rows.
class ProductLookup {
  const ProductLookup(this.status, this.code, [this.rows = const []]);

  final LookupStatus status;
  final String code; // the code as we searched it (cleaned)
  final List<ItemRow> rows; // the matching rows (empty when not found)
}

/// The "brain" of the stock keeper's 3 steps.
///
/// ChangeNotifier (same idea as TransactionData on the admin side):
/// pages call its methods, it updates [session] and calls
/// notifyListeners() → every page that `watch`es it rebuilds.
///
/// The pages only SHOW things; the decisions live here. That keeps the
/// pages simple and makes this class easy to test later.
class ScanFlowProvider extends ChangeNotifier {
  ScanFlowProvider({required ItemsRepository itemsRepo})
    : _itemsRepo = itemsRepo;

  final ItemsRepository _itemsRepo;

  ScanSession _session = ScanSession.empty;
  ScanSession get session => _session;

  /// true while we wait for Firebase → the page shows a small spinner
  /// and ignores new scans (so one label isn't looked up 5 times).
  bool _isLooking = false;
  bool get isLooking => _isLooking;

  // =================================================================
  // STEP 1 — product
  // =================================================================

  /// Looks up a scanned (or typed) product code in `items`.
  ///
  /// Returns a [ProductLookup] and lets the PAGE decide what to show
  /// (go on, length sheet, "not found" dialog…). When exactly one row
  /// matches, it is also saved in the session right away.
  Future<ProductLookup> lookupProduct(String raw) async {
    // Clean the text: remove spaces/new lines around it and use capitals,
    // because codes in the database are upper-case ("2MFMF-BT128").
    final code = raw.trim().toUpperCase();

    _isLooking = true;
    notifyListeners();
    try {
      // .timeout: offline, Firebase may wait a long time → stop after 10 s.
      final rows = await _itemsRepo
          .findAllByCode(code)
          .timeout(const Duration(seconds: 10));

      if (rows.isEmpty) return ProductLookup(LookupStatus.notFound, code);

      if (rows.length == 1) {
        selectItem(rows.first); // only one possibility → choose it
        return ProductLookup(LookupStatus.found, code, rows);
      }

      // Several rows: sort by length (5 m, 6 m, 7 m…) for the sheet.
      // `..sort(...)` (cascade) sorts the list and gives the same list back.
      final sorted = [...rows]..sort((a, b) => a.length.compareTo(b.length));
      return ProductLookup(LookupStatus.chooseLength, code, sorted);
    } on TimeoutException {
      return ProductLookup(LookupStatus.offline, code);
    } catch (_) {
      return ProductLookup(LookupStatus.offline, code);
    } finally {
      // finally ALWAYS runs (success, error or return) → stop the spinner.
      _isLooking = false;
      notifyListeners();
    }
  }

  /// Saves the chosen item row in the session (Step 1 done).
  /// The location is cleared: a new product starts a new location step.
  void selectItem(ItemRow row) {
    _session = _session.copyWith(item: row, clearLocation: true);
    notifyListeners();
  }

  // =================================================================
  // RESET
  // =================================================================

  /// Starts a brand-new scan (after the transaction is saved, or "Cancel").
  void reset() {
    _session = ScanSession.empty;
    _isLooking = false;
    notifyListeners();
  }
}