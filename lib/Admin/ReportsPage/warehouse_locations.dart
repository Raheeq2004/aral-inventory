import 'package:aral_project/Admin/ReportsPage/excel_export_services.dart';
import 'package:firebase_database/firebase_database.dart';

/// Reads the location nodes of the database: "Warehouse1", "Warehouse2", ...
/// Each row has: Location Code, Rack, Shelf No, Warehouse.
class WarehouseLocations {
  WarehouseLocations._();

  /// Returns every location as [warehouse, rack, shelf] (upper-case).
  /// Stops at the first "WarehouseN" node that doesn't exist.
  static Future<List<List<String>>> loadParts() async {
    final result = <List<String>>[];
    try {
      for (var i = 1; i <= 20; i++) {
        final snap = await FirebaseDatabase.instance.ref('Warehouse$i').get();
        if (!snap.exists || snap.value == null) break;

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
            final v = '${row[field] ?? ''}'.trim().toUpperCase();
            return v.isNotEmpty ? v : fromCode[i]; // fall back to the code
          }

          result.add([
            pick('Warehouse', 0),
            pick('Rack', 1),
            pick('Shelf No', 2),
          ]);
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG ERROR: could not read warehouse locations: $e');
    }
    return result;
  }
}
