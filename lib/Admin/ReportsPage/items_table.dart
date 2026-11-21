import 'package:aral_project/Admin/Models/item_row.dart';
import 'package:firebase_database/firebase_database.dart';

/// Reads the WHOLE `items` table (one read) for the reports.
/// Every row keeps ALL its properties in `row.data`
/// (id, Item Code, COLOR, Length, UOM Code, SW, Stock ...).
/// The primary key of a row is `data['id']`; `row.quantity` is its STOCK.
class ItemsTable {
  ItemsTable._();

  static Future<List<ItemRow>> loadAll() async {
    final snap = await FirebaseDatabase.instance.ref('items').get();
    if (!snap.exists || snap.value == null) return [];

    final rows = <ItemRow>[];
    void add(String key, Object? value) {
      if (value is Map) {
        rows.add(ItemRow(key: key, data: Map<String, dynamic>.from(value)));
      }
    }

    // Firebase returns a List when keys are 0,1,2... and a Map otherwise
    // (a List can contain nulls where a row was deleted).
    final raw = snap.value;
    if (raw is Map) {
      raw.forEach((k, v) => add('$k', v));
    } else if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        add('$i', raw[i]);
      }
    }
    return rows;
  }
}
