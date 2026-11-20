import 'package:aral_project/Admin/ReportsPage/excel_export_services.dart';
import 'package:firebase_database/firebase_database.dart';

/// Reads the `locations` table (Joud's new structure — it replaced the
/// old "Warehouse1", "Warehouse2" nodes). ONE read for all warehouses.
/// Each row has: Location Code, Rack, Shelf No, Warehouse.
class WarehouseLocations {
  WarehouseLocations._();

  /// Returns every location as [warehouse, rack, shelf] (upper-case).
  static Future<List<List<String>>> loadParts() async {
    final result = <List<String>>[];
    try {
      final snap = await FirebaseDatabase.instance.ref('locations').get();
      if (!snap.exists || snap.value == null) return result;

      // Firebase returns a List when keys are 0,1,2... and a Map otherwise.
      final raw = snap.value;
      final Iterable rows = raw is Map
          ? raw.values
          : raw is List
          ? raw
          : const [];

      for (final row in rows) {
        if (row is! Map) continue;
        final code = '${row['Location Code'] ?? ''}'.trim();
        final fromCode = ExcelExportService.locationParts(code);

        String pick(String field, int i) {
          var v = '${row[field] ?? ''}'.trim().toUpperCase();
          // "Shelf No" is sometimes a number (7) and sometimes text ("07")
          // in the import → always 2 digits, so 7 and "07" are the same.
          if (field == 'Shelf No' && int.tryParse(v) != null) {
            v = v.padLeft(2, '0');
          }
          return v.isNotEmpty ? v : fromCode[i]; // fall back to the code
        }

        result.add([
          pick('Warehouse', 0),
          pick('Rack', 1),
          pick('Shelf No', 2),
        ]);
      }
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG ERROR: could not read warehouse locations: $e');
    }
    return result;
  }
}