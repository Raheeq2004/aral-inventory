import 'package:aral_project/Admin/ReportsPage/location_tree.dart';
import 'package:aral_project/Admin/ReportsPage/report_filters.dart';
import 'package:aral_project/Admin/ReportsPage/report_widgets.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// =====================================================================
// The bottom sheets of the Reports page.
//
// Every sheet works on a DRAFT copy of the filters and returns the new
// [ReportFilters] only when the admin applies it. Closing the sheet by
// tapping outside returns null = nothing changes.
// `countFor` is given by the page: it answers "how many rows would this
// draft give?", so the button can say "Show 19 rows" BEFORE closing.
// =====================================================================

typedef CountFor = int Function(ReportFilters draft);

Future<ReportFilters?> _showSheet(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<ReportFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppTheme.surfaceColor,
    builder: builder,
  );
}

Future<ReportFilters?> showPeriodSheet(
  BuildContext context, {
  required ReportFilters filters,
  required CountFor countFor,
}) => _showSheet(
  context,
  (_) => _PeriodSheet(filters: filters, countFor: countFor),
);

Future<ReportFilters?> showLocationSheet(
  BuildContext context, {
  required ReportFilters filters,
  required LocationTree tree,
  required CountFor countFor,
}) => _showSheet(
  context,
  (_) => _LocationSheet(filters: filters, tree: tree, countFor: countFor),
);

Future<ReportFilters?> showLengthFinishSheet(
  BuildContext context, {
  required ReportFilters filters,
  required List<double> lengths,
  required List<String> finishes,
  required CountFor countFor,
}) => _showSheet(
  context,
  (_) => _LengthFinishSheet(
    filters: filters,
    lengths: lengths,
    finishes: finishes,
    countFor: countFor,
  ),
);

Future<ReportFilters?> showWorkerSheet(
  BuildContext context, {
  required ReportFilters filters,
  required List<String> workers,
  required CountFor countFor,
}) => _showSheet(
  context,
  (_) => _WorkerSheet(filters: filters, workers: workers, countFor: countFor),
);

// ---------------------------------------------------------------------
// small pieces shared by the sheets
// ---------------------------------------------------------------------

/// Scrollable column that lifts above the keyboard.
class _Shell extends StatelessWidget {
  const _Shell({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    this.actionLabel = 'Reset',
    this.onAction,
    this.onBack,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (onBack != null) ...[
            InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.arrow_back, size: 20),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textColorPrimary,
              ),
            ),
          ),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: AppTheme.secondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppTheme.textColorSecondary,
      ),
    ),
  );
}

/// One line of a single-choice list (check mark = current choice).
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.chevron = false,
  });

  final String label;
  final bool selected;
  final bool chevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: AppTheme.textColorPrimary,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check, size: 18, color: AppTheme.secondaryColor)
            else if (chevron)
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

/// A box that looks like a field and opens something when tapped.
class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.text,
    required this.filled,
    required this.enabled,
    required this.onTap,
  });

  final String text;
  final bool filled; // a value is chosen (not "All …")
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppTheme.surfaceColor : AppTheme.backgroundColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: filled ? FontWeight.w700 : FontWeight.w400,
                    color: filled
                        ? AppTheme.textColorPrimary
                        : AppTheme.textColorSecondary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: enabled
                    ? AppTheme.textColorSecondary
                    : AppTheme.borderColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A square-ish button of the rack / shelf grids.
class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.secondaryContainer : AppTheme.surfaceColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected
              ? AppTheme.secondaryColor.withValues(alpha: 0.5)
              : AppTheme.borderColor,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? AppTheme.onSecondaryContainer
                  : AppTheme.textColorPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// PERIOD  (screens 3 and 4)
