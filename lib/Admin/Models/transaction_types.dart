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
// The list below is the one ARAL's manager gave us (Nov 2026).
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
// The list (Arabic labels) — from ARAL's manager.
// Where a type kept its MEANING, we kept its old CODE and only changed the
// Arabic label (e.g. 'sales_delivery' now shows «مبيعات»). That way the
// transactions already saved in Firebase still match, with no migration.
// ---------------------------------------------------------------------
const List<TransactionType> kTransactionTypes = [
  // ---------- IN (وارد) ----------
  TransactionType(code: 'return_in', label: 'مرتجع على', direction: 'IN'),
  TransactionType(code: 'packaging_in', label: 'إدخال تغليف', direction: 'IN'),
  TransactionType(code: 'services_in', label: 'خدمات', direction: 'IN'),
  TransactionType(code: 'warehouse_in', label: 'استلام مستودع آخر', direction: 'IN'),
  TransactionType(code: 'adjustment_in', label: 'تسوية جرد', direction: 'IN'),
  TransactionType(code: 'opening_balance', label: 'رصيد افتتاحي', direction: 'IN'),

  // ---------- OUT (صادر) ----------
  TransactionType(code: 'sales_delivery', label: 'مبيعات', direction: 'OUT'),
  TransactionType(code: 'transfer_out', label: 'تحويل صادر', direction: 'OUT'),
  TransactionType(code: 'issue_out', label: 'صرف قسم', direction: 'OUT'),
  TransactionType(code: 'damaged', label: 'تالف', direction: 'OUT'),
  TransactionType(code: 'transfer', label: 'تحويل', direction: 'OUT'),
  TransactionType(code: 'warehouse_out', label: 'تحويل مستودع آخر', direction: 'OUT'),
];

// ---------------------------------------------------------------------
// RETIRED types: they were in our first list but NOT in the manager's.
// They are NOT offered in the dropdown any more, but OLD transactions that
// use them still show their original Arabic name (we never rewrite
// history). If the admin edits such a transaction, they can pick a new type.
// ---------------------------------------------------------------------
const List<TransactionType> kRetiredTypes = [
  TransactionType(code: 'purchase_receipt', label: 'استلام مشتريات', direction: 'IN'),
  TransactionType(code: 'transfer_in', label: 'تحويل وارد', direction: 'IN'),
  TransactionType(code: 'return_out', label: 'مرتجع للمورد', direction: 'OUT'),
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
  // No exact match in our list → closest: «صرف قسم»
  'sample / promotional': {'OUT': 'issue_out'},
};

// ---------------------------------------------------------------------
// Helper functions (top-level functions: usable from any file that
// imports this one, no object needed).
// ---------------------------------------------------------------------

/// All ACTIVE types for one direction → used to fill the dropdown.
/// `where` keeps only the matching ones; `toList()` makes a List.
List<TransactionType> typesFor(String direction) =>
    kTransactionTypes.where((t) => t.direction == direction).toList();

/// Finds a type by its code in ALL lists (active, retired, reversal).
/// Returns null if the code is unknown.
TransactionType? typeByCode(String code) {
  if (code == kReversalType.code) return kReversalType;
  // `...` (spread) joins the two lists into one to search them together.
  for (final t in [...kTransactionTypes, ...kRetiredTypes]) {
    if (t.code == code) return t;
  }
  return null;
}

/// true if [code] is a retired type (shown for old data, not selectable).
bool isRetiredType(String code) => kRetiredTypes.any((t) => t.code == code);

/// The default type for a direction = the FIRST one in the manager's list:
/// IN → مرتجع على · OUT → مبيعات
String defaultTypeFor(String direction) => typesFor(direction).first.code;

/// Turns ANY stored value (new code, old English text, or empty) into a
/// valid code for this direction.
String normalizeType(String? stored, String direction) {
  final value = (stored ?? '').trim();
  final lower = value.toLowerCase();

  // A code is OK if it exists (active or retired) AND fits the direction.
  bool fits(String code) => [...kTransactionTypes, ...kRetiredTypes]
      .any((t) => t.code == code && t.direction == direction);

  // 1) Already a valid code (or the reversal)? keep it.
  if (fits(value)) return value;
  if (value == kReversalType.code) return value;

  // 2) Old English value? translate it.
  // `?[direction]` = look inside only if the old name was found (null-safe)
  final mapped = _legacyToCode[lower]?[direction];
  if (mapped != null && fits(mapped)) return mapped;

  // 3) Unknown, empty, or doesn't match the direction → use the default.
  return defaultTypeFor(direction);
}

/// The Arabic label for a stored value (used by lists, cards, export).
String typeLabel(String? stored, String direction) {
  final code = normalizeType(stored, direction);
  return typeByCode(code)?.label ?? '—';
}

/// The Arabic label for a CODE (e.g. 'issue_out' → 'صرف قسم').
/// Used by the Reports page chips.
String labelForCode(String code) => typeByCode(code)?.label ?? code;

/// All codes in display order (active IN + OUT, retired, then reversal).
/// Reports only shows the ones that actually appear in the data.
List<String> get allTypeCodes => [
  ...kTransactionTypes.map((t) => t.code),
  ...kRetiredTypes.map((t) => t.code),
  kReversalType.code,
];