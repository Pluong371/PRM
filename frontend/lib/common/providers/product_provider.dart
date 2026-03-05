import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';

class ProductProvider extends ChangeNotifier {
  final ProductService productService;
  final String baseUrl;

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  Product? _selectedProduct;
  bool _isLoading = false;
  String? _error;
  
  // Filters
  String? _selectedCategory;
  String _searchQuery = '';

  ProductProvider({
    ProductService? productService,
    String? baseUrl,
  })  : productService = productService ?? ProductService(dio: Dio(), baseUrl: baseUrl ?? 'http://localhost:3000'),
        baseUrl = baseUrl ?? 'http://localhost:3000';

  // Getters
  List<Product> get allProducts => List.unmodifiable(_allProducts);
  List<Product> get filteredProducts => List.unmodifiable(_filteredProducts);
  Product? get selectedProduct => _selectedProduct;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  /// Fetch all products from API
  Future<void> fetchProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await productService.getProducts();
      if (result['success']) {
        _allProducts = result['data'] ?? [];
        _applyFilters();
        _error = null;
      } else {
        _error = result['error'] as String? ?? 'Failed to fetch products';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get product details by ID
  Future<void> fetchProductById(String productId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await productService.getProductById(productId);
      if (result['success']) {
        _selectedProduct = result['data'];
        _error = null;
      } else {
        _error = result['error'] as String? ?? 'Failed to fetch product details';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search products by query
  Future<void> searchProducts(String query) async {
    _searchQuery = query;
    
    if (query.isEmpty) {
      _filteredProducts = List.from(_allProducts);
    } else {
      final lowerQuery = query.toLowerCase();
      _filteredProducts = _allProducts.where((product) {
        return product.name.toLowerCase().contains(lowerQuery) ||
            (product.description?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    }
    
    notifyListeners();
  }

  /// Filter products by category
  void filterByCategory(String? category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  /// Apply all active filters
  void _applyFilters() {
    _filteredProducts = _allProducts.where((product) {
      // Apply category filter
      if (_selectedCategory != null && product.category != _selectedCategory) {
        return false;
      }

      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final lowerQuery = _searchQuery.toLowerCase();
        if (!product.name.toLowerCase().contains(lowerQuery) &&
            !(product.description?.toLowerCase().contains(lowerQuery) ?? false)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Get unique categories from products
  List<String> getCategories() {
    final categories = <String>{};
    for (var product in _allProducts) {
      if (product.category.isNotEmpty) {
        categories.add(product.category);
      }
    }
    return categories.toList();
  }

  /// Clear selected product
  void clearSelectedProduct() {
    _selectedProduct = null;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _selectedCategory = null;
    _searchQuery = '';
    _filteredProducts = List.from(_allProducts);
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get product by ID from cached list
  Product? getCachedProduct(String productId) {
    try {
      return _allProducts.firstWhere((product) => product.id == productId);
    } catch (e) {
      return null;
    }
  }

  /// Get products by category
  List<Product> getProductsByCategory(String category) {
    return _allProducts.where((product) => product.category == category).toList();
  }

  /// Sort products by price (low to high)
  void sortByPriceLowToHigh() {
    _filteredProducts.sort((a, b) => a.finalPrice.compareTo(b.finalPrice));
    notifyListeners();
  }

  /// Sort products by price (high to low)
  void sortByPriceHighToLow() {
    _filteredProducts.sort((a, b) => b.finalPrice.compareTo(a.finalPrice));
    notifyListeners();
  }

  /// Sort products by name (A-Z)
  void sortByNameAZ() {
    _filteredProducts.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  /// Sort products by newest first
  void sortByNewest() {
    _filteredProducts.sort((a, b) => b.id.compareTo(a.id));
    notifyListeners();
  }

  /// Get products on sale
  List<Product> getOnSaleProducts() {
    return _filteredProducts.where((product) => product.hasDiscount).toList();
  }

  /// Get available products
  List<Product> getAvailableProducts() {
    return _filteredProducts.where((product) => product.isAvailable).toList();
  }

  /// Get total product count
  int get productCount => _allProducts.length;

  /// Get filtered product count
  int get filteredProductCount => _filteredProducts.length;

  /// Check if product is in stock
  bool isProductAvailable(String productId) {
    final product = getCachedProduct(productId);
    return product != null && product.isAvailable;
  }

  /// Get average price of products
  double getAveragePrice() {
    if (_filteredProducts.isEmpty) return 0;
    final sum = _filteredProducts.fold<double>(
      0,
      (sum, product) => sum + product.finalPrice,
    );
    return sum / _filteredProducts.length;
  }
}
