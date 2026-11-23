import 'package:firebase_database/firebase_database.dart';

class LocationsRepository {
  final DatabaseReference _locationsRef = FirebaseDatabase.instance.ref(
    'locations',
  );

  /// Returns true if [locationCode] (e.g. "WH1-A1-02") exists in `locations`.
  Future<bool> locationExists(String locationCode) async {
    final snap = await _locationsRef
        .orderByChild('Location Code')
        .equalTo(locationCode)
        .limitToFirst(1)
        .get();
    return snap.exists;
  }

  // WHOLE TABLE (used by the Reports page)
  List<List<String>>? _parts;

  /// The result of the last [loadParts] (null until the first read).
  List<List<String>>? get cachedParts => _parts;

  /// Reads the `locations` table (ONE read for all warehouses) and returns
  /// every location as [warehouse, rack, shelf] (upper-case).
  /// Each row has: Location Code, Rack, Shelf No, Warehouse.
  Future<List<List<String>>> loadParts() async {
    final snap = await _locationsRef.get();
    final result = <List<String>>[];
    if (!snap.exists || snap.value == null) return _parts = result;

    // Firebase returns a List when keys are 0,1,2... and a Map otherwise.
    final raw = snap.value;
    final Iterable rows = raw is Map
        ? raw.values
        : raw is List
        ? raw
        : const [];

    for (final row in rows) {
      if (row is! Map) continue;
      final fromCode = _splitCode('${row['Location Code'] ?? ''}');

      String pick(String field, int i) {
        var v = '${row[field] ?? ''}'.trim().toUpperCase();
        // "Shelf No" is sometimes a number (7) and sometimes text ("07")
        // in the import -> always 2 digits, so 7 and "07" are the same.
        if (field == 'Shelf No' && int.tryParse(v) != null) {
          v = v.padLeft(2, '0');
        }
        return v.isNotEmpty ? v : fromCode[i]; // fall back to the code
      }

      result.add([pick('Warehouse', 0), pick('Rack', 1), pick('Shelf No', 2)]);
    }
    return _parts = result;
  }

  /// "WH1-A1-01" (or "WH1 / A1 / 01") -> [WH1, A1, 01]. Always 3 items.
  static List<String> _splitCode(String code) {
    final parts = code
        .trim()
        .split(RegExp(r'[\s/\-]+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p.toUpperCase())
        .toList();
    return [for (var i = 0; i < 3; i++) i < parts.length ? parts[i] : ''];
  }
}
