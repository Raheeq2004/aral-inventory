// =====================================================================
// ARAL Inventory – A1 · Admin Dashboard (v2 "peach")
// =====================================================================
//
// Matches Figma: 🛡️ Admin App → "A1 · Dashboard v2 (sunrise)" and
// "A1b · Dashboard – no scans today".
//
// What's on the page (top → bottom):
//   1) Greeting      → "Good evening, Admin" + today's date
//   2) Hero card     → peach gradient, "Transactions today" + last activity
//   3) IN / OUT row  → two cards: pieces IN today, pieces OUT today
//   4) Empty state   → only when there are no transactions today
//   5) Recent        → the 5 NEWEST transactions (sorted by date)
//
// Fixes compared to the old version:
//   • Recent is sorted newest-first (before: Firebase key order).
//   • Reversals are NOT counted in today's numbers (see _countsForToday).
//   • Dates are compared in LOCAL time (Jordan), not UTC.
//   • Tapping a card opens Transactions already filtered (Today + IN/OUT).
//   • "See all" clears old filters so it really shows all.
//   • Pull down to refresh (reloads from Firebase).
// =====================================================================

import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:aral_project/Admin/components/transactions.dart';
import 'package:aral_project/Admin/providers/filter_provider.dart';
import 'package:aral_project/Admin/providers/transaction_data.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';
// `show DateFormat` → import ONLY DateFormat from intl.
// (intl also has a TextDirection class that clashes with Flutter's.)
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

// The filter values the filter sheet uses (filter_sheet.dart).
// We must use the SAME text, or the chips/filters won't match.
const String _kToday = 'Today';
const String _kMovementIn = 'IN • received';
const String _kMovementOut = 'OUT • issued';

