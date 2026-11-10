// =====================================================================
// ARAL Inventory – Transaction types (WHY stock moved)
// =====================================================================
//
// ONE place for the list of types. A3, the worker scan screen, filters
// and the Excel export all read from here → to change a type, edit ONLY
// this file.
//
// Each type has:
//   code      → stored in Firebase (short English, NEVER changes)
//   label     → shown to the user (Arabic)
//   direction → 'IN' or 'OUT' (a type belongs to ONE direction)
//
// Why store a code and show Arabic?
//   If someone later changes the Arabic wording, old transactions still
//   work, because Firebase only has the code (e.g. "issue_out").
//
// NOTE: sample list for now — confirm the real types with ARAL later.
// =====================================================================

/// One transaction type. A small, immutable class (all fields `final`).
class TransactionType {
  // `const` constructor → the list below can be a compile-time constant.
  const TransactionType({
    required this.code,
    required this.label,
    required this.direction,
  });

  final String code; // stored in Firebase, e.g. 'purchase_receipt'
  final String label; // shown in the app, e.g. 'استلام مشتريات'
  final String direction; // 'IN' or 'OUT'
}

// ---------------------------------------------------------------------
// The list (Arabic labels)
// ---------------------------------------------------------------------
const List<TransactionType> kTransactionTypes = [
  // ---------- IN (وارد) ----------
  TransactionType(code: 'purchase_receipt', label: 'استلام مشتريات', direction: 'IN'),
  TransactionType(code: 'return_in', label: 'مرتجع من قسم / مشروع', direction: 'IN'),
  TransactionType(code: 'transfer_in', label: 'تحويل وارد', direction: 'IN'),
  TransactionType(code: 'opening_balance', label: 'رصيد افتتاحي', direction: 'IN'),
  TransactionType(code: 'adjustment_in', label: 'تسوية جرد (زيادة)', direction: 'IN'),

  // ---------- OUT (صادر) ----------
  TransactionType(code: 'issue_out', label: 'صرف لقسم / مشروع', direction: 'OUT'),
  TransactionType(code: 'sales_delivery', label: 'تسليم لعميل', direction: 'OUT'),
  TransactionType(code: 'transfer_out', label: 'تحويل صادر', direction: 'OUT'),
  TransactionType(code: 'return_out', label: 'مرتجع للمورد', direction: 'OUT'),
  TransactionType(code: 'damaged', label: 'تالف / هالك', direction: 'OUT'),
  TransactionType(code: 'adjustment_out', label: 'تسوية جرد (نقص)', direction: 'OUT'),
];

/// Set automatically by the Reverse button (A4). NOT in the dropdown.
const TransactionType kReversalType = TransactionType(
  code: 'reversal',
  label: 'عكس عملية',
  direction: '', // a reversal can be IN or OUT (opposite of the original)
);

// ---------------------------------------------------------------------
// Old sample data stored English text (e.g. "Purchase Receipt").
// This map translates those old values to the new codes, so old
// transactions still show the right Arabic label.
// Keys are lower-case so "Purchase Receipt" and "purchase receipt" match.
// ---------------------------------------------------------------------
const Map<String, String> _legacyToCode = {
  'purchase receipt': 'purchase_receipt',
  'sales fulfillment': 'sales_delivery',
  'initial count': 'opening_balance',
  'audit loss': 'adjustment_out',
  'audit gain': 'adjustment_in',
  'return': 'return_in',
  'damaged': 'damaged',
  // 'internal transfer' depends on the direction → handled in normalizeType
};

// ---------------------------------------------------------------------
// Helper functions (top-level functions: usable from any file that
// imports this one, no object needed).
// ---------------------------------------------------------------------

/// All types for one direction → used to fill the dropdown.
/// `where` keeps only the matching ones; `toList()` makes a List.
List<TransactionType> typesFor(String direction) =>
    kTransactionTypes.where((t) => t.direction == direction).toList();

/// The default type for a direction (the most common one):
/// IN → استلام مشتريات · OUT → صرف لقسم / مشروع
String defaultTypeFor(String direction) =>
    direction == 'OUT' ? 'issue_out' : 'purchase_receipt';

/// Turns ANY stored value (new code, old English text, or empty) into a
/// valid code for this direction.
String normalizeType(String? stored, String direction) {
  final value = (stored ?? '').trim();
  final lower = value.toLowerCase();

  // 1) Already a valid code for this direction? keep it.
  if (typesFor(direction).any((t) => t.code == value)) return value;
  if (value == kReversalType.code) return value;

  // 2) Old English value? translate it.
  if (lower == 'internal transfer') {
    return direction == 'OUT' ? 'transfer_out' : 'transfer_in';
  }
  final mapped = _legacyToCode[lower];
  if (mapped != null && typesFor(direction).any((t) => t.code == mapped)) {
    return mapped;
  }

  // 3) Unknown, empty, or doesn't match the direction → use the default.
  return defaultTypeFor(direction);
}

/// The Arabic label for a stored value (used by lists, cards, export).
String typeLabel(String? stored, String direction) {
  final code = normalizeType(stored, direction);
  if (code == kReversalType.code) return kReversalType.label;
  // firstWhere finds the first match; orElse is used if none is found.
  return kTransactionTypes
      .firstWhere(
        (t) => t.code == code,
        orElse: () => const TransactionType(code: '', label: '—', direction: ''),
      )
      .label;
}