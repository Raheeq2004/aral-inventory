import 'package:aral_project/Admin/Dashboard/metric_card.dart';
import 'package:aral_project/Admin/components/transactions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: const [
              MetricCard(
                icon: Icons.format_list_bulleted_rounded,
                count: '128',
                label: 'Transactions today',
              ),
              MetricCard(
                icon: Icons.arrow_downward_rounded,
                count: '86',
                label: 'Items IN today',
              ),
              MetricCard(
                icon: Icons.arrow_upward_rounded,
                count: '42',
                label: 'Items OUT today',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent transactions'),
              TextButton(onPressed: () {}, child: Text('See all')),
            ],
          ),
          const SizedBox(height: 8),
          const TransactionsCard(),
        ],
      ),
    );
  }
}
