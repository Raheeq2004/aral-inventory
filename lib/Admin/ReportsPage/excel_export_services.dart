import 'dart:io';
import 'dart:typed_data';

import 'package:aral_project/Admin/Models/item_row.dart';
import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// One line of the stock report: an item row (all its properties) and its
/// STOCK on the chosen day.
class StockLine {
  final ItemRow item;
  final int stock;
  const StockLine(this.item, this.stock);
}

/// Finds the `items` row of a transaction: by item id first (the primary
/// key), otherwise by item code + length (old transactions).
class ItemIndex {
  ItemIndex(Iterable<ItemRow> items) {
    for (final r in items) {
      final id = ExcelExportService.idOf(r);
      if (id != null) _byId[id] = r;
      _byCode.putIfAbsent(r.code, () => []).add(r);
    }
  }

  final Map<int, ItemRow> _byId = {};
  final Map<String, List<ItemRow>> _byCode = {};

  ItemRow? forTx(TransactionModel tx) {
    final id = tx.itemId;
    if (id != null) {
      final row = _byId[id];
      if (row != null) return row;
    }
    final sameCode = _byCode[tx.itemCode];
    if (sameCode == null) return null;
    for (final r in sameCode) {
      if ((r.length - tx.length).abs() < 0.001) return r;
    }
    return (sameCode.length == 1 && tx.length <= 0) ? sameCode.first : null;
  }
}

/// build the .xlsx files
class ExcelExportService {
  ExcelExportService._();

  // ---------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------

  /// The primary key of an item row.
  static int? idOf(ItemRow r) => (r.data['id'] as num?)?.toInt();