// =====================================================================
class _PeriodSheet extends StatefulWidget {
  const _PeriodSheet({required this.filters, required this.countFor});
  final ReportFilters filters;
  final CountFor countFor;

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  bool _custom = false; // showing the From / To pickers
  late DateTime _from;
  late DateTime _to;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    final range = widget.filters.customRange;
    final now = DateTime.now();
    _from = range?.start ?? DateTime(now.year, now.month, 1);
    _to = range?.end ?? _today;
    if (_to.isAfter(_today)) _to = _today;
    if (_from.isAfter(_to)) _from = _to;
  }

  void _resetToDefault() => Navigator.of(context).pop(
    widget.filters.copyWith(period: ReportPeriod.thisMonth, customRange: null),
  );

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: _to, // "From" can't be after "To"
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from, // "To" can't be before "From"
      lastDate: _today, // ...or after today
    );
    if (d != null) setState(() => _to = d);
  }

  @override
  Widget build(BuildContext context) {
    return _custom ? _customView() : _listView();
  }

  Widget _listView() {
    final current = widget.filters.period;
    return _Shell(
      children: [
        _Header(title: 'Period', onAction: _resetToDefault),
        for (final p in ReportPeriod.values)
          _OptionRow(
            label: kPeriodLabels[p]!,
            selected: p == current,
            chevron: p == ReportPeriod.custom,
            onTap: () {
              if (p == ReportPeriod.custom) {
                setState(() => _custom = true);
              } else {
                // single choice: applies on tap and closes
                Navigator.of(context)
                    .pop(widget.filters.copyWith(period: p, customRange: null));
              }
            },
          ),
      ],
    );
  }

  Widget _customView() {
    final draft = widget.filters.copyWith(
      period: ReportPeriod.custom,
      customRange: DateTimeRange(start: _from, end: _to),
    );
    return _Shell(
      children: [
        _Header(
          title: 'Custom range',
          onBack: () => setState(() => _custom = false),
          onAction: _resetToDefault,
        ),
        Row(
          children: [
            Expanded(
              child: _DateField(label: 'FROM', date: _from, onTap: _pickFrom),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateField(label: 'TO', date: _to, onTap: _pickTo),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '“To” can’t be before “From” or after today.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(draft),
          child: Text('Apply · ${rowsText(widget.countFor(draft))}'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        _FieldButton(
          text:
              '${date.day.toString().padLeft(2, '0')} '
              '${_months[date.month - 1]} ${date.year}',
          filled: true,
          enabled: true,
          onTap: onTap,
        ),
      ],
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];
}

// =====================================================================
// LOCATION  (screens 7, 7a, 7b, 7c): warehouse -> rack -> shelf
// =====================================================================
enum _LocView { main, racks, shelves }

class _LocationSheet extends StatefulWidget {
  const _LocationSheet({
    required this.filters,
    required this.tree,
    required this.countFor,
  });

  final ReportFilters filters;
  final LocationTree tree;
  final CountFor countFor;

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  _LocView _view = _LocView.main;
  String? _wh;
  String? _rack;
  String? _shelf;

  @override
  void initState() {
    super.initState();
    _wh = widget.filters.warehouse;
    _rack = widget.filters.rack;
    _shelf = widget.filters.shelf;
  }

  ReportFilters get _draft =>
      widget.filters.copyWith(warehouse: _wh, rack: _rack, shelf: _shelf);

  void _clearAll() => setState(() {
    _wh = null;
    _rack = null;
    _shelf = null;
  });

  void _back() => setState(() => _view = _LocView.main);

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case _LocView.main:
        return _mainView();
      case _LocView.racks:
        return _racksView();
      case _LocView.shelves:
        return _shelvesView();
    }
  }

  // ---- 7 / 7c ----
  Widget _mainView() {
    final tree = widget.tree;
    final wh = _wh;
    final rack = _rack;
    return _Shell(
      children: [
        _Header(title: 'Location', onAction: _clearAll),
        const _Label('WAREHOUSE'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ReportChip(label: 'All', selected: wh == null, onTap: _clearAll),
            for (final w in tree.warehouses)
              ReportChip(
                label: w,
                selected: wh == w,
                // changing the warehouse clears rack and shelf
                onTap: () => setState(() {
                  _wh = w;
                  _rack = null;
                  _shelf = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _Label(
          wh == null ? 'RACK' : 'RACK · ${tree.racksOf(wh).length} IN $wh',
        ),
        _FieldButton(
          text: rack ?? (wh == null ? 'Choose a warehouse first' : 'All racks'),
          filled: rack != null,
          enabled: wh != null,
          onTap: () => setState(() => _view = _LocView.racks),
        ),
        const SizedBox(height: 16),
        _Label(
          rack == null || wh == null
              ? 'SHELF'
              : 'SHELF · ${tree.shelvesOf(wh, rack).length} IN $rack',
        ),
        _FieldButton(
          text:
              _shelf ?? (rack == null ? 'Choose a rack first' : 'All shelves'),
          filled: _shelf != null,
          enabled: rack != null,
          onTap: () => setState(() => _view = _LocView.shelves),
        ),
        if (wh != null && rack != null && _shelf != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$wh-$rack-$_shelf',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_draft),
          child: Text('Show ${rowsText(widget.countFor(_draft))}'),
        ),
      ],
    );
  }

  // ---- 7a: rack grid (just the rack names: NO shelf counts) ----
  Widget _racksView() {
    final wh = _wh!;
    final groups = <String, List<String>>{};
    for (final r in widget.tree.racksOf(wh)) {
      groups.putIfAbsent(r[0].toUpperCase(), () => []).add(r);
    }
    return _Shell(
      children: [
        _Header(
          title: 'Rack in $wh',
          actionLabel: 'All racks',
          onBack: _back,
          onAction: () => setState(() {
            _rack = null;
            _shelf = null;
            _view = _LocView.main;
          }),
        ),
        for (final g in groups.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 42,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      g.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColorSecondary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in g.value)
                        SizedBox(
                          width: 56,
                          height: 42,
                          child: _GridTile(
                            label: r,
                            selected: r == _rack,
                            onTap: () => setState(() {
                              if (_rack != r) _shelf = null; // new rack
                              _rack = r;
                              _view = _LocView.main;
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---- 7b: shelf grid ----
  Widget _shelvesView() {
    final wh = _wh!;
    final rack = _rack!;
    final shelves = widget.tree.shelvesOf(wh, rack);
    return _Shell(
      children: [
        _Header(
          title: 'Shelf in $rack',
          actionLabel: 'All shelves',
          onBack: _back,
          onAction: () => setState(() {
            _shelf = null;
            _view = _LocView.main;
          }),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppTheme.secondaryColor,
              ),
              const SizedBox(width: 6),
              Text(wh, style: const TextStyle(fontSize: 13)),
              const Icon(Icons.chevron_right, size: 16),
              Text(
                rack,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(Icons.chevron_right, size: 16),
              const Text(
                'shelf?',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textColorSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.3,
          children: [
            for (final s in shelves)
              _GridTile(
                label: s,
                selected: s == _shelf,
                onTap: () => setState(() {
                  _shelf = s;
                  _view = _LocView.main;
                }),
              ),
          ],
        ),
      ],
    );
  }
}

// =====================================================================
// LENGTH AND FINISH  (screen 8) + the CUSTOM length
// =====================================================================
class _LengthFinishSheet extends StatefulWidget {
  const _LengthFinishSheet({
    required this.filters,
    required this.lengths,
    required this.finishes,
    required this.countFor,
  });

  final ReportFilters filters;
  final List<double> lengths;
  final List<String> finishes;
  final CountFor countFor;

  @override
  State<_LengthFinishSheet> createState() => _LengthFinishSheetState();
}

class _LengthFinishSheetState extends State<_LengthFinishSheet> {
  final TextEditingController _custom = TextEditingController();
  double? _length;
  String? _finish;
  bool _customOpen = false;

  @override
  void initState() {
    super.initState();
    _length = widget.filters.length;
    _finish = widget.filters.finish;
    final l = _length;
    // a length that is not one of the chips = it was typed before
    if (l != null && !widget.lengths.any((x) => sameLength(x, l))) {
      _customOpen = true;
      _custom.text = l == l.roundToDouble() ? '${l.toInt()}' : '$l';
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  /// "6.5" or "6,5" -> 6.5.  null if it is not a sensible length.
  static double? _parse(String text) {
    final v = double.tryParse(text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0 || v > 99) return null;
    return v;
  }

  ReportFilters get _draft =>
      widget.filters.copyWith(length: _length, finish: _finish);

  void _chooseLength(double? value) => setState(() {
    _length = value;
    _customOpen = false;
    _custom.clear();
  });

  @override
  Widget build(BuildContext context) {
    final typed = _custom.text.trim();
    return _Shell(
      children: [
        _Header(
          title: 'Length and finish',
          onAction: () {
            _finish = null;
            _chooseLength(null);
          },
        ),
        const _Label('LENGTH'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ReportChip(
              label: 'Any',
              selected: _length == null && !_customOpen,
              onTap: () => _chooseLength(null),
            ),
            for (final l in widget.lengths)
              ReportChip(
                label: fmtLength(l),
                selected:
                    !_customOpen && _length != null && sameLength(l, _length!),
                onTap: () => _chooseLength(l),
              ),
            ReportChip(
              label: 'Custom',
              selected: _customOpen,
              onTap: () => setState(() => _customOpen = true),
            ),
          ],
        ),
        if (_customOpen) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _custom,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: 'Custom length',
              hintText: 'e.g. 6.5',
              suffixText: 'm',
              errorText: typed.isNotEmpty && _length == null
                  ? 'Enter a length like 6.5'
                  : null,
            ),
            onChanged: (t) => setState(() => _length = _parse(t)),
          ),
        ],
        const SizedBox(height: 16),
        const _Label('FINISH'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ReportChip(
              label: 'Any',
              selected: _finish == null,
              onTap: () => setState(() => _finish = null),
            ),
            for (final f in widget.finishes)
              ReportChip(
                label: f,
                selected: _finish == f,
                onTap: () => setState(() => _finish = f),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_draft),
          child: Text('Show ${rowsText(widget.countFor(_draft))}'),
        ),
      ],
    );
  }
}

// =====================================================================
// WORKER  (screen 9)
// =====================================================================
class _WorkerSheet extends StatefulWidget {
  const _WorkerSheet({
    required this.filters,
    required this.workers,
    required this.countFor,
  });

  final ReportFilters filters;
  final List<String> workers;
  final CountFor countFor;

  @override
  State<_WorkerSheet> createState() => _WorkerSheetState();
}

class _WorkerSheetState extends State<_WorkerSheet> {
  String? _worker;

  @override
  void initState() {
    super.initState();
    _worker = widget.filters.worker;
  }

  ReportFilters get _draft => widget.filters.copyWith(worker: _worker);

  @override
  Widget build(BuildContext context) {
    return _Shell(
      children: [
        _Header(
          title: 'Worker',
          onAction: () =>
              Navigator.of(context).pop(widget.filters.copyWith(worker: null)),
        ),
        _OptionRow(
          label: 'Anyone',
          selected: _worker == null,
          onTap: () => setState(() => _worker = null),
        ),
        for (final w in widget.workers)
          _OptionRow(
            label: w,
            selected: _worker == w,
            onTap: () => setState(() => _worker = w),
          ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_draft),
          child: Text('Show ${rowsText(widget.countFor(_draft))}'),
        ),
      ],
    );
  }
}
