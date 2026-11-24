import 'package:aral_project/Admin/Models/item_row.dart';

// Small text helpers used by Steps 1, 2 AND 3, so the product and the
// location are written the SAME way on every page.
// (Top-level functions: no class needed, just import the file and call.)

/// 6.0 → "6 m", 6.3 → "6.3 m", 0 → "—"
String lengthText(double l) {
  if (l <= 0) return '—';
  return '${l == l.roundToDouble() ? l.toStringAsFixed(0) : l} m';
}

/// Second line of the PRODUCT card: "6 m · MF · 114 in stock"
/// (no product name: the database has no name column).
String productSubtitle(ItemRow row) {
  // Collection `if`: the colour part is only added when it isn't empty.
  final parts = [
    lengthText(row.length),
    if (row.color.isNotEmpty) row.color,
    '${row.quantity} in stock',
  ];
  return parts.join(' · ');
}

/// "WH1-B3-02" → "Warehouse 1 · Rack B3 · Shelf 02"
/// (if the code has an unexpected shape, it is returned as it is)
String locationTitle(String code) {
  final p = code.split('-');
  if (p.length != 3 || !p[0].startsWith('WH')) return code;
  return 'Warehouse ${p[0].substring(2)} · Rack ${p[1]} · Shelf ${p[2]}';
}