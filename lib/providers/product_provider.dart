import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  final List<Product> _products = [];
  final ApiService _apiService = ApiService();
  String _selectedCategory = 'All';
  String _searchKeyword = '';
  bool _isLoading = true;

  ProductProvider() {
    loadProducts();
  }

  List<Product> get products => _products;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  bool get hasActiveSearch => _searchKeyword.trim().isNotEmpty;

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  bool _matchesCategory(Product product, String selectedCategory) {
    final selected = _normalize(selectedCategory);
    final category = _normalize(product.category);

    if (selected == 'all') return true;
    if (selected == 'sale') {
      return (product.discountPercent ?? 0) > 0 || category.contains('sale');
    }
    if (selected == 'new arrival') {
      return category.contains('new') || category.contains('arrival');
    }
    if (selected == 'shoes') {
      return category.contains('shoe') || category.contains('giay');
    }
    if (selected == 'men') {
      return category.contains('men') || category.contains('nam');
    }
    if (selected == 'women') {
      return category.contains('women') || category.contains('nu');
    }
    if (selected == 'kids') {
      return category.contains('kid') ||
          category.contains('children') ||
          category.contains('tre');
    }

    return category == selected || category.contains(selected);
  }

  List<Product> get filteredProducts {
    return _products.where((product) {
      final categoryMatch = _matchesCategory(product, _selectedCategory);
      final searchMatch = product.name.toLowerCase().contains(
            _searchKeyword.trim().toLowerCase(),
          );
      return categoryMatch && searchMatch;
    }).toList();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void search(String keyword) {
    _searchKeyword = keyword;
    notifyListeners();
  }

  Product getById(String id) {
    return _products.firstWhere((product) => product.id == id);
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();
    try {
      final remote = await _apiService.fetchProducts();
      _products
        ..clear()
        ..addAll(remote);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  void addProduct(Product product) {
    _products.insert(0, product);
    notifyListeners();
    _apiService.createProduct(product);
  }

  void updateProduct(Product product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index == -1) return;
    _products[index] = product;
    notifyListeners();
    _apiService.updateProduct(product);
  }

  void deleteProduct(String id) {
    _products.removeWhere((product) => product.id == id);
    notifyListeners();
    _apiService.deleteProduct(id);
  }
}
