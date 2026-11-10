import 'package:aral_project/Admin/components/transactions.dart';
import 'package:aral_project/Admin/ReportsPage/excel_export_services.dart';
import 'package:aral_project/Admin/providers/transaction_data.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AllTransactionsPage extends StatefulWidget {
  const AllTransactionsPage({super.key});

  @override
  State<AllTransactionsPage> createState() => _AllTransactionsPageState();
}

class _AllTransactionsPageState extends State<AllTransactionsPage> {
  @override
  Widget build(BuildContext context) {
    // Access your theme styles/colors easily
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Search Bar (automatically styled by your InputDecorationTheme / global theme)
          Padding(
            padding: const EdgeInsets.all(15),
            child: SearchBar(
              hintText: 'Search product, code or worker',
              leading: const Icon(Icons.search),
              trailing: [
                IconButton(
                  onPressed: () {
                    // showModalBottomSheet(
                    //   context: context,
                    //   builder: (context) => const FilterModalBottomSheet(),
                    // );
                  },
                  icon: const Icon(Icons.filter_list),
                ),
              ],
            ),
          ),

          // 2. Filter Chips Row Container
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Row(
              children: [
                // Add your filter chips here
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3. Section Title using Theme's bodyMedium style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Text(
              'All Transactions',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 4. Transaction List wrapped in Expanded
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              children: const [TransactionsCard()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ExcelExportService.exportAndNotify(
            context: context,
            transactions: context.read<TransactionData>().transactionDataList,
          );        
          },
        child: const Icon(Icons.download),
      ),
    );
  }
}
