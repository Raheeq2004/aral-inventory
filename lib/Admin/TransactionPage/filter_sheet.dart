import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';

class FilterBottonSheetContent extends StatefulWidget {
  const FilterBottonSheetContent({super.key});

  @override
  State<FilterBottonSheetContent> createState() =>
      _FilterBottomSheetContentState();
}

class _FilterBottomSheetContentState extends State<FilterBottonSheetContent> {
  // State variables (nullable so they can be null/nothing selected by default)
  String? selectedDate;
  String? selectedMovement;
  String? selectedWarehouse;
  String? selectedSort;

  @override
  Widget build(BuildContext context) {
    bool isWh1Selected = selectedWarehouse == 'WH1';
    bool isWh2Selected = selectedWarehouse == 'WH2';

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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppTheme.primaryColor,
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        // Reset all selections to null (nothing selected)
                        selectedDate = null;
                        selectedMovement = null;
                        selectedWarehouse = null;
                        selectedSort = null;
                      });
                    },
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
                    selectedDate ?? 'Select Date',
                    style: TextStyle(
                      fontSize: 14,
                      color: selectedDate != null
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
                    selectedDate == 'Today',
                    (val) => setState(
                      () => selectedDate = selectedDate == 'Today'
                          ? null
                          : 'Today',
                    ),
                  ),
                  _buildCustomChoiceChip(
                    'Yesterday',
                    selectedDate == 'Yesterday',
                    (val) => setState(
                      () => selectedDate = selectedDate == 'Yesterday'
                          ? null
                          : 'Yesterday',
                    ),
                  ),
                  _buildCustomChoiceChip(
                    'Last 7 days',
                    selectedDate == 'Last 7 days',
                    (val) => setState(
                      () => selectedDate = selectedDate == 'Last 7 days'
                          ? null
                          : 'Last 7 days',
                    ),
                  ),
                  _buildCustomChoiceChip(
                    'This month',
                    selectedDate == 'This month',
                    (val) => setState(
                      () => selectedDate = selectedDate == 'This month'
                          ? null
                          : 'This month',
                    ),
                  ),
                  _buildCustomChoiceChip(
                    'Custom range...',
                    selectedDate == 'Custom range...',
                    (val) => setState(
                      () => selectedDate = selectedDate == 'Custom range...'
                          ? null
                          : 'Custom range...',
                    ),
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
                    selectedMovement ?? 'Select Movement',
                    style: TextStyle(
                      fontSize: 14,
                      color: selectedMovement != null
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
                    selectedMovement == 'IN • received',
                    (val) => setState(
                      () =>
                          selectedMovement = selectedMovement == 'IN • received'
                          ? null
                          : 'IN • received',
                    ),
                  ),
                  _buildCustomChoiceChip(
                    'OUT • issued',
                    selectedMovement == 'OUT • issued',
                    (val) => setState(
                      () =>
                          selectedMovement = selectedMovement == 'OUT • issued'
                          ? null
                          : 'OUT • issued',
                    ),
                  ),
                  _buildCustomChoiceChip(
                    'Reversals',
                    selectedMovement == 'Reversals',
                    (val) => setState(
                      () => selectedMovement = selectedMovement == 'Reversals'
                          ? null
                          : 'Reversals',
                    ),
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
                    selectedWarehouse != null
                        ? '$selectedWarehouse • Row B'
                        : 'Select Location',
                    style: TextStyle(
                      fontSize: 14,
                      color: selectedWarehouse != null
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

              // Warehouse Selection Cards Row (Toggleable selection)
              Row(
                children: [
                  // WH1 Card
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          // Tap again to deselect or switch
                          selectedWarehouse = selectedWarehouse == 'WH1'
                              ? null
                              : 'WH1';
                        });
                      },
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

                  // WH2 Card
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedWarehouse = selectedWarehouse == 'WH2'
                              ? null
                              : 'WH2';
                        });
                      },
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

              // Sort Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCustomChoiceChip(
                    'Newest first',
                    selectedSort == 'Newest first',
                    (val) => setState(
                      () => selectedSort = selectedSort == 'Newest first'
                          ? null
                          : 'Newest first',
                    ),
                  ),
                  _buildCustomChoiceChip(
                    'Oldest first',
                    selectedSort == 'Oldest first',
                    (val) => setState(
                      () => selectedSort = selectedSort == 'Oldest first'
                          ? null
                          : 'Oldest first',
                    ),
                  ),
                  _buildCustomChoiceChip(
                    'Largest quantity',
                    selectedSort == 'Largest quantity',
                    (val) => setState(
                      () => selectedSort = selectedSort == 'Largest quantity'
                          ? null
                          : 'Largest quantity',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Show Results Pill Button
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
                    'Show 23 results',
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

  // ChoiceChip helper
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
