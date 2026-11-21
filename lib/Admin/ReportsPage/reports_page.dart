import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:aral_project/Admin/ReportsPage/excel_export_services.dart';
import 'package:aral_project/Admin/ReportsPage/warehouse_locations.dart';
import 'package:aral_project/Admin/providers/transactions_repository.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

enum ReportKind { log, stock }

enum Operations { all, inOnly, outOnly }

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late DateTime _from;
  late DateTime _to;
  late DateTime _asOf; // "stock on a date"
  ReportKind _kind = ReportKind.log;
  Operations operations = Operations.all;
  String? _item; // item code, null = all items
  String? _warehouse; // null = all
  String? _rack; // null = all (only when a warehouse is picked)
  String? _shelf; // null = all (only when a rack is picked)
  String? _worker; // null = all
  bool _exporting = false;
  List<List<String>> _dbPlaces = []; // [warehouse, rack, shelf] from the db

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, now.day); // today
    _asOf = _to;
    // all locations of the db (even ones without transactions)
    WarehouseLocations.loadParts().then((v) {
      if (mounted) setState(() => _dbPlaces = v);
    });
  }

  // ---------------------------------------------------------------------
  // filtering
  // ---------------------------------------------------------------------
  bool _matchesItem(TransactionModel tx) =>
      _item == null || tx.itemCode == _item;

  /// warehouse / rack / shelf are read from the location code column
  bool _matchesPlace(TransactionModel tx) {
    final p = ExcelExportService.locationParts(tx.locationCode);
    if (_warehouse != null && p[0] != _warehouse) return false;
    if (_rack != null && p[1] != _rack) return false;
    if (_shelf != null && p[2] != _shelf) return false;
    return true;
  }

  List<TransactionModel> _filterLog(List<TransactionModel> all) {
    final start = DateTime(_from.year, _from.month, _from.day);
    final endExclusive = DateTime(_to.year, _to.month, _to.day + 1);

    return all.where((tx) {
      final t = tx.timestamp.toLocal();
      if (t.isBefore(start) || !t.isBefore(endExclusive)) return false;

      final dir = tx.direction.toUpperCase();
      if (operations == Operations.inOnly && dir != 'IN') return false;
      if (operations == Operations.outOnly && dir != 'OUT') return false;

      if (!_matchesItem(tx) || !_matchesPlace(tx)) return false;
      if (_worker != null && tx.stockKeeperId != _worker) return false;
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

  Future<void> _pickAsOf() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOf,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // stock in the future makes no sense
    );
    if (picked == null) return;
    setState(() => _asOf = picked);
  }

  Future<void> _export(
    List<TransactionModel> logRows,
    List<StockRow> stockRows,
  ) async {
    setState(() => _exporting = true);
    if (_kind == ReportKind.stock) {
      await ExcelExportService.exportStockAndNotify(
        context: context,
        rows: stockRows,
        asOf: _asOf,
      );
    } else {
      await ExcelExportService.exportAndNotify(
        context: context,
        transactions: logRows,
        from: _from,
        to: _to,
      );
    }
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Consumer<TransactionData>(
      builder: (context, data, child) {
        final all = data.transactionDataList;
        final isStock = _kind == ReportKind.stock;

        final logRows = isStock ? <TransactionModel>[] : _filterLog(all);
        final stockRows = isStock
            ? ExcelExportService.stockAsOf(
                all.where((t) => _matchesItem(t) && _matchesPlace(t)),
                _asOf,
              )
            : <StockRow>[];

        final matchCount = isStock ? stockRows.length : logRows.length;
        final count = NumberFormat('#,##0').format(matchCount);
        final fileName = isStock
            ? ExcelExportService.stockFileNameFor(_asOf)
            : ExcelExportService.fileNameFor(from: _from, to: _to);
        final canExport = !data.isLoading && !_exporting && matchCount > 0;

        // ---- filter options, read from the data columns ----
        // items: code -> name
        final itemNames = <String, String>{};
        for (final t in all) {
          if (t.itemCode.trim().isEmpty) continue;
          itemNames.putIfAbsent(t.itemCode, () => t.itemName);
        }
        final itemCodes = itemNames.keys.toList()..sort();

        // location: db rows + codes seen in transactions, read as
        // [warehouse, rack, shelf]. Rack / shelf lists narrow down
        // when a warehouse / rack is picked, but are always shown.
        final places = [
          ..._dbPlaces,
          ...all.map((t) => ExcelExportService.locationParts(t.locationCode)),
        ];
        final warehouses = _distinct(places.map((p) => p[0]));
        final racks = _distinct(
          places
              .where((p) => _warehouse == null || p[0] == _warehouse)
              .map((p) => p[1]),
        );
        final shelves = _distinct(
          places
              .where(
                (p) =>
                    (_warehouse == null || p[0] == _warehouse) &&
                    (_rack == null || p[1] == _rack),
              )
              .map((p) => p[2]),
        );
        final workers = _distinct(all.map((t) => t.stockKeeperId));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // title and description
              Text(
                isStock ? 'Stock on a date' : 'Export transaction logs',
                style: textTheme.displaySmall?.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                isStock
                    ? 'TEMPORARY: shows net movement (IN - OUT) up to the '
                          'chosen day, not the real stock balance yet.'
                    : 'Create an Excel sheet with product names, locations, '
                          'workers, IN/OUT and quantities.',
                style: textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textColorSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // which report
              _label(context, 'Report'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    'Transaction log',
                    !isStock,
                    () => setState(() => _kind = ReportKind.log),
                  ),
                  _chip(
                    'Stock on a date',
                    isStock,
                    () => setState(() => _kind = ReportKind.stock),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // dates
              if (isStock) ...[
                _label(context, 'As of'),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: _DateButton(date: _asOf, onTap: _pickAsOf),
                ),
              ] else ...[
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
              ],
              const SizedBox(height: 24),

              // IN / OUT (log only)
              if (!isStock) ...[
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
              ],

              // one item (drop-down with search)
              _label(context, 'Item'),
              const SizedBox(height: 8),
              _itemPicker(itemCodes, itemNames),
              const SizedBox(height: 24),

              // warehouse -> rack -> shelf
              _label(context, 'Warehouse'),
              const SizedBox(height: 8),
              _singleSelect(warehouses, _warehouse, (v) {
                _warehouse = v;
                _rack = null; // old rack / shelf may not exist here
                _shelf = null;
              }),
              const SizedBox(height: 24),
              _label(context, 'Rack'),
              const SizedBox(height: 8),
              _singleSelect(racks, _rack, (v) {
                _rack = v;
                _shelf = null;
              }),
              const SizedBox(height: 24),
              _label(context, 'Shelf'),
              const SizedBox(height: 8),
              _singleSelect(shelves, _shelf, (v) => _shelf = v),
              const SizedBox(height: 24),

              // worker (log only)
              if (!isStock) ...[
                _label(context, 'Worker'),
                const SizedBox(height: 8),
                _singleSelect(workers, _worker, (v) => _worker = v),
                const SizedBox(height: 24),
              ],
              const SizedBox(height: 4),

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
                                  : isStock
                                  ? '$count stock lines'
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
                  onPressed: canExport
                      ? () => _export(logRows, stockRows)
                      : null,
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
      values.where((v) => v.trim().isNotEmpty).toSet().toList()..sort(_natural);

  /// A2 before A10 (instead of A10 before A2)
  static int _natural(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final pa = re.allMatches(a).map((m) => m[0]!).toList();
    final pb = re.allMatches(b).map((m) => m[0]!).toList();
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      final nx = int.tryParse(pa[i]);
      final ny = int.tryParse(pb[i]);
      final c = (nx != null && ny != null)
          ? nx.compareTo(ny)
          : pa[i].compareTo(pb[i]);
      if (c != 0) return c;
    }
    return pa.length.compareTo(pb.length);
  }

  /// "All" + one chip per option. Only one can be selected at a time.
  Widget _singleSelect(
    List<String> options,
    String? selected,
    void Function(String?) onChanged,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _chip('All', selected == null, () => setState(() => onChanged(null))),
      for (final o in options)
        _chip(o, selected == o, () => setState(() => onChanged(o))),
    ],
  );

  /// Drop-down list you can type in to search (by item code OR name).
  Widget _itemPicker(List<String> codes, Map<String, String> names) {
    return DropdownMenu<String?>(
      expandedInsets: EdgeInsets.zero, // full width
      initialSelection: _item,
      enableFilter: true,
      requestFocusOnTap: true, // lets the user type
      hintText: 'Search item code or name',
      leadingIcon: const Icon(Icons.search),
      menuHeight: 320,
      // "contains" search on the whole label (code + name)
      filterCallback: (entries, filter) {
        final q = filter.trim().toLowerCase();
        if (q.isEmpty) return entries;
        return entries.where((e) => e.label.toLowerCase().contains(q)).toList();
      },
      onSelected: (value) => setState(() => _item = value),
      dropdownMenuEntries: [
        const DropdownMenuEntry<String?>(value: null, label: 'All items'),
        for (final code in codes)
          DropdownMenuEntry<String?>(
            value: code,
            label: (names[code] ?? '').trim().isEmpty
                ? code
                : '$code  ·  ${names[code]}',
          ),
      ],
    );
  }

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
