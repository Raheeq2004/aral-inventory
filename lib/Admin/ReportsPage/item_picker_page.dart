import 'dart:async';

import 'package:aral_project/Admin/Models/item_row.dart';
import 'package:aral_project/Admin/ReportsPage/report_filters.dart';
import 'package:aral_project/Admin/ReportsPage/report_widgets.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';

// =====================================================================
// WHY THIS IS FAST (the old drop-down was slow)
// =====================================================================
// Old: DropdownMenu built ~2,700 menu entries (widgets) at once, every
//      time the page rebuilt, and sorted the codes with a RegExp
//      comparator inside build().
//
// New:
//  1. [ItemCatalog] is built ONCE when the items arrive:
//       sort O(n log n), index by family O(n), lower-case copy O(n).
//  2. Opening the picker costs O(1): it just receives the catalog.
//  3. The list is a SliverFixedExtentList: Flutter builds ONLY the ~15
//     rows on screen, and (fixed row height) never measures the others.
//     Scrolling = O(visible rows), no matter if there are 2,700 or 27,000.
//  4. Family chip  = O(1) lookup in a Map.
//  5. Search       = O(n·m) plain `contains` on the lower-cased codes
//                    (n ≈ 2,700 → well under a millisecond), run once
//                    per 300 ms pause in typing, not once per key press.
// =====================================================================

/// One searchable item: the row + everything we need pre-computed.
class ItemEntry {
  ItemEntry(this.row)
    : code = row.code,
      lower = row.code.toLowerCase(),
      family = row.code.length <= 5 ? row.code : row.code.substring(0, 5);

  final ItemRow row;
  final String code;
  final String lower; // lower-case copy, so search never calls toLowerCase
  final String family; // first 5 letters of the code: 1MFMF, 2MFMF, 1BMBM…

  double get length => row.length;
}

/// The result of the picker. `ItemPick(null)` = "Clear" (all items);
/// closing the picker with the back arrow returns null = no change.
class ItemPick {
  const ItemPick(this.row);
  final ItemRow? row;
}

/// The search index over the rows of `ItemsRepository.loadAll()`.
class ItemCatalog {
  ItemCatalog(Iterable<ItemRow> rows) {
    for (final r in rows) {
      if (r.code.isEmpty) continue;
      entries.add(ItemEntry(r));
    }
    entries.sort((a, b) {
      final c = a.code.compareTo(b.code);
      return c != 0 ? c : a.length.compareTo(b.length);
    });
    for (final e in entries) {
      _byFamily.putIfAbsent(e.family, () => []).add(e); // stays sorted
      _byKey[e.row.key] = e;
    }
    // biggest families first (they become the chips)
    families = _byFamily.keys.toList()
      ..sort((a, b) {
        final c = _byFamily[b]!.length.compareTo(_byFamily[a]!.length);
        return c != 0 ? c : a.compareTo(b);
      });
  }

  final List<ItemEntry> entries = [];
  final Map<String, List<ItemEntry>> _byFamily = {};
  final Map<String, ItemEntry> _byKey = {};
  late final List<String> families;

  ItemEntry? entryForKey(String key) => _byKey[key];

  /// Case-insensitive "contains". Do NOT modify the returned list.
  List<ItemEntry> search(String query, {String? family}) {
    final base = family == null
        ? entries
        : (_byFamily[family] ?? const <ItemEntry>[]);
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return base; // O(1)
    return [
      for (final e in base)
        if (e.lower.contains(q)) e,
    ];
  }
}

/// Full-screen "Choose item" page. Pops with an [ItemPick].
class ItemPickerPage extends StatefulWidget {
  const ItemPickerPage({
    super.key,
    required this.catalog,
    required this.recent,
    this.selected,
  });

  final ItemCatalog catalog;
  final List<ItemEntry> recent;
  final ItemRow? selected;

  @override
  State<ItemPickerPage> createState() => _ItemPickerPageState();
}

