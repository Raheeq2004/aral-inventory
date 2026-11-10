import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:aral_project/Admin/TransactionDetailPage/transaction_detail.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionsCard extends StatelessWidget {
  final TransactionModel transaction;
  const TransactionsCard(this.transaction, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        // Tap a row → open A3 (Transaction detail) for THIS transaction.
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailPage(transaction: transaction),
          ),
        ),
        title: Text(transaction.itemCode),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: transaction.direction == "IN"
                ? Colors.green.withValues(alpha: 0.15)
                : Theme.of(context).colorScheme.error.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: transaction.direction == 'IN'
              ? const Icon(Icons.arrow_downward)
              : const Icon(Icons.arrow_upward),
        ),
        // subtitle can be any widget → a Column: Joud's text + a small tag
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Location =: ${transaction.locationCode}\n${transaction.workerId} * ${DateFormat('d MMM, HH:mm').format(transaction.timestamp.toLocal())} ",
            ),
            // NEW (A4): tags for reversed / reversal rows (collection `if`)
            if (transaction.reversed)
              const _Tag(text: 'Reversed', icon: Icons.undo),
            if (transaction.isReversal)
              _Tag(
                text: 'Reversal of #${transaction.reversalOf ?? '—'}',
                icon: Icons.undo,
              ),
          ],
        ),
        trailing: Text(
          transaction.direction == 'IN'
              ? "+${transaction.quantity}"
              : "-${transaction.quantity}",
          style: TextStyle(
            fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
            color: transaction.direction == 'IN'
                ? Colors.green.shade700
                : Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
  }
}

/// NEW (A4): a small yellow tag under a row ("Reversed" / "Reversal of #…").
class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.icon});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.warningContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // only as wide as its content
          children: [
            Icon(icon, size: 14, color: AppTheme.warningColor),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppTheme.warningColor),
            ),
          ],
        ),
      ),
    );
  }
}