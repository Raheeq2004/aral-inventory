import 'dart:io';
import 'dart:typed_data';

import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// One line of the "stock on a date" report: how many units of one item
/// were in one location at the end of the chosen day.
class StockRow {
  final String itemCode;
  final String itemName;
  final String locationCode;
  int quantity;

  StockRow({
    required this.itemCode,
    required this.itemName,
    required this.locationCode,
    required this.quantity,
  });
}

/// build the .xlsx files
class ExcelExportService {
  ExcelExportService._();

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

  /// Stock at the END of the day [asOf]:
  /// for every item + location, add up all IN and subtract all OUT
  /// up to that day. Reversals are normal rows (opposite direction),
  /// so they cancel out by themselves. Lines with 0 units are left out.
  static List<StockRow> stockAsOf(
    Iterable<TransactionModel> transactions,
    DateTime asOf,
  ) {
    final endExclusive = DateTime(asOf.year, asOf.month, asOf.day + 1);
    final lines = <String, StockRow>{};

    for (final tx in transactions) {
      if (!tx.timestamp.toLocal().isBefore(endExclusive)) continue;
      final signed = tx.direction.toUpperCase() == 'IN'
          ? tx.quantity
          : -tx.quantity;
      final key = '${tx.itemCode}|${tx.locationCode}';
      final line = lines.putIfAbsent(
        key,
        () => StockRow(
          itemCode: tx.itemCode,
          itemName: tx.itemName,
          locationCode: tx.locationCode,
          quantity: 0,
        ),
      );
      line.quantity += signed;
    }

    return lines.values.where((l) => l.quantity != 0).toList()..sort((a, b) {
      final byItem = a.itemCode.compareTo(b.itemCode);
      return byItem != 0 ? byItem : a.locationCode.compareTo(b.locationCode);
    });
  }

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

  /// Transaction log (date only, no time, no type column).
  static Future<bool> exportAndNotify({
    required BuildContext context,
    required List<TransactionModel> transactions,
    DateTime? from,
    DateTime? to,
  }) {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final sorted = [...transactions]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final rows = <List<xl.CellValue>>[
      for (final tx in sorted)
        [
          xl.TextCellValue(dateFmt.format(tx.timestamp.toLocal())),
          xl.TextCellValue(tx.itemCode),
          xl.TextCellValue(tx.itemName),
          xl.TextCellValue(tx.locationCode),
          xl.TextCellValue(warehouseOf(tx.locationCode)),
          xl.TextCellValue(tx.stockKeeperId),
          xl.TextCellValue(tx.direction.toUpperCase()),
          xl.IntCellValue(
            tx.direction.toUpperCase() == 'IN' ? tx.quantity : -tx.quantity,
          ),
          xl.TextCellValue(englishType(tx.type)),
          // Notes: is this row reversed, or is it a reversal?
          xl.TextCellValue(
            tx.reversed
                ? 'Reversed${tx.reversalId != null ? ' (by #${tx.reversalId})' : ''}'
                : tx.isReversal
                ? 'Reversal of #${tx.reversalOf ?? '—'}'
                : '',
          ),
        ],
    ];

    return _saveAndNotify(
      context: context,
      fileName: fileNameFor(from: from, to: to),
      headers: const [
        'Date',
        'Item code',
        'Product name',
        'Location',
        'Warehouse',
        'Worker',
        'Direction',
        'Quantity',
        'Type',
        'Notes',
      ],
      rows: rows,
      wideColumns: {2, 3, 8, 9},
    );
  }

  /// Stock on a date (one line per item + location).
  static Future<bool> exportStockAndNotify({
    required BuildContext context,
    required List<StockRow> rows,
    required DateTime asOf,
  }) {
    return _saveAndNotify(
      context: context,
      fileName: stockFileNameFor(asOf),
      headers: const [
        'Item code',
        'Product name',
        'Location',
        'Warehouse',
        'Net movement (IN - OUT)', // NOT real stock yet
      ],
      rows: [
        for (final r in rows)
          [
            xl.TextCellValue(r.itemCode),
            xl.TextCellValue(r.itemName),
            xl.TextCellValue(r.locationCode),
            xl.TextCellValue(warehouseOf(r.locationCode)),
            xl.IntCellValue(r.quantity),
          ],
      ],
      wideColumns: {1, 2},
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