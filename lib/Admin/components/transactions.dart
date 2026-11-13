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
    // Determine the amount text
    final String amountText = transaction.direction == 'IN'
        ? "+${transaction.quantity}"
        : "-${transaction.quantity}";

    // Determine the color and text decorations based on transaction status
    Color amountColor;
    TextDecoration? textDecoration;
    Color iconContainerColor;

    if (transaction.reversed) {
      // 1. REVERSED transaction: Faded original color with a strikethrough
      final bool isIn = transaction.direction == 'IN';
      amountColor = isIn
          ? Colors.green.shade700.withValues(alpha: 0.4)
          : Theme.of(context).colorScheme.error.withValues(alpha: 0.4);
      textDecoration = TextDecoration.lineThrough;
      iconContainerColor =
          (isIn ? Colors.green : Theme.of(context).colorScheme.error)
              .withValues(alpha: 0.08);
    } else if (transaction.isReversal) {
      // 2. REVERSAL transaction: Yellow theme color for text and soft yellow icon container
      amountColor = AppTheme.warningColor;
      textDecoration = null;
            iconContainerColor = AppTheme.warningBorder.withValues(alpha: 0.6);
    } else {
      // 3. NORMAL transaction: Standard green for IN, Red for OUT
      final bool isIn = transaction.direction == 'IN';
      amountColor = isIn
          ? Colors.green.shade700
          : Theme.of(context).colorScheme.error;
      textDecoration = null;
      iconContainerColor =
          (isIn ? Colors.green : Theme.of(context).colorScheme.error)
              .withValues(alpha: 0.15);
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
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
            color: iconContainerColor,
            shape: BoxShape.circle,
          ),
          child: transaction.direction == 'IN'
              ? Icon(Icons.arrow_downward, color: amountColor)
              : Icon(Icons.arrow_upward, color: amountColor),
        ),
        subtitle: Text(
          "Location =: ${transaction.locationCode}\n${transaction.workerId} * ${DateFormat('d MMM, HH:mm').format(transaction.timestamp.toLocal())}",
        ),
        trailing: Text(
          amountText,
          style: TextStyle(
            fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
            fontWeight: FontWeight.bold,
            color: amountColor,
            decoration: textDecoration,
            decorationColor: amountColor,
          ),
        ),
      ),
    );
  }
}
