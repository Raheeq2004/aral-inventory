import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:aral_project/Admin/Models/transaction_types.dart'; // shared type list
import 'package:aral_project/Admin/ReportsPage/excel_export_services.dart';
import 'package:aral_project/Admin/providers/transaction_data.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

enum Operations { all, inOnly, outOnly }

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late DateTime _from;
  late DateTime _to;
  Operations operations = Operations.all;
  String? _warehouse; // null = all
  String? _worker; // null = all
  String? _type; // null = all · otherwise a type CODE (e.g. 'issue_out')
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, now.day); // today
  }

  // filtering
  List<TransactionModel> _filter(List<TransactionModel> all) {
    final start = DateTime(_from.year, _from.month, _from.day);
    final endExclusive = DateTime(_to.year, _to.month, _to.day + 1);

    return all.where((tx) {
      final t = tx.timestamp.toLocal();
      if (t.isBefore(start) || !t.isBefore(endExclusive)) return false;

      final dir = tx.direction.toUpperCase();
      if (operations == Operations.inOnly && dir != 'IN') return false;
      if (operations == Operations.outOnly && dir != 'OUT') return false;

      if (_warehouse != null &&
          ExcelExportService.warehouseOf(tx.locationCode) != _warehouse) {
        return false;
      }
      if (_worker != null && tx.workerId != _worker) return false;
      // Compare the NORMALIZED code, so old names ("Purchase Receipt") and
      // new codes ('purchase_receipt') count as the same type.
      if (_type != null &&
          normalizeType(tx.type, tx.direction.toUpperCase()) != _type) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: isFrom ? DateTime(2020) : _from,
      lastDate: isFrom ? _to : DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => isFrom ? _from = picked : _to = picked);
  }

  Future<void> _export(List<TransactionModel> matches) async {
    setState(() => _exporting = true);
    await ExcelExportService.exportAndNotify(
      context: context,
      transactions: matches,
      from: _from,
      to: _to,
    );
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Consumer<TransactionData>(
      builder: (context, data, child) {
        final all = data.transactionDataList;
        final matches = _filter(all);
        final count = NumberFormat('#,##0').format(matches.length);
        final fileName = ExcelExportService.fileNameFor(from: _from, to: _to);
        final canExport = !data.isLoading && !_exporting && matches.isNotEmpty;

        // chip options come from the real data
        final warehouses = _distinct(
          all.map((t) => ExcelExportService.warehouseOf(t.locationCode)),
        );
        final workers = _distinct(all.map((t) => t.workerId));
        // Type chips: the SHARED list (transaction_types.dart), only the
        // types that actually appear in the data, in the list's order.
        final presentTypes = all
            .map((t) => normalizeType(t.type, t.direction.toUpperCase()))
            .toSet();
        final types = allTypeCodes.where(presentTypes.contains).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // title and description
              Text(
                'Export transaction logs',
                style: textTheme.displaySmall?.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                'Create an Excel sheet with product names, locations, '
                'workers, IN/OUT and quantities.',
                style: textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textColorSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // from/to
              Row(
                children: [
                  Expanded(child: _label(context, 'From')),
                  const SizedBox(width: 12),
                  Expanded(child: _label(context, 'To')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateButton(
                      date: _from,
                      onTap: () => _pickDate(isFrom: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateButton(
                      date: _to,
                      onTap: () => _pickDate(isFrom: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // IN / OUT
              _label(context, 'Transactions'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    'All',
                    operations == Operations.all,
                    () => setState(() => operations = Operations.all),
                  ),
                  _chip(
                    'IN only',
                    operations == Operations.inOnly,
                    () => setState(() => operations = Operations.inOnly),
                  ),
                  _chip(
                    'OUT only',
                    operations == Operations.outOnly,
                    () => setState(() => operations = Operations.outOnly),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // warehouse
              _label(context, 'Warehouse'),
              const SizedBox(height: 8),
              _singleSelect(warehouses, _warehouse, (v) => _warehouse = v),
              const SizedBox(height: 24),

              // worker
              _label(context, 'Worker'),
              const SizedBox(height: 8),
              _singleSelect(workers, _worker, (v) => _worker = v),
              const SizedBox(height: 24),

              // transaction type: Arabic labels from the shared list
              _label(context, 'Type'),
              const SizedBox(height: 8),
              _singleSelect(
                types,
                _type,
                (v) => _type = v,
                labelOf: labelForCode, // code → Arabic label
              ),
              const SizedBox(height: 28),

              // summary card
              Card(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.35,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.bar_chart_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.isLoading
                                  ? 'Loading transactions...'
                                  : '$count transactions match',
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // export
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: canExport ? () => _export(matches) : null,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 20),
                  label: Text(_exporting ? 'Exporting...' : 'Export to Excel'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static List<String> _distinct(Iterable<String> values) =>
      values.where((v) => v.trim().isNotEmpty).toSet().toList()..sort();

  /// "All" + one chip per option. Only one can be selected at a time.
  Widget _singleSelect(
    List<String> options,
    String? selected,
    void Function(String?) onChanged, {
    String Function(String)? labelOf, // optional: how to show each option
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _chip('All', selected == null, () => setState(() => onChanged(null))),
      for (final o in options)
        _chip(labelOf?.call(o) ?? o, selected == o, () => setState(() => onChanged(o))),
    ],
  );

  Widget _label(BuildContext context, String text) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppTheme.textColorPrimary,
    ),
  );

  /// Filter chip
  Widget _chip(String label, bool selected, VoidCallback onTap) => FilterChip(
    label: Text(label),
    selected: selected,
    showCheckmark: true,
    backgroundColor: AppTheme.surfaceColor,
    onSelected: (_) => onTap(),
  );
}

class _DateButton extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateButton({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.schedule_rounded, size: 20),
      label: Text(DateFormat('dd MMM yyyy').format(date)),
      style: OutlinedButton.styleFrom(
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textColorPrimary,
        side: const BorderSide(color: AppTheme.borderColor, width: 1.5),
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    );
  }
}