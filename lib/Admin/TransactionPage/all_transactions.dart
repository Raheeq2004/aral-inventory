import 'package:aral_project/Admin/TransactionPage/filter_sheet.dart';
import 'package:aral_project/Admin/components/transactions.dart';
import 'package:aral_project/Admin/providers/filter_provider.dart';
import 'package:aral_project/Admin/providers/transaction_data.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AllTransactionsPage extends StatefulWidget {
  const AllTransactionsPage({super.key});

  @override
  State<AllTransactionsPage> createState() => _AllTransactionsPageState();
}

class _AllTransactionsPageState extends State<AllTransactionsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filterProvider = context.watch<TransactionFilterProvider>();
    final transactionData = context.watch<TransactionData>();

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
              controller: _searchController,
              hintText: 'Search product, code or worker',
              leading: const Icon(Icons.search),
              onChanged: (value) {
                // Dynamically updates text search query inside TransactionData
                context.read<TransactionData>().setSearchQuery(value);
              },
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      context.read<TransactionData>().setSearchQuery('');
                    },
                  ),
                IconButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      isDismissible: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const FilterBottonSheetContent(),
                    ).then((_) {
                      // Once the sheet closes, sync active filters from FilterProvider to TransactionData
                      context.read<TransactionData>().setFilters(
                        date: filterProvider.selectedDate,
                        movement: filterProvider.selectedMovement,
                        warehouse: filterProvider.selectedWarehouse,
                        sort: filterProvider.selectedSort,
                      );
                    });
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
                      _buildActiveChip(filterProvider.selectedDate!, () {
                        filterProvider.setDate(null);
                        _syncFilters(filterProvider);
                      }),
                    if (filterProvider.selectedMovement != null)
                      _buildActiveChip(filterProvider.selectedMovement!, () {
                        filterProvider.setMovement(null);
                        _syncFilters(filterProvider);
                      }),
                    if (filterProvider.selectedWarehouse != null)
                      _buildActiveChip(filterProvider.selectedWarehouse!, () {
                        filterProvider.setWarehouse(null);
                        _syncFilters(filterProvider);
                      }),
                    if (filterProvider.selectedSort != null)
                      _buildActiveChip(filterProvider.selectedSort!, () {
                        filterProvider.setSort(null);
                        _syncFilters(filterProvider);
                      }),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        filterProvider.resetAll();
                        context.read<TransactionData>().setFilters();
                      },
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
              'All Transactions (${transactionData.transactions.length})',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 4. Transaction List wrapped in Expanded (NOW USING transactionData.transactions)
          Expanded(
            child: transactionData.isLoading
                ? const Center(child: CircularProgressIndicator())
                : transactionData.transactions.isEmpty
                ? const Center(
                    child: Text('No transactions found matching criteria.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    itemCount: transactionData
                        .transactions
                        .length, // Uses filtered count
                    itemBuilder: (context, index) {
                      final transaction = transactionData
                          .transactions[index]; // Uses filtered items
                      return TransactionsCard(transaction);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Helper method to sync filter changes back to TransactionData
  void _syncFilters(TransactionFilterProvider filterProvider) {
    context.read<TransactionData>().setFilters(
      date: filterProvider.selectedDate,
      movement: filterProvider.selectedMovement,
      warehouse: filterProvider.selectedWarehouse,
      sort: filterProvider.selectedSort,
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
