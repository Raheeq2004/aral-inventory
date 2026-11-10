import 'package:aral_project/Admin/DashboardPage/admin_dashboard.dart';
import 'package:aral_project/Admin/ReportsPage/reports_page.dart';
import 'package:aral_project/Admin/TransactionPage/all_transactions.dart';
import 'package:aral_project/Admin/providers/transaction_data.dart';
import 'package:aral_project/Internet%20Connectivity/connectivity_badge.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdminRouting extends StatefulWidget {
  const AdminRouting({super.key});

  @override
  State<AdminRouting> createState() => _AdminRoutingState();
}

class _AdminRoutingState extends State<AdminRouting> {
  @override
  void initState() {
    super.initState();
    // Safely fetch transactions after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionData>(context, listen: false).getTransactions();
    });
  }

  int _currentIndex = 0;

  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  final List<String> _titles = ['Dashboard', 'Transactions', 'Reports'];

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      AdminDashboard(onNavigateToTransactions: _onTabChanged),
      const AllTransactionsPage(),
      const ReportsPage(), // Dina's Reports page (was a placeholder text)
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(_titles[_currentIndex]),
        actions: [
          const ConnectivityBadge(),
          const SizedBox(width: 8),
          IconButton(onPressed: () {}, icon: const Icon(Icons.logout_rounded)),
          const SizedBox(width: 10),
        ],
      ),
      body: screens[_currentIndex],
      // Colors, icon sizes and type now come from
      // bottomNavigationBarTheme in Theme/theme.dart (active tab = orange).
      // No hard-coded colors here → change the theme once, the bar follows.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_rounded),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Reports',
          ),
        ],
        onTap: _onTabChanged,
      ),
    );
  }
}