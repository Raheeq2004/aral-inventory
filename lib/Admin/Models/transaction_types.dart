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
// OLD names → new codes
// The sample data was created with English names ("Purchase Receipt",
// "Customer Return", …). This map translates each old name (lower-case)
// into a code, PER DIRECTION, so old transactions show the right Arabic
// type everywhere (A3, Reports filter, Excel).
// A Map inside a Map: { old name: { 'IN': code, 'OUT': code } }
// ---------------------------------------------------------------------
const Map<String, Map<String, String>> _legacyToCode = {
  'purchase receipt': {'IN': 'purchase_receipt'},
  'customer return': {'IN': 'return_in', 'OUT': 'return_out'},
  'return': {'IN': 'return_in', 'OUT': 'return_out'},
  'internal transfer': {'IN': 'transfer_in', 'OUT': 'transfer_out'},
  'internal transfer in': {'IN': 'transfer_in'},
  'internal transfer out': {'OUT': 'transfer_out'},
  'initial count': {'IN': 'opening_balance', 'OUT': 'adjustment_out'},
  'initial stock count / adjustment': {'IN': 'opening_balance', 'OUT': 'adjustment_out'},
  'audit gain': {'IN': 'adjustment_in'},
  'audit loss': {'OUT': 'adjustment_out', 'IN': 'adjustment_in'},
  'audit loss / shrinkage': {'OUT': 'adjustment_out', 'IN': 'adjustment_in'},
  'damaged': {'OUT': 'damaged'},
  'damaged / defective': {'OUT': 'damaged'},
  'sales fulfillment': {'OUT': 'sales_delivery'},
  // No exact match in our list → closest: "صرف لقسم / مشروع"
  'sample / promotional': {'OUT': 'issue_out'},
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
  // `?[direction]` = look inside only if the old name was found (null-safe)
  final mapped = _legacyToCode[lower]?[direction];
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

/// The Arabic label for a CODE (e.g. 'issue_out' → 'صرف لقسم / مشروع').
/// Used by the Reports page chips.
String labelForCode(String code) {
  if (code == kReversalType.code) return kReversalType.label;
  for (final t in kTransactionTypes) {
    if (t.code == code) return t.label;
  }
  return code;
}

/// All codes in display order (IN types, OUT types, then reversal).
List<String> get allTypeCodes => [
  ...kTransactionTypes.map((t) => t.code),
  kReversalType.code,
];