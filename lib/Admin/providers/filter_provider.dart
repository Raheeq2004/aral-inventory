import 'package:flutter/material.dart';

class TransactionFilterProvider extends ChangeNotifier {
  String? _selectedDate;
  DateTimeRange? _customDateRange;
  String? _selectedMovement;
  String? _selectedWarehouse;
  double? _selectedLength;
  bool _isCustomLength = false;
  String? _selectedSort;

  // Getters
  String? get selectedDate => _selectedDate;
  DateTimeRange? get customDateRange => _customDateRange;
  String? get selectedMovement => _selectedMovement;
  String? get selectedWarehouse => _selectedWarehouse;
  double? get selectedLength => _selectedLength;
  bool get isCustomLength => _isCustomLength;
  String? get selectedSort => _selectedSort;

  // Count of active filters (excluding sort or including depending on preference)
  int get activeFiltersCount {
    return [
      _selectedDate,
      _customDateRange,
      _selectedMovement,
      _selectedWarehouse,
      _selectedLength,
      _selectedSort,
    ].where((f) => f != null).length;
  }

  bool get hasActiveFilters => activeFiltersCount > 0;

  // Setters / Actions

  //Setter for Length (handles both preset chips and custom text input)
  void setLength(double? length, {bool isCustom = false}) {
    if (isCustom) {
      _isCustomLength = true;
      _selectedLength = length;
    } else {
      _isCustomLength = false;
      _selectedLength = (_selectedLength == length) ? null : length;
    }
    notifyListeners();
  }

  // <-- ADDED: Toggles the Custom length chip on/off
  void selectCustomLength() {
    if (_isCustomLength) {
      _isCustomLength = false;
      _selectedLength = null;
    } else {
      _isCustomLength = true;
      _selectedLength = null; // Clear any previously selected preset
    }
    notifyListeners();
  }

  // Update setDate inside TransactionFilterProvider:
  void setDate(String? date) {
    _selectedDate = (_selectedDate == date) ? null : date;
    if (_selectedDate == null) {
      _customDateRange = null; // <-- Clear range bounds too when date is wiped
    }
    notifyListeners();
  }

  void setMovement(String? movement) {
    _selectedMovement = (_selectedMovement == movement) ? null : movement;
    notifyListeners();
  }

  void setWarehouse(String? warehouse) {
    _selectedWarehouse = (_selectedWarehouse == warehouse) ? null : warehouse;
    notifyListeners();
  }

  void setSort(String? sort) {
    _selectedSort = (_selectedSort == sort) ? null : sort;
    notifyListeners();
  }

  void setCustomDateRange(DateTimeRange range) {
    _customDateRange = range;
    // Format a nice readable string for the chip/label e.g. "Nov 1 - Nov 9"
    final start = '${range.start.day} ${_getMonthName(range.start.month)}';
    final end = '${range.end.day} ${_getMonthName(range.end.month)}';
    _selectedDate = '$start - $end';
    notifyListeners();
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  void resetAll() {
    _selectedDate = null;
    _customDateRange = null;
    _selectedMovement = null; // FIX: was not cleared by Reset / Clear all
    _selectedWarehouse = null;
    _selectedLength = null;
    _isCustomLength = false;
    _selectedSort = null;
    notifyListeners();
  }
}