/// StatelessWidget: the page keeps no state of its own.
/// All data comes from the TransactionData provider (via Consumer).
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key, this.onNavigateToTransactions});

  /// Given by AdminRouting: call it with 1 to switch to the Transactions tab.
  /// `Function(int)?` → a function that takes an int; `?` = may be null.
  final Function(int)? onNavigateToTransactions;

  // -------------------------------------------------------------------
  // Helpers (small functions used by build)
  // -------------------------------------------------------------------

  /// true if [date] is today (in the phone's local time).
  static bool _isToday(DateTime date) {
    final d = date.toLocal(); // Firebase time may be UTC → convert first
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  /// Should this transaction count in TODAY's numbers?
  /// A reversal (and the original it cancels) is not a real stock
  /// movement: reversing "OUT 150" adds "IN 150", and counting it would
  /// show 150 pieces IN that never arrived. So we skip both.
  static bool _countsForToday(TransactionModel tx) =>
      !tx.isReversal && !tx.reversed;

  /// "Good morning / afternoon / evening" depending on the hour.
  static String _greeting() {
    final hour = DateTime.now().hour; // 0..23
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Opens the Transactions tab with filters already applied.
  /// The filters live in TWO providers:
  ///   • TransactionFilterProvider → what the chips / sheet SHOW
  ///   • TransactionData           → what the list actually FILTERS
  /// so we update both, then switch tab.
  void _openTransactions(
    BuildContext context, {
    String? date,
    String? movement,
  }) {
    // context.read = get the provider ONCE (no rebuild on changes).
    // Right choice inside onTap / onPressed.
    final filters = context.read<TransactionFilterProvider>();
    filters.resetAll(); // start clean (setDate/setMovement TOGGLE values)
    if (date != null) filters.setDate(date);
    if (movement != null) filters.setMovement(movement);

    context.read<TransactionData>().setFilters(date: date, movement: movement);

    // `?.call(1)` = call the function only if it's not null.
    onNavigateToTransactions?.call(1);
  }

  // -------------------------------------------------------------------
  // build
  // -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Consumer rebuilds ONLY this part when TransactionData calls
    // notifyListeners() (after loading, editing, reversing…).
    return Consumer<TransactionData>(
      builder: (context, data, child) {
        final all = data.transactionDataList;

        // First load: nothing yet → show a spinner instead of zeros.
        if (data.isLoading && all.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        // ---- Today's numbers ------------------------------------------
        // where = keep only the items that match the test.
               // Count ALL of today's transactions (reversals included),
        // so the cards always match the Transactions list (Today filter).
        final today = all.where((tx) => _isToday(tx.timestamp)).toList();

        // fold = walk the list and build ONE value (here: a sum).
        //   start at 0, then for each tx: sum + tx.quantity
        final piecesIn = today
            .where((tx) => tx.direction.toUpperCase() == 'IN')
            .fold<int>(0, (sum, tx) => sum + tx.quantity);
        final piecesOut = today
            .where((tx) => tx.direction.toUpperCase() == 'OUT')
            .fold<int>(0, (sum, tx) => sum + tx.quantity);

        // Last activity today = the newest of today's transactions.
        // reduce = compare items two by two and keep one (the newest).
        final TransactionModel? last = today.isEmpty
            ? null
            : today.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
        final lastLine = last == null
            ? 'No scans yet today'
            : 'Last: ${DateFormat('HH:mm').format(last.timestamp.toLocal())}'
                  ' by ${last.workerId}';

        // ---- Recent: 5 newest, ALL transactions (reversals included) ----
        // [...all] = a COPY, so we don't reorder the provider's list.
        // `..sort(...)` (cascade) sorts the copy and returns the copy itself,
        // so we can continue with .take(5).
        // b.compareTo(a) → descending → newest first.
        final recent =
            ([...all]..sort((a, b) => b.timestamp.compareTo(a.timestamp)))
                .take(5)
                .toList();

        // RefreshIndicator = pull down to reload. onRefresh must return a
        // Future → getTransactions() is async, so it fits.
        return RefreshIndicator(
          onRefresh: data.getTransactions,
          child: SingleChildScrollView(
            // Always scrollable, even when the content is short,
            // otherwise pull-to-refresh can't be triggered.
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1) Greeting ------------------------------------------
                Text(
                  '${_greeting()}, Admin',
                  style: textTheme.displaySmall?.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('EEEE, d MMMM y').format(DateTime.now())}'
                  ' • All warehouses',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 16),

                // 2) Hero card -----------------------------------------
                _HeroCard(
                  count: today.length,
                  subtitle: lastLine,
                  onTap: () => _openTransactions(context, date: _kToday),
                ),
                const SizedBox(height: 12),

                // 3) IN / OUT row --------------------------------------
                // Expanded = each card takes an equal share of the width.
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.arrow_downward_rounded,
                        value: piecesIn,
                        label: 'Items IN today',
                        color: AppTheme.successColor,
                        onTap: () => _openTransactions(
                          context,
                          date: _kToday,
                          movement: _kMovementIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.arrow_upward_rounded,
                        value: piecesOut,
                        label: 'Items OUT today',
                        color: theme.colorScheme.error,
                        onTap: () => _openTransactions(
                          context,
                          date: _kToday,
                          movement: _kMovementOut,
                        ),
                      ),
                    ),
                  ],
                ),

                // 4) Empty state (collection-if: only added when true) --
                if (today.isEmpty) ...[
                  const SizedBox(height: 16),
                  const _EmptyToday(),
                ],

                // 5) Recent --------------------------------------------
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent transactions',
                        style: textTheme.titleMedium?.copyWith(
                          color: AppTheme.textColorPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      // No date/movement → resetAll only → shows ALL.
                      onPressed: () => _openTransactions(context),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No transactions yet',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
                    ),
                  )
                else
                  // `...` (spread) puts every card of the list into children.
                  ...recent.map((tx) => TransactionsCard(tx)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =====================================================================
// Hero card: peach gradient + "Transactions today"
// =====================================================================
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.count,
    required this.subtitle,
    required this.onTap,
  });

  final int count;
  final String subtitle;
  final VoidCallback onTap; // VoidCallback = a function with no args/result

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Dark brown text: the peach is light, so white text would be hard
    // to read (design-system note on peachGradient in Figma).
    final onPeach = scheme.onSecondaryContainer;
    final radius = BorderRadius.circular(20);

    // DecoratedBox draws the soft orange shadow OUTSIDE the card.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF39966).withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Material + Ink + InkWell = a tappable box with the ripple effect
      // drawn ON TOP of the gradient (a plain Container would hide it).
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias, // cut the circles at the round corners
        child: Ink(
          decoration: const BoxDecoration(gradient: AppTheme.peachGradient),
          child: InkWell(
            onTap: onTap,
            // Stack = widgets on top of each other.
            // The Padding (not Positioned) gives the Stack its size;
            // the Positioned circles are placed relative to it.
            child: Stack(
              children: [
                const Positioned(
                  right: -40,
                  top: -60,
                  child: _DecorCircle(size: 150, opacity: 0.35),
                ),
                const Positioned(
                  right: 20,
                  bottom: -40,
                  child: _DecorCircle(size: 80, opacity: 0.30),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transactions today',
                              style: TextStyle(fontSize: 14, color: onPeach),
                            ),
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 36,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                                color: onPeach,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: onPeach,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // White circle with the orange list icon.
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.format_list_bulleted_rounded,
                          color: scheme.secondary, // burnt orange
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A see-through white circle used as decoration on the hero card.
class _DecorCircle extends StatelessWidget {
  const _DecorCircle({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

// =====================================================================
// IN / OUT card
// =====================================================================
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color color; // green for IN, red for OUT
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Card uses cardTheme from theme.dart (white, thin border, radius 12).
    // margin: zero → the Row controls the spacing, not the Card.
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias, // ripple stays inside the corners
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Same soft circle style as the transaction list icons.
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const Spacer(), // pushes the chevron to the right
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textColorSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Empty state: no transactions today
// =====================================================================
class _EmptyToday extends StatelessWidget {
  const _EmptyToday();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppTheme.backgroundColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: AppTheme.textColorSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No transactions yet today',
            style: textTheme.titleSmall?.copyWith(
              color: AppTheme.textColorPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Scans from workers will appear here',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}