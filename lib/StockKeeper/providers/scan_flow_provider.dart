import 'dart:async'; // TimeoutException

import 'package:aral_project/Admin/Models/item_row.dart';
import 'package:aral_project/Admin/providers/items_repository.dart';
import 'package:aral_project/Admin/providers/locations_repository.dart';
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

/// What happened when we looked up a scanned location code (Step 2).
/// Simpler than products: a location code is unique, so it's found or not.
enum LocationStatus { found, notFound, offline }

/// The "brain" of the stock keeper's 3 steps.
///
/// ChangeNotifier (same idea as TransactionData on the admin side):
/// pages call its methods, it updates [session] and calls
/// notifyListeners() → every page that `watch`es it rebuilds.
///
/// The pages only SHOW things; the decisions live here. That keeps the
/// pages simple and makes this class easy to test later.
class ScanFlowProvider extends ChangeNotifier {
  ScanFlowProvider({
    required ItemsRepository itemsRepo,
    required LocationsRepository locationsRepo,
  }) : _itemsRepo = itemsRepo,
       _locationsRepo = locationsRepo;

  final ItemsRepository _itemsRepo;
  final LocationsRepository _locationsRepo;

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
  // STEP 2 — location
  // =================================================================

  /// Location codes look like "WH1-B3-02": WH<number>-<letter><number>-<2 digits>.
  /// RegExp check BEFORE asking Firebase: a code with the wrong shape
  /// (e.g. a PRODUCT label scanned by mistake) can't exist → no need to ask.
  static final RegExp _locationShape = RegExp(r'^WH\d+-[A-Z]\d+-\d{2}$');

  /// true if [code] looks like a location (used to warn "this is a product
  /// label, not a shelf label").
  static bool looksLikeLocation(String code) =>
      _locationShape.hasMatch(code.trim().toUpperCase());

  /// Looks up a scanned (or typed) location code in `locations`
  /// (indexed search on "Location Code"). When found it is saved in the
  /// session, so the Quantity page can show it.
  Future<LocationStatus> lookupLocation(String raw) async {
    final code = raw.trim().toUpperCase();
    if (!looksLikeLocation(code)) return LocationStatus.notFound;

    _isLooking = true;
    notifyListeners();
    try {
      final exists = await _locationsRepo
          .locationExists(code)
          .timeout(const Duration(seconds: 10));
      if (!exists) return LocationStatus.notFound;
      _session = _session.copyWith(locationCode: code);
      return LocationStatus.found;
    } on TimeoutException {
      return LocationStatus.offline;
    } catch (_) {
      return LocationStatus.offline;
    } finally {
      _isLooking = false;
      notifyListeners();
    }
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