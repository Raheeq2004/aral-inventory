import 'package:aral_project/Admin/ReportsPage/report_filters.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';

/// How many rows the preview table shows on the main page / on the
/// confirmation page.
const int kPreviewRows = 4;
const int kConfirmPreviewRows = 10;

// =====================================================================
// THE PREVIEW  (file card + first rows of the file)
// =====================================================================
// This widget is SELF-CONTAINED: it only gets plain data (texts) and uses
// nothing from the page. That is what makes it movable: put it in the main
// page, in the confirmation page, or anywhere else, with no other change.
// =====================================================================
class ReportPreview extends StatelessWidget {
  const ReportPreview({
    super.key,
    required this.fileName,
    required this.totalRows,
    required this.headers,
    required this.rows,
    this.columnFlex,
    this.cellColor,
    this.emptyTitle = 'No transactions match.',
    this.emptyHint = 'Try a longer period or fewer filters.',
  });

  final String fileName;

  /// ALL rows of the file (the table only shows [rows], the first ones).
  final int totalRows;
  final List<String> headers;
  final List<List<String>> rows;

  /// Relative width of each column (same length as [headers]).
  final List<double>? columnFlex;

  /// Optional colour of one cell (e.g. IN = green, OUT = red).
  final Color? Function(int column, String value)? cellColor;

  final String emptyTitle;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final more = totalRows - rows.length;

    return Material(
      color: AppTheme.surfaceColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- file card ----
            Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: AppTheme.successColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(rowsText(totalRows), style: textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),

            // ---- nothing matches (screen 13) ----
            if (totalRows == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    Text(
                      emptyTitle,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      emptyHint,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              )
            else ...[
              // ---- the table ----
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Table(
                  columnWidths: {
                    for (var i = 0; i < headers.length; i++)
                      i: FlexColumnWidth(columnFlex?[i] ?? 1),
                  },
                  border: TableBorder.all(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  children: [
                    // header = BLUE (primaryContainer)
                    TableRow(
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryContainer,
                      ),
                      children: [
                        for (final h in headers)
                          _cell(h, header: true, color: null),
                      ],
                    ),
                    for (final row in rows)
                      TableRow(
                        children: [
                          for (var c = 0; c < row.length; c++)
                            _cell(row[c], color: cellColor?.call(c, row[c])),
                        ],
                      ),
                  ],
                ),
              ),
              if (more > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text(
                      '+ ${fmtCount(more)} more rows',
                      style: textTheme.bodySmall,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, {bool header = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: header || color != null
              ? FontWeight.w700
              : FontWeight.w500,
          color: header
              ? AppTheme.onPrimaryContainer
              : (color ?? AppTheme.textColorPrimary),
        ),
      ),
    );
  }
}