  /// Location codes look like "WH1-A1-01" (or "WH1 / A1 / 01").
  /// Split on dashes, slashes or spaces -> [warehouse, rack, shelf].
  /// Always returns 3 items ('' when a part is missing).
  static List<String> locationParts(String locationCode) {
    final parts = locationCode
        .trim()
        .split(RegExp(r'[\s/\-]+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p.toUpperCase())
        .toList();
    return [for (var i = 0; i < 3; i++) i < parts.length ? parts[i] : ''];
  }

  static String warehouseOf(String locationCode) =>
      locationParts(locationCode)[0];

  /// transactions_17-10-2026.xlsx
  /// transactions_01-10-2026_17-10-2026.xlsx   (year on both dates)
  static String fileNameFor({DateTime? from, DateTime? to}) {
    final full = DateFormat('dd-MM-yyyy');
    if (from == null || to == null) {
      return 'transactions_${full.format(DateTime.now())}.xlsx';
    }
    final sameDay =
        from.year == to.year && from.month == to.month && from.day == to.day;
    if (sameDay) return 'transactions_${full.format(to)}.xlsx';
    return 'transactions_${full.format(from)}_${full.format(to)}.xlsx';
  }

  /// stock_17-10-2026.xlsx
  static String stockFileNameFor(DateTime asOf) =>
      'stock_${DateFormat('dd-MM-yyyy').format(asOf)}.xlsx';

  /// Type exactly as it is written in the db, just tidied:
  /// "issue_out" -> "Issue Out", "Purchase Receipt" stays "Purchase Receipt".
  static String englishType(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (t.contains('_') || t == t.toLowerCase()) {
      return t
          .split(RegExp(r'[_\s]+'))
          .where((w) => w.isNotEmpty)
          .map((w) => w[0].toUpperCase() + w.substring(1))
          .join(' ');
    }
    return t;
  }

  // ---------------------------------------------------------------------
  // ITEM PROPERTIES  (every report shows ALL of them)
  // ---------------------------------------------------------------------

  // shown first, in this order (if the items table has them)
  static const List<String> _firstKeys = [
    'Item Code',
    'COLOR',
    'Length',
    'UOM Code',
    'SW',
  ];

  // NOT listed as normal properties:
  //  id            -> has its own "Item ID" column (the primary key)
  //  Name / name   -> product name is removed from the reports
  //  Stock / Quantity -> this IS the stock, it gets its own column
  static const Set<String> _skipKeys = {
    'id',
    'Name',
    'name',
    'Stock',
    'Quantity',
  };

  /// Every property name found in the items table (ALL of them, dynamic),
  /// known ones first, the rest A-Z.
  static List<String> propertyKeys(Iterable<ItemRow> items) {
    final found = <String>{};
    for (final r in items) {
      found.addAll(r.data.keys);
    }
    found.removeAll(_skipKeys);
    final first = _firstKeys.where(found.contains).toList();
    final rest = found.where((k) => !_firstKeys.contains(k)).toList()..sort();
    return [...first, ...rest];
  }

  static xl.CellValue _cell(Object? v) {
    if (v == null) return xl.TextCellValue('');
    if (v is int) return xl.IntCellValue(v);
    if (v is num) return xl.DoubleCellValue(v.toDouble());
    return xl.TextCellValue('$v');
  }

  // ---------------------------------------------------------------------
  // STOCK ON A DATE
  // ---------------------------------------------------------------------

  /// The `items` table keeps each item's stock RIGHT NOW (row.quantity).
  /// Stock at the end of [asOf] = stock now, minus everything that moved
  /// AFTER that day (IN counts +, OUT counts -). Every row in [items] is
  /// listed, also the ones with zero stock.
  /// [allItems] is only used to find the item of each transaction.
  static List<StockLine> stockAsOf({
    required Iterable<ItemRow> allItems,
    required Iterable<ItemRow> items,
    required Iterable<TransactionModel> transactions,
    required DateTime asOf,
  }) {
    final endExclusive = DateTime(asOf.year, asOf.month, asOf.day + 1);
    final index = ItemIndex(allItems);

    final movedAfter = <String, int>{}; // item row key -> net movement
    for (final tx in transactions) {
      if (tx.timestamp.toLocal().isBefore(endExclusive)) continue;
      final row = index.forTx(tx);
      if (row == null) continue;
      movedAfter[row.key] = (movedAfter[row.key] ?? 0) + tx.stockEffect;
    }

    final lines = [
      for (final r in items)
        StockLine(r, r.quantity - (movedAfter[r.key] ?? 0)),
    ];
    lines.sort((a, b) {
      final byCode = a.item.code.compareTo(b.item.code);
      return byCode != 0 ? byCode : a.item.length.compareTo(b.item.length);
    });
    return lines;
  }

  // ---------------------------------------------------------------------
  // building the file
  // ---------------------------------------------------------------------

  /// creates excel file; returns path on mobile/desktop, null on web
  static Future<String?> _buildFile({
    required String fileName,
    required List<String> headers,
    required List<List<xl.CellValue>> rows,
    Set<int> wideColumns = const {},
  }) async {
    final book = xl.Excel.createExcel();
    const sheetName = 'Report';
    book.rename('Sheet1', sheetName);
    final sheet = book[sheetName];

    final headerStyle = xl.CellStyle(
      bold: true,
      fontColorHex: xl.ExcelColor.white,
      backgroundColorHex: xl.ExcelColor.fromHexString('#1F3A5F'),
    );
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      );
      cell.value = xl.TextCellValue(headers[c]);
      cell.cellStyle = headerStyle;
      sheet.setColumnWidth(c, wideColumns.contains(c) ? 28 : 16);
    }

    for (final row in rows) {
      sheet.appendRow(row);
    }

    final bytes = book.encode();
    if (bytes == null) throw Exception('Could not create the Excel file');

    // web: normal browser download
    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: fileName.replaceAll('.xlsx', ''),
        bytes: Uint8List.fromList(bytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      return null;
    }

    // mobile / desktop
    Directory? dir;
    if (Platform.isAndroid) dir = await getExternalStorageDirectory();
    dir ??= await getApplicationDocumentsDirectory();

    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  // ---------------------------------------------------------------------
  // REPORT 1: transaction log
  // ---------------------------------------------------------------------
  static Future<bool> exportAndNotify({
    required BuildContext context,
    required List<TransactionModel> transactions,
    required List<ItemRow> items, // the whole items table
    DateTime? from,
    DateTime? to,
  }) {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final index = ItemIndex(items);
    final keys = propertyKeys(items);

    final headers = [
      'Date',
      'Item ID',
      ...keys,
      'Item stock (now)',
      'Location',
      'Warehouse',
      'Rack',
      'Shelf',
      'Worker',
      'Direction',
      'Quantity',
      'Type',
      'Notes',
    ];

    final sorted = [...transactions]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final rows = <List<xl.CellValue>>[];
    for (final tx in sorted) {
      final item = index.forTx(tx);
      final place = locationParts(tx.locationCode);
      final isIn = tx.direction.toUpperCase() == 'IN';

      rows.add([
        xl.TextCellValue(dateFmt.format(tx.timestamp.toLocal())),
        _cell(item != null ? idOf(item) : tx.itemId),
        for (final k in keys)
          _cell(
            item?.data[k] ??
                (k == 'Item Code' && tx.itemCode.isNotEmpty
                    ? tx.itemCode
                    : null),
          ),
        _cell(item?.quantity),
        xl.TextCellValue(tx.locationCode),
        xl.TextCellValue(place[0]),
        xl.TextCellValue(place[1]),
        xl.TextCellValue(place[2]),
        xl.TextCellValue(tx.stockKeeperId),
        xl.TextCellValue(tx.direction.toUpperCase()),
        xl.IntCellValue(isIn ? tx.quantity : -tx.quantity),
        xl.TextCellValue(englishType(tx.type)),
        // Notes: is this row reversed, or is it a reversal?
        xl.TextCellValue(
          tx.reversed
              ? 'Reversed${tx.reversalId != null ? ' (by ${tx.reversalId})' : ''}'
              : tx.isReversal
              ? 'Reversal of ${tx.reversalOf ?? '-'}'
              : '',
        ),
      ]);
    }

    return _saveAndNotify(
      context: context,
      fileName: fileNameFor(from: from, to: to),
      headers: headers,
      rows: rows,
      wideColumns: {
        headers.indexOf('Location'),
        headers.indexOf('Type'),
        headers.indexOf('Notes'),
      },
    );
  }

  // ---------------------------------------------------------------------
  // REPORT 2: stock on a date (every item, even with zero stock)
  // ---------------------------------------------------------------------
  static Future<bool> exportStockAndNotify({
    required BuildContext context,
    required List<StockLine> lines,
    required List<ItemRow> items, // the whole items table (for the columns)
    required DateTime asOf,
  }) {
    final keys = propertyKeys(items);
    final headers = [
      'Item ID',
      ...keys,
      'Stock (as of ${DateFormat('dd-MM-yyyy').format(asOf)})',
    ];

    final rows = <List<xl.CellValue>>[
      for (final l in lines)
        [
          _cell(idOf(l.item)),
          for (final k in keys) _cell(l.item.data[k]),
          xl.IntCellValue(l.stock),
        ],
    ];

    return _saveAndNotify(
      context: context,
      fileName: stockFileNameFor(asOf),
      headers: headers,
      rows: rows,
    );
  }

  /// Builds the file, then shows the "<file> saved  OPEN" pop-up.
  static Future<bool> _saveAndNotify({
    required BuildContext context,
    required String fileName,
    required List<String> headers,
    required List<List<xl.CellValue>> rows,
    Set<int> wideColumns = const {},
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final path = await _buildFile(
        fileName: fileName,
        headers: headers,
        rows: rows,
        wideColumns: wideColumns,
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.textColorPrimary,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 6),
            content: Text(
              '$fileName saved',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
            action: path == null
                ? null
                : SnackBarAction(
                    label: 'OPEN',
                    textColor: AppTheme.primaryContainer,
                    onPressed: () => OpenFilex.open(path),
                  ),
          ),
        );
      return true;
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
            content: Text(
              'Export failed: $e',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      return false;
    }
  }
}
