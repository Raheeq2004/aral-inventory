import 'package:aral_project/Admin/Dashboard/metric_card.dart';
import 'package:aral_project/Admin/Dashboard/recent_transaction_section.dart';
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

    // Pull text theme shortcuts for cleaner code
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
          Text(
            formattedDate,
            style:
                textTheme.bodyMedium, // Automatically uses textColorSecondary
          ),
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
          const RecentTransactionsSection(),
        ],
      ),
    );
  }
}
