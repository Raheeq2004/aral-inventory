import 'package:aral_project/Admin/TransactionPage/filter_sheet.dart';
import 'package:aral_project/Admin/components/transactions.dart';
import 'package:aral_project/Admin/providers/filter_provider.dart';
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
    final theme = Theme.of(context);
    final filterProvider = context.watch<TransactionFilterProvider>();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Handle FAB action
        },
        child: const Icon(Icons.download),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Search Bar with Badged Filter Icon
          Padding(
            padding: const EdgeInsets.all(15),
            child: SearchBar(
              hintText: 'Search product, code or worker',
              leading: const Icon(Icons.search),
              trailing: [
                IconButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      isDismissible: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const FilterBottonSheetContent(),
                    );
                  },
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.filter_list),
                      if (filterProvider.activeFiltersCount > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${filterProvider.activeFiltersCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Active Filter Chips Row Container (Under Search Bar)
          if (filterProvider.hasActiveFilters) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (filterProvider.selectedDate != null)
                      _buildActiveChip(
                        filterProvider.selectedDate!,
                        () => filterProvider.setDate(null),
                      ),
                    if (filterProvider.selectedMovement != null)
                      _buildActiveChip(
                        filterProvider.selectedMovement!,
                        () => filterProvider.setMovement(null),
                      ),
                    if (filterProvider.selectedWarehouse != null)
                      _buildActiveChip(
                        filterProvider.selectedWarehouse!,
                        () => filterProvider.setWarehouse(null),
                      ),
                    if (filterProvider.selectedSort != null)
                      _buildActiveChip(
                        filterProvider.selectedSort!,
                        () => filterProvider.setSort(null),
                      ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => filterProvider.resetAll(),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text(
                        'Clear all',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

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
    );
  }

  // Helper widget for active filter chips below the search bar
  Widget _buildActiveChip(String label, VoidCallback onDeleted) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        backgroundColor: const Color(0xFFFDE6D2),
        deleteIcon: const Icon(Icons.close, size: 14, color: Colors.black87),
        onDeleted: onDeleted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.orange.shade300, width: 1),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
