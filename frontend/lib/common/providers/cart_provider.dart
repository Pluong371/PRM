import 'package:flutter/foundation.dart';
import '../models/product_model.dart';

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

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;
  int get totalQuantity => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);
  double get estimatedTax => subtotal * 0.1; // 10% tax
  double get shippingFee => subtotal > 100 ? 0 : 5.0; // Free shipping over $100
  double get total => subtotal + estimatedTax + shippingFee;

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
    notifyListeners();
  }

  /// Update quantity of existing item
  void updateQuantity(int index, int quantity) {
    if (index < 0 || index >= _items.length) return;

    if (quantity <= 0) {
      removeItem(index);
    } else {
      _items[index].quantity = quantity;
      notifyListeners();
    }
  }

  /// Remove item from cart
  void removeItem(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    notifyListeners();
  }

  /// Remove item by product ID
  void removeItemByProductId(String productId) {
    _items.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  /// Clear entire cart
  void clear() {
    _items.clear();
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

  /// Get cart summary for display
  Map<String, dynamic> getSummary() {
    return {
      'itemCount': itemCount,
      'totalQuantity': totalQuantity,
      'subtotal': subtotal,
      'tax': estimatedTax,
      'shipping': shippingFee,
      'total': total,
      'items': items,
    };
  }
}
