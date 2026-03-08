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
  double _minPrice = 0;
  double _maxPrice = 999999;
  bool _inStockOnly = false;
  String _sortBy = 'newest';
  int _currentPage = 1;
  int _totalPages = 1;

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
  double get minPrice => _minPrice;
  double get maxPrice => _maxPrice;
  bool get inStockOnly => _inStockOnly;
  String get sortBy => _sortBy;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;

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

  /// Advanced search with filters
  Future<void> searchAdvanced({
    String query = '',
    double? minPrice,
    double? maxPrice,
    String? categoryId,
    bool inStockOnly = false,
    String sortBy = 'newest',
    int page = 1,
  }) async {
    _isLoading = true;
    _error = null;
    _searchQuery = query;
    _minPrice = minPrice ?? 0;
    _maxPrice = maxPrice ?? 999999;
    _inStockOnly = inStockOnly;
    _sortBy = sortBy;
    _currentPage = page;
    _selectedCategory = categoryId;
    notifyListeners();

    try {
      final result = await productService.searchAdvanced(
        query: query,
        minPrice: minPrice,
        maxPrice: maxPrice,
        categoryId: categoryId,
        inStockOnly: inStockOnly,
        sortBy: sortBy,
        page: page,
        limit: 50,
      );

      if (result['success']) {
        _filteredProducts = result['data'] ?? [];
        final pagination = result['pagination'] as Map<String, dynamic>?;
        _totalPages = pagination?['totalPages'] ?? 1;
        _error = null;
      } else {
        _error = result['error'] as String? ?? 'Search failed';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set price range filter
  void setPriceRange(double min, double max) {
    _minPrice = min;
    _maxPrice = max;
    notifyListeners();
  }

  /// Toggle in stock only filter
  void setInStockOnly(bool value) {
    _inStockOnly = value;
    notifyListeners();
  }

  /// Set sort option
  void setSortBy(String sortOption) {
    _sortBy = sortOption;
    notifyListeners();
  }
}
