import 'package:aral_project/Admin/Dashboard/admin_dashboard.dart';
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
  final List<String> _titles = ['Dashboard', 'Transactions', 'Reports'];
  final List<Widget> _screens = [
    const AdminDashboard(),
    const Center(child: Text('Transactions Screen')),
    const Center(child: Text('Reports Screen')),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(_titles[_currentIndex]),
        actions: [
          const ConnectivityBadge(),
          const SizedBox(width: 8),
          IconButton(onPressed: () {}, icon: const Icon(Icons.logout_rounded)),
          SizedBox(width: 10),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFF1F5F9),
        selectedItemColor: const Color(
          0xFF78350F,
        ), // Deep warm brown for selected item/pill
        unselectedItemColor: const Color(
          0xFF475569,
        ), // Slate gray for unselected items
        selectedIconTheme: const IconThemeData(size: 26),
        unselectedIconTheme: const IconThemeData(size: 24),
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
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
