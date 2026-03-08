import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../services/cart_storage_service.dart';
import '../services/coupon_service.dart';

class CartItem {
  final String productId;
  final String productName;
  final String imageUrl;
  final double unitPrice;
  final double discountPercent;
  int quantity;
  final String sizeLabel;
  final String? colorHex;

  CartItem({
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.unitPrice,
    required this.discountPercent,
    required this.quantity,
    required this.sizeLabel,
    this.colorHex,
  });

  double get finalPrice => unitPrice * (1 - discountPercent / 100);
  double get lineTotal => finalPrice * quantity;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'quantity': quantity,
      'sizeLabel': sizeLabel,
      'colorHex': colorHex,
      'unitPrice': unitPrice,
      'lineTotal': lineTotal,
    };
  }

  factory CartItem.fromProduct(
    Product product, {
    required int quantity,
    required String sizeLabel,
    String? colorHex,
  }) {
    return CartItem(
      productId: product.id,
      productName: product.name,
      imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : '',
      unitPrice: product.price,
      discountPercent: product.discountPercent ?? 0,
      quantity: quantity,
      sizeLabel: sizeLabel,
      colorHex: colorHex,
    );
  }
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  bool _isLoading = false;
  String? _error;
  
  // Coupon & Discount Fields
  String? _appliedCouponCode;
  double _discountPercent = 0.0;
  double _discountAmount = 0.0;
  final CouponService _couponService = CouponService();

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;
  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Coupon Getters
  String? get appliedCouponCode => _appliedCouponCode;
  double get discountPercent => _discountPercent;
  double get discountAmount => _discountAmount;

  double get subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);
  double get estimatedTax => (subtotal - _discountAmount) * 0.1; // 10% tax on discounted amount
  double get shippingFee => (subtotal - _discountAmount) > 100 ? 0 : 5.0; // Free shipping over $100
  double get total => subtotal - _discountAmount + estimatedTax + shippingFee;

  /// Load cart from local storage
  Future<void> loadCart() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final savedItems = await CartStorageService.loadCart();
      _items.clear();
      _items.addAll(savedItems);
      _error = null;
    } catch (e) {
      _error = 'Failed to load cart: ${e.toString()}';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save cart to local storage
  Future<void> _saveCart() async {
    try {
      await CartStorageService.saveCart(_items);
    } catch (e) {
      print('Error saving cart to storage: $e');
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Add item to cart or update quantity if exists
  void addItem(CartItem item) {
    final existingIndex = _items.indexWhere(
      (i) =>
          i.productId == item.productId &&
          i.sizeLabel == item.sizeLabel &&
          i.colorHex == item.colorHex,
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += item.quantity;
    } else {
      _items.add(item);
    }
    _saveCart();
    notifyListeners();
  }

  /// Update quantity of existing item
  void updateQuantity(int index, int quantity) {
    if (index < 0 || index >= _items.length) return;

    if (quantity <= 0) {
      removeItem(index);
    } else {
      _items[index].quantity = quantity;
      _saveCart();
      notifyListeners();
    }
  }

  /// Remove item from cart
  void removeItem(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    _saveCart();
    notifyListeners();
  }

  /// Remove item by product ID
  void removeItemByProductId(String productId) {
    _items.removeWhere((item) => item.productId == productId);
    _saveCart();
    notifyListeners();
  }

  /// Clear entire cart
  void clear() {
    _items.clear();
    _saveCart();
    notifyListeners();
  }

  /// Check if product exists in cart
  bool hasProduct(String productId) {
    return _items.any((item) => item.productId == productId);
  }

  /// Get quantity of product
  int getProductQuantity(String productId) {
    try {
      return _items.firstWhere((item) => item.productId == productId).quantity;
    } catch (e) {
      return 0;
    }
  }

  /// Convert cart to API payload format
  Map<String, dynamic> toApiPayload({
    required String userId,
    required String shippingAddress,
    required String paymentMethod,
    String? discountCode,
  }) {
    double discountAmount = 0;
    if (discountCode != null) {
      // Apply discount logic here
      discountAmount = subtotal * 0.1; // 10% discount example
    }

    return {
      'userId': userId,
      'shippingAddress': shippingAddress,
      'paymentMethod': paymentMethod,
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'total': total - discountAmount,
      'items': _items.map((item) => item.toJson()).toList(),
    };
  }

  /// Apply coupon code to cart
  Future<Map<String, dynamic>> applyCoupon(String couponCode) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _couponService.applyCoupon(
        couponCode: couponCode,
        subtotal: subtotal,
      );

      if (result['valid'] as bool) {
        _appliedCouponCode = couponCode;
        _discountPercent = (result['discountPercent'] as num?)?.toDouble() ?? 0.0;
        _discountAmount = (result['discountAmount'] as num?)?.toDouble() ?? 0.0;
        _error = null;
      } else {
        _error = result['message'] as String?;
        _appliedCouponCode = null;
        _discountPercent = 0.0;
        _discountAmount = 0.0;
      }

      notifyListeners();
      return result;
    } catch (e) {
      _error = 'Error applying coupon: ${e.toString()}';
      _appliedCouponCode = null;
      _discountPercent = 0.0;
      _discountAmount = 0.0;
      notifyListeners();
      return {
        'valid': false,
        'message': _error,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Remove applied coupon
  void removeCoupon() {
    _appliedCouponCode = null;
    _discountPercent = 0.0;
    _discountAmount = 0.0;
    _error = null;
    notifyListeners();
  }

  /// Get cart summary for display
  Map<String, dynamic> getSummary() {
    return {
      'itemCount': itemCount,
      'totalQuantity': totalQuantity,
      'subtotal': subtotal,
      'discountAmount': _discountAmount,
      'tax': estimatedTax,
      'shipping': shippingFee,
      'total': total,
      'appliedCoupon': _appliedCouponCode,
      'items': items,
    };
  }
}
