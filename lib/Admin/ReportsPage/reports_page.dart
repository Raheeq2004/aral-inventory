import 'package:aral_project/Admin/Models/item_row.dart';
import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:aral_project/Admin/ReportsPage/confirm_export_page.dart';
import 'package:aral_project/Admin/ReportsPage/excel_export_services.dart';
import 'package:aral_project/Admin/ReportsPage/filter_sheets.dart';
import 'package:aral_project/Admin/ReportsPage/item_picker_page.dart';
import 'package:aral_project/Admin/ReportsPage/location_tree.dart';
import 'package:aral_project/Admin/ReportsPage/report_filters.dart';
import 'package:aral_project/Admin/ReportsPage/report_preview.dart';
import 'package:aral_project/Admin/ReportsPage/report_widgets.dart';
import 'package:aral_project/Admin/providers/items_repository.dart';
import 'package:aral_project/Admin/providers/locations_repository.dart';
import 'package:aral_project/Admin/providers/transactions_repository.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';


enum PreviewPlacement { mainPage, confirmPage }

const PreviewPlacement kPreviewPlacement = PreviewPlacement.mainPage;

final DateFormat _dayMonth = DateFormat('d MMM');

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // the SHARED repositories (registered once in main.dart)
  late final ItemsRepository _itemsRepo;
  late final LocationsRepository _locationsRepo;

  ReportKind _kind = ReportKind.log;
  ReportFilters _f = const ReportFilters();
  bool _exporting = false;

  // ---- items: read once, then everything below is derived ONCE ----
  List<ItemRow> _items = const [];
  ItemIndex _index = ItemIndex(const <ItemRow>[]); // transaction -> item row
  ItemCatalog _catalog = ItemCatalog(const <ItemRow>[]); // the picker's index
  // Length chips are STATIC (kStandardLengths); anything else = "Custom".
  List<String> _finishOptions = const []; // from the db (COLOR), sorted
  bool _itemsLoaded = false;
  bool _itemsRefreshing = true;
  String? _itemsError;

  // ---- locations ----
  LocationTree _tree = LocationTree(const <List<String>>[]);

  /// keys of the last items picked (most recent first)
  final List<String> _recentKeys = [];

  @override
  void initState() {
    super.initState();
    _itemsRepo = context.read<ItemsRepository>();
    _locationsRepo = context.read<LocationsRepository>();

    // Paint at once with what the repositories already know...
    final cachedItems = _itemsRepo.cachedAll;
    if (cachedItems != null) {
      _useItems(cachedItems);
      _itemsLoaded = true;
    }
    final cachedPlaces = _locationsRepo.cachedParts;
    if (cachedPlaces != null) _tree = LocationTree(cachedPlaces);

    // ...then refresh (the stock numbers change all the time).
    _refreshItems();
    _refreshLocations();
  }

  Future<void> _refreshItems() async {
    if (!_itemsRefreshing) setState(() => _itemsRefreshing = true);
    try {
      final rows = await _itemsRepo.loadAll();
      if (!mounted) return;
      setState(() {
        _useItems(rows);
        _itemsLoaded = true;
        _itemsRefreshing = false;
        _itemsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _itemsRefreshing = false;
        _itemsError = '$e';
      });
    }
  }

  Future<void> _refreshLocations() async {
    try {
      final parts = await _locationsRepo.loadParts();
      if (!mounted) return;
      setState(() => _tree = LocationTree(parts));
    } catch (_) {
      // not fatal: the Location sheet falls back to the codes that appear
      // in the transactions (see _treeFor)
    }
  }

  /// Everything that depends only on the items table: computed ONCE here,
  /// never inside build().
  void _useItems(List<ItemRow> rows) {
    _items = rows;
    _index = ItemIndex(rows);
    _catalog = ItemCatalog(rows);

    final finishes = <String>{};
    for (final r in rows) {
      if (r.color.trim().isNotEmpty) finishes.add(r.color);
    }
    _finishOptions = finishes.toList()..sort(naturalCompare);
  }

  // ---------------------------------------------------------------------
  // filtering
  // ---------------------------------------------------------------------

  /// A shelf from a location code can be "7" or "07": always 2 digits.
  static String _padShelf(String s) =>
      int.tryParse(s) != null ? s.padLeft(2, '0') : s;

  bool _matchesTx(
    TransactionModel tx,
    ReportFilters f,
    DateTime start,
    DateTime endExclusive,
  ) {
    final t = tx.timestamp.toLocal(); // Jordan time, not UTC
    if (t.isBefore(start) || !t.isBefore(endExclusive)) return false;

    final dir = tx.direction.toUpperCase();
    if (f.operations == Operations.inOnly && dir != 'IN') return false;
    if (f.operations == Operations.outOnly && dir != 'OUT') return false;
    if (f.worker != null && tx.stockKeeperId != f.worker) return false;

    // item code + length + finish: from the row in the items table when we
    // can find it, otherwise from the transaction itself
    final row = _index.forTx(tx);
    final code = row?.code ?? tx.itemCode;
    final length = row?.length ?? tx.length;
    final color = row?.color ?? tx.color;

    if (f.items.isNotEmpty) {
      final picked = f.items.any(
        (item) => row != null
            ? row.key == item.key
            : code == item.code && sameLength(length, item.length),
      );
      if (!picked) return false;
    }
    if (!f.matchesLength(length)) return false;
    if (!f.matchesFinish(color)) return false;

    if (f.hasLocation) {
      final p = ExcelExportService.locationParts(tx.locationCode);
      if (f.warehouse != null && p[0] != f.warehouse) return false;
      if (f.rack != null && p[1] != f.rack) return false;
      if (f.shelf != null && _padShelf(p[2]) != f.shelf) return false;
    }
    return true;
  }

  List<TransactionModel> _logRows(List<TransactionModel> all, ReportFilters f) {
    final range = f.dateRange(DateTime.now());
    final start = range.start;
    final end = DateTime(range.end.year, range.end.month, range.end.day + 1);
    return all.where((tx) => _matchesTx(tx, f, start, end)).toList();
  }

  bool _matchesRow(ItemRow r, ReportFilters f) {
    if (f.items.isNotEmpty && !f.items.any((i) => i.key == r.key)) {
      return false;
    }
    if (!f.matchesLength(r.length)) return false;
    if (!f.matchesFinish(r.color)) return false;
    return true;
  }

  /// "How many rows would these filters give?" (for the sheet buttons)
  int _countFor(ReportFilters f) {
    if (_kind == ReportKind.stock) {
      var n = 0;
      for (final r in _items) {
        if (_matchesRow(r, f)) n++;
      }
      return n;
    }
    final all = context.read<TransactionData>().transactionDataList;
    return _logRows(all, f).length;
  }

  /// The [k] newest rows, in ONE pass: O(n·k) instead of sorting everything.
  static List<TransactionModel> _newest(List<TransactionModel> rows, int k) {
    final top = <TransactionModel>[];
    for (final tx in rows) {
      var i = top.length;
      while (i > 0 && top[i - 1].timestamp.isBefore(tx.timestamp)) {
        i--;
      }
      if (i < k) {
        top.insert(i, tx);
        if (top.length > k) top.removeLast();
      }
    }
    return top;
  }

  // ---------------------------------------------------------------------
  // opening the sheets / pages
  // ---------------------------------------------------------------------
  void _apply(ReportFilters? next) {
    if (next != null && mounted) setState(() => _f = next);
  }

  Future<void> _openPeriod() async =>
      _apply(await showPeriodSheet(context, filters: _f, countFor: _countFor));

  Future<void> _openLocation() async {
    final all = context.read<TransactionData>().transactionDataList;
    _apply(
      await showLocationSheet(
        context,
        filters: _f,
        tree: _treeFor(all),
        countFor: _countFor,
      ),
    );
  }

  /// `locations` table; if it could not be read, the codes in the transactions
  LocationTree _treeFor(List<TransactionModel> all) => !_tree.isEmpty
      ? _tree
      : LocationTree(
          all.map((t) => ExcelExportService.locationParts(t.locationCode)),
        );

  Future<void> _openLengthFinish() async => _apply(
    await showLengthFinishSheet(
      context,
      filters: _f,
      lengths: kStandardLengths,
      finishes: _finishOptions,
      countFor: _countFor,
    ),
  );

  Future<void> _openWorker() async {
    final all = context.read<TransactionData>().transactionDataList;
    final workers =
        all
            .map((t) => t.stockKeeperId)
            .where((w) => w.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort(naturalCompare);
    _apply(
      await showWorkerSheet(
        context,
        filters: _f,
        workers: workers,
        countFor: _countFor,
      ),
    );
  }

  Future<void> _openItem() async {
    if (!_itemsLoaded) return;
    final recent = _recentKeys
        .map(_catalog.entryForKey)
        .whereType<ItemEntry>()
        .toList();
    final pick = await Navigator.of(context).push<ItemPick>(
      MaterialPageRoute(
        builder: (_) => ItemPickerPage(
          catalog: _catalog,
          recent: recent,
          selected: _f.items,
        ),
      ),
    );
    if (pick == null || !mounted) return;
    setState(() {
      _f = _f.copyWith(items: pick.rows);
      // the newest picks go first in "Recent" (the list keeps 5)
      for (final row in pick.rows) {
        _recentKeys
          ..remove(row.key)
          ..insert(0, row.key);
      }
      while (_recentKeys.length > 5) {
        _recentKeys.removeLast();
      }
    });
  }

  Future<void> _pickAsOf() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _f.asOfDate(now),
      firstDate: DateTime(2020),
      lastDate: now, // stock in the future makes no sense
    );
    if (picked == null || !mounted) return;
    final isToday = DateUtils.isSameDay(picked, now);
    setState(() => _f = _f.copyWith(asOf: isToday ? null : picked));
  }

  void _resetAll() {
    final before = _f;
    setState(() => _f = const ReportFilters());
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.textColorPrimary,
          duration: const Duration(seconds: 4),
          content: const Text(
            'Filters cleared',
            style: TextStyle(color: Colors.white),
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: const Color(0xFFF7A35C),
            onPressed: () {
              if (mounted) setState(() => _f = before);
            },
          ),
        ),
      );
  }

  // ---------------------------------------------------------------------
  // export
  // ---------------------------------------------------------------------
  Future<void> _export(
    BuildContext ctx, {
    required bool isStock,
    required List<TransactionModel> logRows,
    required List<StockLine> stockLines,
  }) async {
    final now = DateTime.now();
    if (isStock) {
      await ExcelExportService.exportStockAndNotify(
        context: ctx,
        lines: stockLines,
        items: _items,
        asOf: _f.asOfDate(now),
      );
    } else {
      final range = _f.dateRange(now);
      await ExcelExportService.exportAndNotify(
        context: ctx,
        transactions: logRows,
        items: _items,
        from: range.start,
        to: range.end,
      );
    }
  }

  Future<void> _exportHere({
    required bool isStock,
    required List<TransactionModel> logRows,
    required List<StockLine> stockLines,
  }) async {
    setState(() => _exporting = true);
    try {
      await _export(
        context,
        isStock: isStock,
        logRows: logRows,
        stockLines: stockLines,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ---------------------------------------------------------------------
  // the preview (a ReportPreview widget: see report_preview.dart)
  // ---------------------------------------------------------------------
  Widget _buildPreview({
    required bool isStock,
    required List<TransactionModel> logRows,
    required List<StockLine> stockLines,
    required String fileName,
    required int total,
    required int limit,
  }) {
    if (isStock) {
      return ReportPreview(
        fileName: fileName,
        totalRows: total,
        headers: const ['Item', 'Len', 'Stock'],
        columnFlex: const [3, 1, 1.2],
        emptyTitle: 'No items match.',
        emptyHint: 'Try fewer filters.',
        rows: [
          for (final l in stockLines.take(limit))
            [
              l.item.code,
              l.item.length > 0 ? fmtLen(l.item.length) : '',
              '${l.stock}',
            ],
        ],
      );
    }

    return ReportPreview(
      fileName: fileName,
      totalRows: total,
      headers: const ['Date', 'Item', 'Move', 'Qty'],
      columnFlex: const [1.3, 3, 1, 0.9],
      // IN = green, OUT = red
      cellColor: (col, value) => col == 2
          ? (value == 'IN' ? AppTheme.successColor : AppTheme.errorColor)
          : null,
      rows: [
        for (final tx in _newest(logRows, limit))
          [
            _dayMonth.format(tx.timestamp.toLocal()),
            _index.forTx(tx)?.code ?? tx.itemCode,
            tx.direction.toUpperCase(),
            '${tx.quantity}',
          ],
      ],
    );
  }

  // ---------------------------------------------------------------------
  // build
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionData>(
      builder: (context, data, child) {
        final isStock = _kind == ReportKind.stock;
        final all = data.transactionDataList;
        final now = DateTime.now();

        final logRows = isStock
            ? const <TransactionModel>[]
            : _logRows(all, _f);
        final stockLines = isStock
            ? ExcelExportService.stockAsOf(
                allItems: _items,
                items: _items.where((r) => _matchesRow(r, _f)),
                transactions: all,
                asOf: _f.asOfDate(now),
              )
            : const <StockLine>[];

        final total = isStock ? stockLines.length : logRows.length;
        final range = _f.dateRange(now);
        final fileName = isStock
            ? ExcelExportService.stockFileNameFor(_f.asOfDate(now))
            : ExcelExportService.fileNameFor(from: range.start, to: range.end);

        final ready =
            _itemsLoaded &&
            _itemsError == null &&
            !_itemsRefreshing &&
            !data.isLoading;
        final canExport = ready && !_exporting && total > 0;
        final exportLabel = !ready
            ? 'Loading…'
            : isStock
            ? 'Export stock'
            : 'Export ${rowsText(total)}';

        final active = _f.activeCount(_kind);
        final previewOnMain = kPreviewPlacement == PreviewPlacement.mainPage;

        // ONE preview widget; it is placed below, either on this page or on
        // the confirmation page.
        final preview = _buildPreview(
          isStock: isStock,
          logRows: logRows,
          stockLines: stockLines,
          fileName: fileName,
          total: total,
          limit: previewOnMain ? kPreviewRows : kConfirmPreviewRows,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- which report ----
              Row(
                children: [
                  Expanded(
                    child: _KindCard(
                      icon: Icons.swap_horiz_rounded,
                      title: 'Transaction log',
                      subtitle: 'Every IN / OUT',
                      selected: !isStock,
                      onTap: () => setState(() => _kind = ReportKind.log),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KindCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'Stock on a date',
                      subtitle: 'What was in stock',
                      selected: isStock,
                      onTap: () => setState(() => _kind = ReportKind.stock),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ---- All / IN / OUT (log only) ----
              if (!isStock) ...[
                _OperationsSwitch(
                  value: _f.operations,
                  onChanged: (v) =>
                      setState(() => _f = _f.copyWith(operations: v)),
                ),
                const SizedBox(height: 12),
              ],

              // ---- the filter rows ----
              _CardShell(
                child: Column(
                  children: [
                    if (isStock)
                      _FilterRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: _f.asOf == null
                            ? 'Today, ${_dayMonth.format(now)}'
                            : DateFormat('d MMM yyyy').format(_f.asOf!),
                        tone: _f.asOf == null ? _Tone.normal : _Tone.set,
                        onTap: _pickAsOf,
                      )
                    else
                      _FilterRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Period',
                        value: _f.periodValue(now),
                        tone: _f.period == ReportPeriod.thisMonth
                            ? _Tone.normal
                            : _Tone.set,
                        onTap: _openPeriod,
                      ),
                    _FilterRow(
                      icon: Icons.inventory_2_outlined,
                      label: 'Item',
                      value: !_itemsLoaded ? 'Loading…' : _f.itemValue,
                      tone: _f.items.isEmpty ? _Tone.unset : _Tone.set,
                      onTap: _openItem,
                    ),
                    // the stock is kept per item, not per location
                    if (!isStock)
                      _FilterRow(
                        icon: Icons.location_on_outlined,
                        label: 'Location',
                        value: _f.locationValue,
                        tone: _f.hasLocation ? _Tone.set : _Tone.unset,
                        onTap: _openLocation,
                      ),
                    _FilterRow(
                      icon: Icons.straighten,
                      label: 'Length · finish',
                      value: _f.lengthFinishValue,
                      tone: (_f.lengths.isNotEmpty || _f.finishes.isNotEmpty)
                          ? _Tone.set
                          : _Tone.unset,
                      onTap: _openLengthFinish,
                      last: isStock,
                    ),
                    if (!isStock)
                      _FilterRow(
                        icon: Icons.person_outline,
                        label: 'Worker',
                        value: _f.workerValue,
                        tone: _f.worker == null ? _Tone.unset : _Tone.set,
                        onTap: _openWorker,
                        last: true,
                      ),
                  ],
                ),
              ),

              // ---- "N filters on · Reset all" ----
              if (active > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Text(
                        '$active filter${active == 1 ? '' : 's'} on',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _resetAll,
                        child: const Text(
                          'Reset all',
                          style: TextStyle(
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_itemsError != null) ...[
                const SizedBox(height: 12),
                _ErrorCard(message: _itemsError!, onRetry: _refreshItems),
              ],
              const SizedBox(height: 12),

              // ---- preview on THIS page ----
              if (previewOnMain) ...[preview, const SizedBox(height: 12)],

              // ---- export ----
              ExportButton(
                label: exportLabel,
                enabled: canExport,
                busy: _exporting,
                onPressed: previewOnMain
                    ? () => _exportHere(
                        isStock: isStock,
                        logRows: logRows,
                        stockLines: stockLines,
                      )
                    // preview on the CONFIRMATION page: open it
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ConfirmExportPage(
                            preview: preview,
                            buttonLabel: exportLabel,
                            onExport: (ctx) => _export(
                              ctx,
                              isStock: isStock,
                              logRows: logRows,
                              stockLines: stockLines,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =====================================================================
// small widgets of the main page
// =====================================================================

/// White card with the thin border (a Material, so the ripples show).
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.surfaceColor,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppTheme.borderColor),
    ),
    child: child,
  );
}

/// "Transaction log" / "Stock on a date".
/// Selected = ORANGE BORDER only (white background).
class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? AppTheme.secondaryColor : AppTheme.borderColor,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? AppTheme.secondaryColor
                    : AppTheme.textColorSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColorPrimary,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// All / IN / OUT. A selected option is a white pill on a grey track.
class _OperationsSwitch extends StatelessWidget {
  const _OperationsSwitch({required this.value, required this.onChanged});

  final Operations value;
  final ValueChanged<Operations> onChanged;

  static const _labels = {
    Operations.all: 'All',
    Operations.inOnly: 'IN',
    Operations.outOnly: 'OUT',
  };

  Color _colorOf(Operations o) {
    switch (o) {
      case Operations.all:
        return AppTheme.textColorPrimary;
      case Operations.inOnly:
        return AppTheme.successColor;
      case Operations.outOnly:
        return AppTheme.errorColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          for (final o in Operations.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(o),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: o == value ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: o == value
                        ? const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _labels[o]!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: o == value
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: o == value
                          ? _colorOf(o)
                          : AppTheme.textColorSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// How a row's value looks:
///  unset  -> grey ("All items", "Any")
///  normal -> dark, regular (a default that is not a filter: "This month")
///  set    -> BLACK + BOLD (the admin chose something)
enum _Tone { unset, normal, set }

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final _Tone tone;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppTheme.borderColor)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textColorSecondary),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textColorPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: tone == _Tone.set
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: tone == _Tone.unset
                      ? AppTheme.textColorSecondary
                      : AppTheme.textColorPrimary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppTheme.textColorSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.warningContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.warningBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Could not read the items table: $message',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.warningColor,
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}