import 'package:aral_project/Admin/Dashboard/metric_card.dart';
import 'package:aral_project/Admin/components/transactions.dart';
import 'package:aral_project/Admin/providers/transaction_data.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('EEE, d MMM y').format(DateTime.now());
    final textTheme = Theme.of(context).textTheme;

    return Consumer<TransactionData>(
      builder: (context, transactionData, child) {
        final list = transactionData.transactionDataList;
        DateTime now = DateTime.now();

        // 1. Filter transactions that happened today (ignoring hours/minutes/seconds)
        final todaysTransactions = list.where((tx) {
          return tx.timestamp.year == now.year &&
              tx.timestamp.month == now.month &&
              tx.timestamp.day == now.day;
        }).toList();

        // 2. Count of transactions today
        int transactionsTodayCount = todaysTransactions.length;

        // 3. Sum of quantities for Items IN today
        int itemsInToday = todaysTransactions
            .where((tx) => tx.direction.toUpperCase() == 'IN')
            .fold(0, (sum, tx) => sum + tx.quantity);

        // 4. Sum of quantities for Items OUT today
        int itemsOutToday = todaysTransactions
            .where((tx) => tx.direction.toUpperCase() == 'OUT')
            .fold(0, (sum, tx) => sum + tx.quantity);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, Admin',
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(formattedDate, style: textTheme.bodyMedium),
              const SizedBox(height: 20),

              // Dynamic Metric Cards for Today's Stats
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  MetricCard(
                    icon: Icons.format_list_bulleted_rounded,
                    count: transactionsTodayCount
                        .toString(), // Dynamic count for today
                    label: 'Transactions today',
                  ),
                  MetricCard(
                    icon: Icons.arrow_downward_rounded,
                    count: itemsInToday.toString(), // Dynamic IN sum today
                    label: 'Items IN today',
                  ),
                  MetricCard(
                    icon: Icons.arrow_upward_rounded,
                    count: itemsOutToday.toString(), // Dynamic OUT sum today
                    label: 'Items OUT today',
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent transactions'),
                  TextButton(onPressed: () {}, child: const Text('See all')),
                ],
              ),
              const SizedBox(height: 8),
              const TransactionsCard(),
            ],
          ),
        );
      },
    );
  }
}
