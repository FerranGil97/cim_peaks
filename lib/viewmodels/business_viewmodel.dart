import 'package:flutter/material.dart';
import '../data/models/business_model.dart';
import '../data/repositories/business_repository.dart';

class BusinessViewModel extends ChangeNotifier {
  final BusinessRepository _repository = BusinessRepository();

  List<BusinessModel> _businesses = [];
  BusinessType? _selectedType;
  String _searchQuery = '';
  bool _isLoading = false;

  List<BusinessModel> get businesses {
    var results = _businesses;

    if (_selectedType != null) {
      results = results
          .where((b) => b.type == _selectedType)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      results = results
          .where((b) =>
              b.name
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              (b.comarca
                      ?.toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ??
                  false))
          .toList();
    }

    // Primer els Pro
    results.sort((a, b) => b.isPro ? 1 : -1);
    return results;
  }

  BusinessType? get selectedType => _selectedType;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  void loadBusinesses() {
    _isLoading = true;
    notifyListeners();
    _repository.getBusinesses().listen((businesses) {
      _businesses = businesses;
      _isLoading = false;
      notifyListeners();
    });
  }

  void setTypeFilter(BusinessType? type) {
    _selectedType = type;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }
}