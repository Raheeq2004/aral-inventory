import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:aral_project/Admin/TransactionDetailPage/transaction_detail.dart';
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
        subtitle: Text(
          "Location =: ${transaction.locationCode}\n${transaction.workerId} * ${DateFormat('d MMM, HH:mm').format(transaction.timestamp.toLocal())} ",
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
