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

/// build the .xlsx file
class ExcelExportService {
  ExcelExportService._();

  /// Location codes look like "WH1-A1-01" (or "WH1 / A1 / 01").
  /// Warehouse = the first part, split on dashes, slashes or spaces.
  static String warehouseOf(String locationCode) {
    final parts = locationCode
        .trim()
        .split(RegExp(r'[\s/\-]+'))
        .where((p) => p.isNotEmpty);
    return parts.isEmpty ? '' : parts.first.toUpperCase();
  }

  /// transactions_17-10-2026.xlsx
  /// transactions_01-10_17-10-2026.xlsx
  static String fileNameFor({DateTime? from, DateTime? to}) {
    final day = DateFormat('dd-MM');
    final full = DateFormat('dd-MM-yyyy');
    if (from == null || to == null) {
      return 'transactions_${full.format(DateTime.now())}.xlsx';
    }
    final sameDay =
        from.year == to.year && from.month == to.month && from.day == to.day;
    if (sameDay) return 'transactions_${full.format(to)}.xlsx';
    return 'transactions_${day.format(from)}_${full.format(to)}.xlsx';
  }

  /// creates excel file; returns path on mobile/desktop, null on web
  static Future<String?> _buildFile(
    List<TransactionModel> transactions,
    String fileName,
  ) async {
    final book = xl.Excel.createExcel();
    const sheetName = 'Transactions';
    book.rename('Sheet1', sheetName);
    final sheet = book[sheetName];

    final headers = [
      'Date & time',
      'Item code',
      'Product name',
      'Location',
      'Warehouse',
      'Worker',
      'Direction',
      'Quantity',
      'Type',
    ];

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
      sheet.setColumnWidth(c, c == 2 || c == 3 ? 28 : 16);
    }

    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final sorted = [...transactions]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final tx in sorted) {
      final isIn = tx.direction.toUpperCase() == 'IN';
      sheet.appendRow([
        xl.TextCellValue(dateFmt.format(tx.timestamp.toLocal())),
        xl.TextCellValue(tx.itemCode),
        xl.TextCellValue(tx.itemName),
        xl.TextCellValue(tx.locationCode),
        xl.TextCellValue(warehouseOf(tx.locationCode)),
        xl.TextCellValue(tx.workerId),
        xl.TextCellValue(tx.direction.toUpperCase()),
        xl.IntCellValue(isIn ? tx.quantity : -tx.quantity),
        xl.TextCellValue(tx.type),
      ]);
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

  static Future<bool> exportAndNotify({
    required BuildContext context,
    required List<TransactionModel> transactions,
    DateTime? from,
    DateTime? to,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final fileName = fileNameFor(from: from, to: to);

    try {
      final path = await _buildFile(transactions, fileName);
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
