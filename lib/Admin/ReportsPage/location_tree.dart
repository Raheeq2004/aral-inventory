/// "A2" before "A10" (instead of "A10" before "A2").
/// No RegExp and no new lists: it walks both strings once.
int naturalCompare(String a, String b) {
  bool isDigit(int c) => c >= 48 && c <= 57;

  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    final ca = a.codeUnitAt(i);
    final cb = b.codeUnitAt(j);
    if (isDigit(ca) && isDigit(cb)) {
      var ei = i;
      while (ei < a.length && isDigit(a.codeUnitAt(ei))) {
        ei++;
      }
      var ej = j;
      while (ej < b.length && isDigit(b.codeUnitAt(ej))) {
        ej++;
      }
      final na = int.tryParse(a.substring(i, ei)) ?? 0;
      final nb = int.tryParse(b.substring(j, ej)) ?? 0;
      if (na != nb) return na.compareTo(nb);
      i = ei;
      j = ej;
    } else {
      if (ca != cb) return ca.compareTo(cb);
      i++;
      j++;
    }
  }
  return (a.length - i).compareTo(b.length - j);
}

/// Warehouse -> rack -> shelf, built ONCE from the rows that
/// `LocationsRepository.loadParts()` returns ([warehouse, rack, shelf]).
/// Every list is already sorted, so the sheets only read from it.
class LocationTree {
  LocationTree(Iterable<List<String>> parts) {
    final raw = <String, Map<String, Set<String>>>{};
    for (final p in parts) {
      if (p.length < 3 || p[0].isEmpty) continue;
      final racks = raw.putIfAbsent(p[0], () => <String, Set<String>>{});
      if (p[1].isEmpty) continue;
      final shelves = racks.putIfAbsent(p[1], () => <String>{});
      if (p[2].isNotEmpty) shelves.add(p[2]);
    }

    _warehouses = raw.keys.toList()..sort(naturalCompare);
    for (final wh in _warehouses) {
      final racks = raw[wh]!;
      final rackNames = racks.keys.toList()..sort(naturalCompare);
      _racks[wh] = rackNames;
      for (final rack in rackNames) {
        _shelves['$wh|$rack'] = racks[rack]!.toList()..sort(naturalCompare);
      }
    }
  }

  late final List<String> _warehouses;
  final Map<String, List<String>> _racks = {};
  final Map<String, List<String>> _shelves = {};

  bool get isEmpty => _warehouses.isEmpty;

  List<String> get warehouses => _warehouses;

  List<String> racksOf(String warehouse) => _racks[warehouse] ?? const [];

  List<String> shelvesOf(String warehouse, String rack) =>
      _shelves['$warehouse|$rack'] ?? const [];
}
