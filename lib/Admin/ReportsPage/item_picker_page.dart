import 'dart:async';
import 'package:aral_project/Admin/Models/item_row.dart';
import 'package:aral_project/Admin/ReportsPage/report_filters.dart';
import 'package:aral_project/Admin/ReportsPage/report_widgets.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';


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

/// The result of the picker: every item the admin ticked.
/// An empty list = "all items"; closing with the back arrow returns
/// null = no change.
class ItemPick {
  const ItemPick(this.rows);
  final List<ItemRow> rows;
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

/// Full-screen "Choose item" page (MULTIPLE choice). Pops with an [ItemPick].
class ItemPickerPage extends StatefulWidget {
  const ItemPickerPage({
    super.key,
    required this.catalog,
    required this.recent,
    this.selected = const [],
  });

  final ItemCatalog catalog;
  final List<ItemEntry> recent;
  final List<ItemRow> selected;

  @override
  State<ItemPickerPage> createState() => _ItemPickerPageState();
}

class _ItemPickerPageState extends State<ItemPickerPage> {
  static const double _rowHeight = 48;
  static const int _chipCount = 3; // chips before the "+N more"
  static const double _expandedChipsMaxHeight = 176;

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  String _query = ''; // the query the list is showing right now
  String? _family;
  bool _allFamilies = false;
  late List<ItemEntry> _results = widget.catalog.search('');

  /// Ticked items: key -> row (keeps the order they were ticked in).
  late final Map<String, ItemRow> _picked = {
    for (final r in widget.selected) r.key: r,
  };

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

  void _toggle(ItemRow row) => setState(() {
    if (_picked.remove(row.key) == null) _picked[row.key] = row;
  });

  bool get _allShownPicked =>
      _results.isNotEmpty &&
      _results.every((e) => _picked.containsKey(e.row.key));

  /// "Select all" for the rows now on screen (only offered for a narrowed
  /// list: a family or a search, never the whole 2,700).
  void _toggleAllShown() => setState(() {
    if (_allShownPicked) {
      for (final e in _results) {
        _picked.remove(e.row.key);
      }
    } else {
      for (final e in _results) {
        _picked[e.row.key] = e.row;
      }
    }
  });

  void _done() => Navigator.of(context).pop(ItemPick(_picked.values.toList()));

  @override
  Widget build(BuildContext context) {
    final searching = _query.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose items'),
        actions: [
          if (_picked.isNotEmpty)
            TextButton(
              onPressed: () => setState(_picked.clear),
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
      // lifted above the phone's own buttons
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ReportButton(
          label: _picked.isEmpty
              ? 'Show all items'
              : 'Done · ${_picked.length} selected',
          onPressed: _done,
        ),
      ),
    );
  }

  Widget _familyChips() {
    final all = widget.catalog.families;
    // what the SHORT view shows: the biggest families + the open one
    final collapsed = <String>{
      ...all.take(_chipCount),
      if (_family != null) _family!,
    }.toList();
    final hidden = all.length - collapsed.length;
    final canExpand = hidden > 0;
    final shown = _allFamilies ? all : collapsed;

    final chips = Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
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
          if (!_allFamilies && canExpand)
            ExpandPill(
              label: '+$hidden more',
              icon: Icons.expand_more,
              onTap: () => setState(() => _allFamilies = true),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // PINNED above the long chip list, so "less" is always in view
          if (_allFamilies && canExpand) ...[
            ExpandPill(
              strong: true,
              label: 'Show fewer families',
              icon: Icons.expand_less,
              onTap: () => setState(() => _allFamilies = false),
            ),
            const SizedBox(height: 8),
          ],
          if (_allFamilies)
            // 46+ chips scroll inside their own box: the item list below
            // never gets pushed off the screen
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: _expandedChipsMaxHeight,
              ),
              child: SingleChildScrollView(child: chips),
            )
          else
            chips,
        ],
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
    final narrowed = searching || _family != null;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (showRecent) ...[
          _header('RECENT'),
          SliverToBoxAdapter(
            child: Column(children: [for (final e in widget.recent) _tile(e)]),
          ),
        ],
        _header(
          title,
          trailing: narrowed && n > 1
              ? TextButton(
                  onPressed: _toggleAllShown,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    _allShownPicked ? 'Unselect all' : 'Select all ${fmtCount(n)}',
                    style: const TextStyle(
                      color: AppTheme.secondaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : null,
        ),
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

  SliverToBoxAdapter _header(String text, {Widget? trailing}) =>
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: SizedBox(
            height: 36,
            child: Row(
              children: [
                Expanded(
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
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      );

  Widget _tile(ItemEntry e) {
    final isSelected = _picked.containsKey(e.row.key);
    return InkWell(
      onTap: () => _toggle(e.row),
      child: Container(
        height: _rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.secondaryContainer.withValues(alpha: 0.35)
              : null,
          border: const Border(
            bottom: BorderSide(color: AppTheme.borderColor),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              size: 22,
              color: isSelected
                  ? AppTheme.secondaryColor
                  : AppTheme.textColorSecondary.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 12),
            Expanded(child: _highlighted(e)),
            if (e.length > 0)
              Text(
                fmtLength(e.length),
                style: Theme.of(context).textTheme.bodySmall,
              ),
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