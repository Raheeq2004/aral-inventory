import 'package:flutter/foundation.dart';

class TransactionFilterProvider extends ChangeNotifier {
  String? _selectedDate;
  String? _selectedMovement;
  String? _selectedWarehouse;
  String? _selectedSort;

  // Getters
  String? get selectedDate => _selectedDate;
  String? get selectedMovement => _selectedMovement;
  String? get selectedWarehouse => _selectedWarehouse;
  String? get selectedSort => _selectedSort;

  // Count of active filters (excluding sort or including depending on preference)
  int get activeFiltersCount {
    return [
      _selectedDate,
      _selectedMovement,
      _selectedWarehouse,
      _selectedSort,
    ].where((f) => f != null).length;
  }

  bool get hasActiveFilters => activeFiltersCount > 0;

  // Setters / Actions
  void setDate(String? date) {
    _selectedDate = (_selectedDate == date) ? null : date;
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

  void resetAll() {
    _selectedDate = null;
    _selectedMovement = null;
    _selectedWarehouse = null;
    _selectedSort = null;
    notifyListeners();
  }
}
