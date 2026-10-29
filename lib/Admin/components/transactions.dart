import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:aral_project/Admin/providers/transaction_data.dart';
import 'package:flutter/material.dart';
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
                title: Text(tx.itemName),
                subtitle: Text("Type: ${tx.type} | Qty: ${tx.quantity}"),
                trailing: Text(
                  tx.timestamp.toLocal().toString().split('.')[0],
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
