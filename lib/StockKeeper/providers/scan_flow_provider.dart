import 'package:aral_project/Admin/Models/item_row.dart';
import 'package:aral_project/Admin/providers/items_repository.dart';
import 'package:aral_project/Admin/providers/locations_repository.dart';
import 'package:aral_project/StockKeeper/models/scan_session.dart';
import 'package:aral_project/connectivity/connectivity_service.dart';
import 'package:flutter/foundation.dart'; // ChangeNotifier, debugPrint

/// What happened when we looked up a scanned product code.
/// An `enum` = a fixed list of possible values (like 'IN' / 'OUT', but
/// checked by Dart: a typo is a compile error, not a silent bug).
enum LookupStatus {
  found, // exactly ONE row → go on to Step 2
  // 2+ rows (same code, several lengths) → ask the keeper.
  // Only happens for a TYPED item code: an ITM-id label
  // always points to exactly one row.
  chooseLength,
  notFound, // no row with this code / id
  // The CAMERA read a QR that isn't one of ours (not ITM-…, not WH…):
  // a supplier barcode, an old test label, a random QR…
  notOurLabel,
  // TYPED text that can't be an id or an item code at all (e.g. "RAHEEQ"):
  // not "not registered" — it's simply not a code.
  invalidCode,
  offline, // the phone has no internet
  failed, // online, but Firebase gave an error / took too long
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
/// `failed` = online but something went wrong (same idea as for products).
enum LocationStatus { found, notFound, offline, failed }

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
    required this._itemsRepo,
    required LocationsRepository locationsRepo,
  }) : _locationsRepo = locationsRepo;

  final ItemsRepository _itemsRepo;
  final LocationsRepository _locationsRepo;

  ScanSession _session = ScanSession.empty;
  ScanSession get session => _session;

  /// true while we wait for Firebase → the page shows a small spinner
  /// and ignores new scans (so one label isn't looked up 5 times).
  bool _isLooking = false;
  bool get isLooking => _isLooking;

  /// The same check the green "Online" badge uses (connectivity_plus):
  /// is the phone connected to Wi-Fi / mobile data at all?
  final ConnectivityService _connectivity = ConnectivityService();

  /// Called when a lookup FAILED: was it really "no internet", or another
  /// problem? Before, every error said "No connection" — even when the phone
  /// was online (that's what happened with ITM-999999).
  ///   [error] is printed in the debug console so we can see the real reason.
  Future<bool> _failedBecauseOffline(Object error, String what) async {
    debugPrint('Scan lookup failed for $what: $error');
    try {
      return !(await _connectivity.checkInitialConnection());
    } catch (_) {
      return false; // can't tell → don't blame the internet
    }
  }

  // =================================================================
  // STEP 1 — product
  // =================================================================

  /// Product labels hold "ITM-" + the item id, e.g. "ITM-1201".
  ///   ^      → start of the text      ITM-   → these 4 letters exactly
  ///   (\d+)  → one or more digits, inside ( ) = a "group" we can read
  ///   $      → end of the text (nothing allowed after the number)
  static final RegExp _productLabelShape = RegExp(r'^ITM-(\d+)$');

  /// Only digits, e.g. "1201" (allowed when the keeper TYPES it, not scanned).
  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  /// What a real ITEM CODE looks like ("2MFMF-BT128", "1BMBM010-AR801"):
  ///   (?=.*[A-Z])  → somewhere it has at least ONE letter
  ///   (?=.*\d)     → somewhere it has at least ONE digit
  ///   (?=…) is a "look-ahead": it CHECKS without using up characters.
  ///   [A-Z0-9]     → starts with a letter or digit
  ///   [A-Z0-9./-]{2,29} → then 2–29 more letters, digits, . / or -
  ///                  (so 3–30 characters in total)
  /// "RAHEEQ" has no digit → not an item code. "12" is too short.
  static final RegExp _itemCodeShape = RegExp(
    r'^(?=.*[A-Z])(?=.*\d)[A-Z0-9][A-Z0-9./-]{2,29}$',
  );

  /// true if [code] COULD be an item code (we still ask Firebase if it exists).
  static bool looksLikeItemCode(String code) =>
      _itemCodeShape.hasMatch(code.trim().toUpperCase());

  /// true if [code] looks like a PRODUCT label ("ITM-1201").
  /// Used on Step 2 to say "this is a product label, scan the shelf".
  static bool looksLikeProduct(String code) =>
      _productLabelShape.hasMatch(code.trim().toUpperCase());

  /// Reads the item id out of [code]:
  ///   "ITM-1201" → 1201
  ///   "1201"     → 1201, but ONLY if [allowBareNumber] (typed by hand)
  ///   anything else → null (not an id)
  ///
  /// Why no bare numbers from the CAMERA: any random QR / barcode in the
  /// warehouse could contain just a number and match a wrong item. The
  /// "ITM-" prefix proves the QR is one of OUR product labels.
  static int? productIdFrom(String code, {bool allowBareNumber = false}) {
    final clean = code.trim().toUpperCase();
    // firstMatch → the match (or null); group(1) → the digits inside ( ).
    final match = _productLabelShape.firstMatch(clean);
    final digits =
        match?.group(1) ??
        (allowBareNumber && _digitsOnly.hasMatch(clean) ? clean : null);
    if (digits == null) return null;
    // tryParse returns null instead of crashing on a huge number.
    final id = int.tryParse(digits);
    return (id != null && id > 0) ? id : null; // ids start at 1
  }

  /// Looks up a scanned (or typed) product label in `items`.
  ///
  /// THE ORDER OF CHECKS:
  ///   1. "ITM-1201" (or "1201" when [typed]) → read `items/(id - 1)` directly
  ///      → exactly ONE row, never a "which length?" question.
  ///   2. A shelf code (WH1-B3-02) → not a product, no need to ask Firebase.
  ///   3. Anything else:
  ///      • from the CAMERA → [LookupStatus.notOurLabel] (not an ARAL label)
  ///      • TYPED by hand and shaped like an item code ("2MFMF-BT128")
  ///        → search by code (+ "Which length?" sheet if needed)
  ///      • TYPED but not a code at all ("RAHEEQ") → [LookupStatus.invalidCode]
  ///
  /// Returns a [ProductLookup] and lets the PAGE decide what to show
  /// (go on, length sheet, "not found" dialog…). When exactly one row
  /// matches, it is also saved in the session right away.
  ///
  /// [typed] = true when the code comes from "Enter code manually".
  Future<ProductLookup> lookupProduct(String raw, {bool typed = false}) async {
    // Clean the text: remove spaces/new lines around it and use capitals,
    // because codes in the database are upper-case ("2MFMF-BT128").
    final code = raw.trim().toUpperCase();

    final id = productIdFrom(code, allowBareNumber: typed);
    if (id == null && looksLikeLocation(code)) {
      return ProductLookup(LookupStatus.notFound, code);
    }
    // From the CAMERA only ITM-<id> labels are accepted. Item codes work
    // only when TYPED (a keeper may know the code but not the id).
    if (id == null && !typed) {
      return ProductLookup(LookupStatus.notOurLabel, code);
    }
    // TYPED, not an id, and doesn't even look like an item code
    // → don't ask Firebase, tell the keeper the text itself is wrong.
    if (id == null && !looksLikeItemCode(code)) {
      return ProductLookup(LookupStatus.invalidCode, code);
    }

    _isLooking = true;
    notifyListeners();
    try {
      // ---- 1. by ID: the normal case for every new label ----
      if (id != null) {
        // ONE direct read of items/(id − 1) — our rule "key = id − 1".
        // No search of the whole table: if nothing is there, the item
        // simply doesn't exist → "not registered" right away.
        // .timeout: offline, Firebase may wait a long time → stop after 10 s.
        final row = await _itemsRepo
            .itemByIdDirect(id)
            .timeout(const Duration(seconds: 10));
        if (row == null) return ProductLookup(LookupStatus.notFound, code);
        selectItem(row);
        return ProductLookup(LookupStatus.found, code, [row]);
      }

      // ---- 3. by ITEM CODE: only when typed by hand ----
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
    } catch (e) {
      // ONE catch for everything (a TimeoutException too), then we check
      // WHY: no internet → offline, otherwise → failed.
      final offline = await _failedBecauseOffline(e, code);
      return ProductLookup(
        offline ? LookupStatus.offline : LookupStatus.failed,
        code,
      );
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

  /// Location codes look like "WH1-B3-02": `WH<number>-<letter><number>-<2 digits>`.
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
    } catch (e) {
      final offline = await _failedBecauseOffline(e, code);
      return offline ? LocationStatus.offline : LocationStatus.failed;
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