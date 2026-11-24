import 'package:aral_project/Admin/Models/item_row.dart';
import 'package:aral_project/StockKeeper/models/scan_labels.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';

/// "Which length?" — shown when one item code has several rows in `items`
/// (e.g. 1BMBM010-AR801 at 5 m, 6 m and 7 m). The QR only holds the code,
/// so the keeper tells us the length of the bar in their hands.
///
/// Returns the chosen [ItemRow], or null if the sheet was closed.
///
/// Usage:  final row = await showLengthPicker(context, code, rows);
Future<ItemRow?> showLengthPicker(
  BuildContext context,
  String code,
  List<ItemRow> rows,
) {
  // showModalBottomSheet returns a Future that completes with the value
  // given to Navigator.pop(context, value) inside the sheet.
  return showModalBottomSheet<ItemRow>(
    context: context,
    showDragHandle: true, // the small grey bar on top
    isScrollControlled: true, // lets the sheet grow for many lengths
    builder: (context) => _LengthPicker(code: code, rows: rows),
  );
}

class _LengthPicker extends StatelessWidget {
  const _LengthPicker({required this.code, required this.rows});

  final String code;
  final List<ItemRow> rows;

  @override
  Widget build(BuildContext context) {
    // How many rows share each length? 2+ = a DUPLICATE in the database
    // (same code AND same length). We still show both, with a warning,
    // so the keeper chooses knowingly instead of the app picking silently.
    final countByLength = <double, int>{};
    for (final r in rows) {
      // update(key, change, ifAbsent): +1 if the length is already there,
      // otherwise start at 1.
      countByLength.update(r.length, (n) => n + 1, ifAbsent: () => 1);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // only as tall as its content
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Which length?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '$code comes in ${countByLength.length} lengths. '
              'Choose the length of the bar you are holding.',
              style: const TextStyle(color: AppTheme.textColorSecondary),
            ),
            const SizedBox(height: 14),
            // Flexible + ListView: the list scrolls if there are many lengths
            // (one code has 9!) instead of overflowing the screen.
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final duplicate = (countByLength[r.length] ?? 0) > 1;
                  return _LengthTile(
                    length: lengthText(r.length),
                    stock: r.quantity,
                    duplicate: duplicate,
                    // Navigator.pop with a value → it becomes the result
                    // of showLengthPicker(...)
                    onTap: () => Navigator.pop(context, r),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LengthTile extends StatelessWidget {
  const _LengthTile({
    required this.length,
    required this.stock,
    required this.duplicate,
    required this.onTap,
  });

  final String length;
  final int stock;
  final bool duplicate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: duplicate ? AppTheme.warningBorder : AppTheme.borderColor,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.straighten, color: AppTheme.textColorSecondary),
              const SizedBox(width: 12),
              Text(
                length,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (duplicate) ...[
                const SizedBox(width: 8),
                // Small cream badge: "this length exists twice"
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warningContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⚠ duplicate',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.warningColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(), // pushes the stock to the right
              Text(
                '$stock pcs',
                style: const TextStyle(color: AppTheme.textColorSecondary),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppTheme.textColorSecondary),
            ],
          ),
        ),
      ),
    );
  }
}