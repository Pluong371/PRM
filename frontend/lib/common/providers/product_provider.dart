import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';

class ProductProvider extends ChangeNotifier {
  final ProductService _productService;

  List<Product> _products = [];
  Product? _selectedProduct;
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedCategory;
  String? _searchQuery;

  ProductProvider({
    ProductService? productService,
  }) : _productService = productService ?? ProductService();

  // Getters
  List<Product> get products => _products;
  Product? get selectedProduct => _selectedProduct;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedCategory => _selectedCategory;
  String? get searchQuery => _searchQuery;

  List<Product> get filteredProducts {
    var filtered = _products;

    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }

    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      final query = _searchQuery!.toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.category.toLowerCase().contains(query) ||
            (p.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  List<String> get categories {
    final categorySet = <String>{};
    for (var product in _products) {
      categorySet.add(product.category);
    }
    return categorySet.toList()..sort();
  }

  Future<void> fetchProducts({String? token}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _products = await _productService.getProducts(token: token);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchProductById(String id, {String? token}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedProduct = await _productService.getProductById(id, token: token);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchProducts({
    String? query,
    String? category,
    String? token,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _products = await _productService.searchProducts(
        query: query,
        category: category,
        token: token,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _selectedCategory = null;
    _searchQuery = null;
    notifyListeners();
  }

  void selectProduct(Product? product) {
    _selectedProduct = product;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refreshProducts({String? token}) async {
    await fetchProducts(token: token);
  }
}
