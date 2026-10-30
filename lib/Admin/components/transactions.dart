import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:aral_project/Admin/providers/transaction_data.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TransactionsCard extends StatelessWidget {
  const TransactionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionData>(
      builder: (context, transactionData, child) {
        if (transactionData.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (transactionData.transactionDataList.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'No transactions found in database.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: transactionData.transactionDataList.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            TransactionModel tx = transactionData.transactionDataList[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(tx.itemCode),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tx.direction == "IN"
                        ? Colors.green.withValues(alpha: 0.15)
                        : Theme.of(context).colorScheme.error
                              .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: tx.direction == 'IN'
                      ? Icon(Icons.arrow_downward)
                      : Icon(Icons.arrow_upward),
                ),
                subtitle: Text(
                  "Location =: ${tx.locationCode}\n${tx.workerId} * ${DateFormat('d MMM, HH:mm').format(tx.timestamp.toLocal())} ",
                ),
                trailing: Text(
                  tx.direction == 'IN' ? "+${tx.quantity}" : "-${tx.quantity}",
                  style: TextStyle(
                    fontSize: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.fontSize,
                    color: tx.direction == 'IN'
                        ? Colors.green.shade700
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