class _ItemPickerPageState extends State<ItemPickerPage> {
  static const double _rowHeight = 48;
  static const int _chipCount = 3; // chips before the "+N"

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  String _query = ''; // the query the list is showing right now
  String? _family;
  bool _allFamilies = false;
  late List<ItemEntry> _results = widget.catalog.search('');

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    setState(() {}); // only to show / hide the clear (x) button
    _debounce = Timer(const Duration(milliseconds: 300), _applyQuery);
  }

  void _applyQuery() {
    if (!mounted) return;
    setState(() {
      _query = _controller.text.trim();
      // chips are hidden while typing, so the family is ignored then
      _results = widget.catalog.search(
        _query,
        family: _query.isEmpty ? _family : null,
      );
    });
  }

  void _setFamily(String? family) {
    setState(() {
      _family = family;
      _results = widget.catalog.search('', family: family);
    });
  }

  void _clearText() {
    _debounce?.cancel();
    _controller.clear();
    _applyQuery();
  }

  void _pick(ItemRow? row) => Navigator.of(context).pop(ItemPick(row));

  @override
  Widget build(BuildContext context) {
    final searching = _query.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose item'),
        actions: [
          if (widget.selected != null)
            TextButton(
              onPressed: () => _pick(null),
              child: const Text(
                'Clear',
                style: TextStyle(
                  color: AppTheme.secondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: Center(
              child: Text(
                '${fmtCount(_results.length)} items',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'Search code…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _clearText,
                      ),
              ),
            ),
          ),
          if (!searching) _familyChips(),
          Expanded(child: _list(searching)),
        ],
      ),
    );
  }

  Widget _familyChips() {
    final all = widget.catalog.families;
    final shown = _allFamilies
        ? all
        : <String>{
            ...all.take(_chipCount),
            if (_family != null) _family!,
          }.toList();
    final hidden = all.length - shown.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ReportChip(
              label: 'All',
              selected: _family == null,
              onTap: () => _setFamily(null),
            ),
            for (final f in shown)
              ReportChip(
                label: f,
                selected: _family == f,
                onTap: () => _setFamily(f),
              ),
            if (hidden > 0)
              ReportChip(
                label: '+$hidden',
                selected: false,
                onTap: () => setState(() => _allFamilies = true),
              ),
            if (_allFamilies && all.length > _chipCount)
              ReportChip(
                label: 'Less',
                selected: false,
                onTap: () => setState(() => _allFamilies = false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _list(bool searching) {
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No items match $_query. Check the code.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final showRecent =
        !searching && _family == null && widget.recent.isNotEmpty;
    final n = _results.length;
    final title = searching
        ? (n == 1 ? '1 MATCH' : '${fmtCount(n)} MATCHES')
        : (_family ?? 'ALL ITEMS');

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (showRecent) ...[
          _header('RECENT'),
          SliverToBoxAdapter(
            child: Column(
              children: [for (final e in widget.recent) _tile(e, recent: true)],
            ),
          ),
        ],
        _header(title),
        SliverFixedExtentList(
          itemExtent: _rowHeight,
          delegate: SliverChildBuilderDelegate(
            (context, i) => _tile(_results[i]),
            childCount: _results.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  SliverToBoxAdapter _header(String text) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppTheme.textColorSecondary,
        ),
      ),
    ),
  );

  Widget _tile(ItemEntry e, {bool recent = false}) {
    final isSelected = widget.selected?.key == e.row.key;
    return InkWell(
      onTap: () => _pick(e.row),
      child: Container(
        height: _rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
        ),
        child: Row(
          children: [
            if (recent) ...[
              const Icon(
                Icons.history,
                size: 16,
                color: AppTheme.textColorSecondary,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: _highlighted(e)),
            if (e.length > 0)
              Text(
                fmtLength(e.length),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 18, color: AppTheme.secondaryColor),
            ],
          ],
        ),
      ),
    );
  }

  /// The code with the typed part marked (peach background).
  Widget _highlighted(ItemEntry e) {
    final base = Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 15);
    final q = _query.toLowerCase();
    final i = q.isEmpty ? -1 : e.lower.indexOf(q);
    if (i < 0) {
      return Text(
        e.code,
        style: base,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: e.code.substring(0, i)),
          TextSpan(
            text: e.code.substring(i, i + q.length),
            style: const TextStyle(
              backgroundColor: AppTheme.secondaryContainer,
              color: AppTheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: e.code.substring(i + q.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
