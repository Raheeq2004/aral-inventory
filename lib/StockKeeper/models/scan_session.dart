import 'package:aral_project/Admin/Models/item_row.dart';

/// Everything the stock keeper has chosen so far in ONE scan flow:
///   Step 1 → [item]          (the product row: code + length + stock)
///   Step 2 → [locationCode]  (e.g. "WH1-B3-02")
///   Step 3 → quantity / IN-OUT / type are chosen on the Quantity page.
///
/// IMMUTABLE ("final" fields): we never change a session in place.
/// To change something we make a NEW copy with [copyWith]. This avoids
/// bugs where one page changes data another page is still showing.
class ScanSession {
  const ScanSession({this.item, this.locationCode});

  /// The scanned item's row in `items` (null = not scanned yet).
  /// ItemRow gives us the key (needed to write the stock), the code,
  /// the length, the live stock, the SW…
  final ItemRow? item;

  /// The scanned location code (null = not scanned yet).
  final String? locationCode;

  /// An empty session = the start of a new scan.
  static const empty = ScanSession();

  bool get hasItem => item != null;
  bool get hasLocation => locationCode != null;

  /// Returns a NEW session with the given fields replaced.
  /// `clearLocation: true` → used when the product changes, because a
  /// location chosen for the old product shouldn't carry over.
  ScanSession copyWith({
    ItemRow? item,
    String? locationCode,
    bool clearLocation = false,
  }) {
    return ScanSession(
      item: item ?? this.item,
      locationCode: clearLocation ? null : (locationCode ?? this.locationCode),
    );
  }
}