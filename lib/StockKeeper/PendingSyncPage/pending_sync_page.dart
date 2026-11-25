import 'package:aral_project/connectivity/connectivity_badge.dart';
import 'package:aral_project/StockKeeper/PendingSyncPage/pending_sync_model.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// =====================================================================
// ARAL Inventory – Pending sync page (worker)
// Figma: "Pending sync". Reads everything from PendingSyncController.
// =====================================================================

class PendingSyncPage extends StatelessWidget {
  const PendingSyncPage({super.key, this.onLogout});

  /// Logout icon (top right). TODO(integrate): connect to the real logout.
  final VoidCallback? onLogout;

  /// DEMO route: gives the page its own fake controller so you can open it
  /// alone:  Navigator.push(context, PendingSyncPage.demoRoute());
  /// TODO(integrate): once PendingSyncController is registered in
  /// main.dart's MultiProvider, use `MaterialPageRoute(builder: (_) =>
  /// const PendingSyncPage())` instead and delete this.
  static Route<void> demoRoute() => MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider(
      create: (_) => PendingSyncController.demo(),
      child: const PendingSyncPage(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PendingSyncController>();
    final entries = _groupByDay(c.items);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Pending sync'),
        actions: [
          const ConnectivityBadge(),
          IconButton(
            tooltip: 'Log out',
            onPressed: onLogout ?? () {},
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // blue strip: only while a sync is running
          if (c.isSyncing) _SyncingBanner(done: c.syncDone, total: c.syncTotal),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              // +1 → the "waiting" card is the first row of the list
              itemCount: entries.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return _WaitingCard(controller: c);
                final e = entries[i - 1];
                if (e is String) return _DayHeader(e);
                final t = e as PendingTransaction;
                return _TransactionTile(
                  t: t,
                  onRetry: () =>
                      context.read<PendingSyncController>().retry(t.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Newest first, with a text header ("TODAY") before each day.
  /// Result = a mixed list: String (header) or PendingTransaction (row).
  static List<Object> _groupByDay(List<PendingTransaction> items) {
    final sorted = [...items]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final out = <Object>[];
    String? lastLabel;
    for (final t in sorted) {
      final label = _dayLabel(t.savedAt);
      if (label != lastLabel) {
        out.add(label);
        lastLabel = label;
      }
      out.add(t);
    }
    return out;
  }

  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays; // local time, not UTC
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    return DateFormat('d MMM yyyy').format(d).toUpperCase();
  }
}

/// Shows the dark "Saved on this phone · will sync when online   VIEW"
/// message. TODO(integrate): call it from the quantity page right after
/// a transaction is saved while offline.
void showSavedOfflineSnack(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: const Text('Saved on this phone • will sync when online'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'VIEW',
          textColor: AppTheme.primaryContainer,
          onPressed: () =>
              // TODO(integrate): use the non-demo route (see demoRoute)
              Navigator.of(context).push(PendingSyncPage.demoRoute()),
        ),
      ),
    );
}

// ---------------------------------------------------------------------
// Pieces of the page (private: only this file uses them)
// ---------------------------------------------------------------------

/// Blue strip: "Back online • Syncing transactions…      2 of 3"
class _SyncingBanner extends StatelessWidget {
  const _SyncingBanner({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.sync_rounded,
            size: 18,
            color: AppTheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Back online • Syncing transactions…',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.onPrimaryContainer,
              ),
            ),
          ),
          Text(
            // while running, show the one being sent (done + 1)
            '${done < total ? done + 1 : total} of $total',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Big card: "2 transactions waiting" + [Sync now]
class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.controller});
  final PendingSyncController controller;

  @override
  Widget build(BuildContext context) {
    final n = controller.waitingCount;
    final busy = controller.isSyncing;
    final canSync = n > 0 && !busy && controller.isOnline;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F2EE), // soft warm grey from the mock-up
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.warningContainer,
                  border: Border.all(color: AppTheme.warningBorder),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: AppTheme.warningColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n == 0
                          ? 'All caught up'
                          : '$n transaction${n == 1 ? '' : 's'} waiting',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColorPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n == 0
                          ? 'Nothing is waiting on this phone'
                          : 'Saved on this phone while offline',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textColorSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: canSync
                  ? () => context.read<PendingSyncController>().syncAll()
                  : null, // disabled: nothing waiting / offline / running
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: const StadiumBorder(),
              ),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_rounded, size: 20),
              label: Text(
                busy
                    ? 'Syncing…'
                    : controller.isOnline
                    ? 'Sync now'
                    : 'Waiting for connection',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppTheme.textColorSecondary,
      ),
    ),
  );
}

/// One transaction row: name, "IN • 20 pcs • WH1 / B3 / S2", status chip.
class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.t, required this.onRetry});
  final PendingTransaction t;
  final VoidCallback onRetry;

  static final DateFormat _time = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final isFailed = t.status == SyncStatus.failed;

    final String note = switch (t.status) {
      SyncStatus.synced =>
        'Synced to server • ${_time.format(t.syncedAt ?? t.savedAt)}',
      SyncStatus.failed => '${t.error ?? 'Sync failed'} • Tap to retry',
      SyncStatus.pending => 'Saved on this phone • ${_time.format(t.savedAt)}',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        // only a failed row can be tapped
        onTap: isFailed ? onRetry : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.itemName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColorPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${t.direction} • ${t.quantity} pcs • ${t.location}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textColorSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: TextStyle(
                        fontSize: 13,
                        color: isFailed
                            ? AppTheme.errorColor
                            : AppTheme.textColorSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: t.status),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small rounded label on the right: Pending / Synced / Sync failed.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    // (background, text/icon colour, icon, text)
    final (Color bg, Color fg, IconData icon, String text) = switch (status) {
      SyncStatus.pending => (
        const Color(0xFFFFF1CC),
        AppTheme.warningColor,
        Icons.schedule_rounded,
        'Pending',
      ),
      SyncStatus.synced => (
        const Color(0xFFDDF1E3),
        AppTheme.successColor,
        Icons.cloud_done_rounded,
        'Synced',
      ),
      SyncStatus.failed => (
        const Color(0xFFFDDADA),
        AppTheme.errorColor,
        Icons.error_rounded,
        'Sync failed',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}