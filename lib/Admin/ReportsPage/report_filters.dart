import 'package:aral_project/Admin/Models/item_row.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ReportKind { log, stock }

enum Operations { all, inOnly, outOnly }

enum ReportPeriod { today, yesterday, last7Days, thisMonth, lastMonth, custom }

const Map<ReportPeriod, String> kPeriodLabels = {
  ReportPeriod.today: 'Today',
  ReportPeriod.yesterday: 'Yesterday',
  ReportPeriod.last7Days: 'Last 7 days',
  ReportPeriod.thisMonth: 'This month',
  ReportPeriod.lastMonth: 'Last month',
  ReportPeriod.custom: 'Custom range…',
};

// ---------------------------------------------------------------------
// small formatting helpers (shared by the page, the sheets and the picker)
// ---------------------------------------------------------------------
final NumberFormat _lenFmt = NumberFormat('0.##');
final NumberFormat _countFmt = NumberFormat('#,##0');
final DateFormat _dayMonth = DateFormat('d MMM');

/// 6.3 -> "6.3", 6.0 -> "6"
String fmtLen(double v) => _lenFmt.format(v);

/// 6.3 -> "6.3 m"
String fmtLength(double v) => '${_lenFmt.format(v)} m';

/// 2737 -> "2,737"
String fmtCount(int n) => _countFmt.format(n);

/// 1 -> "1 row", 19 -> "19 rows"
String rowsText(int n) => n == 1 ? '1 row' : '${fmtCount(n)} rows';

/// Lengths are doubles: never compare them with ==
bool sameLength(double a, double b) => (a - b).abs() < 0.001;

/// 3 Nov - 15 Nov -> "3–15 Nov";  28 Oct - 3 Nov -> "28 Oct – 3 Nov"
String formatRange(DateTimeRange r) {
  final a = r.start;
  final b = r.end;
  if (a.year == b.year && a.month == b.month) {
    if (a.day == b.day) return _dayMonth.format(a);
    return '${a.day}–${_dayMonth.format(b)}';
  }
  return '${_dayMonth.format(a)} – ${_dayMonth.format(b)}';
}

const Object _keep = Object();

/// Everything the admin can set on the Reports page.
/// Immutable: a sheet works on a COPY (the "draft") and the page only takes
/// it when the admin taps the button, so tapping outside = no change.
@immutable
class ReportFilters {
  const ReportFilters({
    this.operations = Operations.all,
    this.period = ReportPeriod.thisMonth,
    this.customRange,
    this.asOf,
    this.item,
    this.warehouse,
    this.rack,
    this.shelf,
    this.length,
    this.finish,
    this.worker,
  });

  final Operations operations;
  final ReportPeriod period;
  final DateTimeRange? customRange; // only used when period == custom
  final DateTime? asOf; // "stock on a date"; null = today
  final ItemRow? item; // one exact item row (code + length)
  final String? warehouse;
  final String? rack;
  final String? shelf; // always 2 digits when numeric ("07")
  final double? length;
  final String? finish; // = COLOR in the items table
  final String? worker; // = createdBy

  /// `null` can be passed on purpose to CLEAR a value, so the nullable
  /// fields use a "keep" marker instead of null for "not given".
  ReportFilters copyWith({
    Operations? operations,
    ReportPeriod? period,
    Object? customRange = _keep,
    Object? asOf = _keep,
    Object? item = _keep,
    Object? warehouse = _keep,
    Object? rack = _keep,
    Object? shelf = _keep,
    Object? length = _keep,
    Object? finish = _keep,
    Object? worker = _keep,
  }) {
    return ReportFilters(
      operations: operations ?? this.operations,
      period: period ?? this.period,
      customRange: identical(customRange, _keep)
          ? this.customRange
          : customRange as DateTimeRange?,
      asOf: identical(asOf, _keep) ? this.asOf : asOf as DateTime?,
      item: identical(item, _keep) ? this.item : item as ItemRow?,
      warehouse: identical(warehouse, _keep)
          ? this.warehouse
          : warehouse as String?,
      rack: identical(rack, _keep) ? this.rack : rack as String?,
      shelf: identical(shelf, _keep) ? this.shelf : shelf as String?,
      length: identical(length, _keep) ? this.length : length as double?,
      finish: identical(finish, _keep) ? this.finish : finish as String?,
      worker: identical(worker, _keep) ? this.worker : worker as String?,
    );
  }

  bool get hasLocation => warehouse != null || rack != null || shelf != null;

  /// First and last DAY of the chosen period (local time, both included).
  DateTimeRange dateRange(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final thisMonth = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: today,
    );
    switch (period) {
      case ReportPeriod.today:
        return DateTimeRange(start: today, end: today);
      case ReportPeriod.yesterday:
        final y = DateTime(now.year, now.month, now.day - 1);
        return DateTimeRange(start: y, end: y);
      case ReportPeriod.last7Days:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 6),
          end: today,
        );
      case ReportPeriod.thisMonth:
        return thisMonth;
      case ReportPeriod.lastMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 1, 1),
          end: DateTime(now.year, now.month, 0), // day 0 = last day before
        );
      case ReportPeriod.custom:
        return customRange ?? thisMonth;
    }
  }

  /// The day of the "stock on a date" report (default: today).
  DateTime asOfDate(DateTime now) {
    final d = asOf ?? now;
    return DateTime(d.year, d.month, d.day);
  }

  /// How many ROWS of the page are set (the number in "N filters on").
  /// The default period ("This month") is not a filter.
  int activeCount(ReportKind kind) {
    var n = 0;
    if (kind == ReportKind.log) {
      if (operations != Operations.all) n++;
      if (period != ReportPeriod.thisMonth) n++;
      if (hasLocation) n++;
      if (worker != null) n++;
    } else {
      if (asOf != null) n++;
    }
    if (item != null) n++;
    if (length != null || finish != null) n++;
    return n;
  }

  // ---- the text each row shows ----
  String periodValue(DateTime now) => period == ReportPeriod.custom
      ? formatRange(dateRange(now))
      : kPeriodLabels[period]!;

  String get itemValue {
    final i = item;
    if (i == null) return 'All items';
    return i.length > 0 ? '${i.code} · ${fmtLength(i.length)}' : i.code;
  }

  String get locationValue => hasLocation
      ? [warehouse, rack, shelf].whereType<String>().join(' · ')
      : 'All locations';

  String get lengthFinishValue {
    final parts = <String>[
      if (length != null) fmtLength(length!),
      if (finish != null) finish!,
    ];
    return parts.isEmpty ? 'Any' : parts.join(' · ');
  }

  String get workerValue => worker ?? 'Anyone';
}
