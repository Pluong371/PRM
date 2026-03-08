import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';

/// Service to persist and restore cart from local storage
class CartStorageService {
  static const String _cartKey = 'shopping_cart';
  static late SharedPreferences _prefs;

  /// Initialize SharedPreferences
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Save cart items to local storage
  static Future<bool> saveCart(List<CartItem> items) async {
    try {
      final List<Map<String, dynamic>> cartData = items
          .map((item) => {
                'productId': item.productId,
                'productName': item.productName,
                'imageUrl': item.imageUrl,
                'unitPrice': item.unitPrice,
                'discountPercent': item.discountPercent,
                'quantity': item.quantity,
                'sizeLabel': item.sizeLabel,
                'colorHex': item.colorHex,
              })
          .toList();

      final jsonString = jsonEncode(cartData);
      return await _prefs.setString(_cartKey, jsonString);
    } catch (e) {
      print('Error saving cart: $e');
      return false;
    }
  }

  /// Load cart items from local storage
  static Future<List<CartItem>> loadCart() async {
    try {
      final jsonString = _prefs.getString(_cartKey);
      if (jsonString == null) {
        return [];
      }

      final List<dynamic> cartData = jsonDecode(jsonString);
      return cartData
          .map((item) => CartItem(
                productId: item['productId'] ?? '',
                productName: item['productName'] ?? 'Unknown',
                imageUrl: item['imageUrl'] ?? '',
                unitPrice: (item['unitPrice'] ?? 0).toDouble(),
                discountPercent: (item['discountPercent'] ?? 0).toDouble(),
                quantity: item['quantity'] ?? 1,
                sizeLabel: item['sizeLabel'] ?? '',
                colorHex: item['colorHex'],
              ))
          .toList();
    } catch (e) {
      print('Error loading cart: $e');
      return [];
    }
  }

  /// Clear cart from local storage
  static Future<bool> clearCart() async {
    try {
      return await _prefs.remove(_cartKey);
    } catch (e) {
      print('Error clearing cart: $e');
      return false;
    }
  }

  /// Check if cart exists in storage
  static bool hasCart() {
    return _prefs.containsKey(_cartKey);
  }

  /// Get cart size from storage
  static Future<int> getCartSize() async {
    try {
      final jsonString = _prefs.getString(_cartKey);
      if (jsonString == null) {
        return 0;
      }
      final List<dynamic> cartData = jsonDecode(jsonString);
      return cartData.length;
    } catch (e) {
      print('Error getting cart size: $e');
      return 0;
    }
  }
}
