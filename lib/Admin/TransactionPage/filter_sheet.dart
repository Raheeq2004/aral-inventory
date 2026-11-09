import 'package:aral_project/Admin/providers/filter_provider.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FilterBottonSheetContent extends StatelessWidget {
  const FilterBottonSheetContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch the provider so the bottom sheet updates instantly
    final filterProvider = context.watch<TransactionFilterProvider>();

    bool isWh1Selected = filterProvider.selectedWarehouse == 'WH1';
    bool isWh2Selected = filterProvider.selectedWarehouse == 'WH2';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 20),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Drag Handle Pill (Centered)
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 2. Header Row
              Row(
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColorPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (filterProvider.activeFiltersCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppTheme.primaryColor,
                      ),
                      child: Text(
                        'Active (${filterProvider.activeFiltersCount})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => filterProvider.resetAll(),
                    child: Text(
                      'Reset all',
                      style: TextStyle(
                        color: AppTheme.secondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppTheme.textColorSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppTheme.borderColor),
              const SizedBox(height: 10),

              // Date Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Date',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textColorPrimary,
                    ),
                  ),
                  Text(
                    filterProvider.selectedDate ?? 'Select Date',
                    style: TextStyle(
                      fontSize: 14,
                      color: filterProvider.selectedDate != null
                          ? AppTheme.secondaryColor
                          : AppTheme.textColorSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Date Filter Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCustomChoiceChip(
                    'Today',
                    filterProvider.selectedDate == 'Today',
                    (val) => filterProvider.setDate('Today'),
                  ),
                  _buildCustomChoiceChip(
                    'Yesterday',
                    filterProvider.selectedDate == 'Yesterday',
                    (val) => filterProvider.setDate('Yesterday'),
                  ),
                  _buildCustomChoiceChip(
                    'Last 7 days',
                    filterProvider.selectedDate == 'Last 7 days',
                    (val) => filterProvider.setDate('Last 7 days'),
                  ),
                  _buildCustomChoiceChip(
                    'This month',
                    filterProvider.selectedDate == 'This month',
                    (val) => filterProvider.setDate('This month'),
                  ),
                  _buildCustomChoiceChip(
                    'Custom range...',
                    filterProvider.selectedDate == 'Custom range...',
                    (val) => filterProvider.setDate('Custom range...'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Movement Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Movement',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textColorPrimary,
                    ),
                  ),
                  Text(
                    filterProvider.selectedMovement ?? 'Select Movement',
                    style: TextStyle(
                      fontSize: 14,
                      color: filterProvider.selectedMovement != null
                          ? AppTheme.secondaryColor
                          : AppTheme.textColorSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Movement Filter Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCustomChoiceChip(
                    'IN • received',
                    filterProvider.selectedMovement == 'IN • received',
                    (val) => filterProvider.setMovement('IN • received'),
                  ),
                  _buildCustomChoiceChip(
                    'OUT • issued',
                    filterProvider.selectedMovement == 'OUT • issued',
                    (val) => filterProvider.setMovement('OUT • issued'),
                  ),
                  _buildCustomChoiceChip(
                    'Reversals',
                    filterProvider.selectedMovement == 'Reversals',
                    (val) => filterProvider.setMovement('Reversals'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Warehouse & Location Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Warehouse & location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textColorPrimary,
                    ),
                  ),
                  Text(
                    filterProvider.selectedWarehouse != null
                        ? '${filterProvider.selectedWarehouse} Selected'
                        : 'Select Location',
                    style: TextStyle(
                      fontSize: 14,
                      color: filterProvider.selectedWarehouse != null
                          ? AppTheme.secondaryColor
                          : AppTheme.textColorSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Location code = Warehouse – Rack – Shelf (e.g. WH1-B3-02)',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textColorSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // Warehouse Selection Cards Row
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => filterProvider.setWarehouse('WH1'),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isWh1Selected
                              ? const Color(0xFFFDE6D2).withValues(alpha: 0.6)
                              : AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isWh1Selected
                                ? Colors.orange.shade300
                                : AppTheme.borderColor,
                            width: isWh1Selected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  Icons.home,
                                  size: 20,
                                  color: isWh1Selected
                                      ? Colors.black87
                                      : AppTheme.textColorSecondary,
                                ),
                                if (isWh1Selected)
                                  const Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: Colors.black87,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'WH1',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textColorPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '30 racks • 571 shelves',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textColorSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => filterProvider.setWarehouse('WH2'),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isWh2Selected
                              ? const Color(0xFFFDE6D2).withValues(alpha: 0.6)
                              : AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isWh2Selected
                                ? Colors.orange.shade300
                                : AppTheme.borderColor,
                            width: isWh2Selected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  Icons.home,
                                  size: 20,
                                  color: isWh2Selected
                                      ? Colors.black87
                                      : AppTheme.textColorSecondary,
                                ),
                                if (isWh2Selected)
                                  const Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: Colors.black87,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'WH2',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textColorPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '21 racks • 360 shelves',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textColorSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Sort by Section
              const Text(
                'Sort by',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColorPrimary,
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCustomChoiceChip(
                    'Newest first',
                    filterProvider.selectedSort == 'Newest first',
                    (val) => filterProvider.setSort('Newest first'),
                  ),
                  _buildCustomChoiceChip(
                    'Oldest first',
                    filterProvider.selectedSort == 'Oldest first',
                    (val) => filterProvider.setSort('Oldest first'),
                  ),
                  _buildCustomChoiceChip(
                    'Largest quantity',
                    filterProvider.selectedSort == 'Largest quantity',
                    (val) => filterProvider.setSort('Largest quantity'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomChoiceChip(
    String label,
    bool isSelected,
    Function(bool) onSelected,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: const Color(0xFFFDE6D2),
      backgroundColor: AppTheme.surfaceColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black87 : AppTheme.textColorSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? Colors.orange.shade300 : AppTheme.borderColor,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      showCheckmark: isSelected,
      checkmarkColor: Colors.black87,
    );
  }
}
