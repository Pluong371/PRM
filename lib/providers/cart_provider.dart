import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  double _discountPercent = 0;
  String? _appliedCode;

  List<CartItem> get items => _items;
  String? get appliedCode => _appliedCode;
  int get itemCount => _items.fold<int>(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);

  double get discountAmount => subtotal * (_discountPercent / 100);

  double get total => subtotal - discountAmount;

  void addToCart(Product product, {required String size}) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id && item.size == size,
    );

    if (existingIndex >= 0) {
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + 1,
      );
    } else {
      _items.add(CartItem(product: product, quantity: 1, size: size));
    }

    notifyListeners();
  }

  void increaseQuantity(int index) {
    _items[index] = _items[index].copyWith(
      quantity: _items[index].quantity + 1,
    );
    notifyListeners();
  }

  void decreaseQuantity(int index) {
    if (_items[index].quantity == 1) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(
        quantity: _items[index].quantity - 1,
      );
    }
    notifyListeners();
  }

  void removeAt(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  bool applyDiscount({required String code, required double percent}) {
    if (subtotal <= 0) return false;
    _appliedCode = code;
    _discountPercent = percent;
    notifyListeners();
    return true;
  }

  void clearDiscount() {
    _appliedCode = null;
    _discountPercent = 0;
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    clearDiscount();
    notifyListeners();
  }
}
