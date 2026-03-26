import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class OrderProvider extends ChangeNotifier {
  final List<Order> _orders = [];
  final ApiService _apiService = ApiService();

  OrderProvider() {
    loadOrders();
  }

  List<Order> get orders => _orders;

  bool _isGuid(String value) {
    final regex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return regex.hasMatch(value);
  }

  String _generateGuid() {
    final now = DateTime.now();
    final raw = (now.microsecondsSinceEpoch.toRadixString(16) +
            now.millisecondsSinceEpoch.toRadixString(16))
        .padRight(32, '0')
        .substring(0, 32);
    return '${raw.substring(0, 8)}-${raw.substring(8, 12)}-${raw.substring(12, 16)}-${raw.substring(16, 20)}-${raw.substring(20, 32)}';
  }

  Future<void> loadOrders() async {
    try {
      final remote = await _apiService.fetchOrders();
      _orders
        ..clear()
        ..addAll(remote);
      notifyListeners();
    } catch (_) {}
  }

  List<Order> byStatus(OrderStatus? status, {String? userId}) {
    Iterable<Order> filtered = _orders;
    if (userId != null && userId.isNotEmpty) {
      filtered = filtered.where((order) => order.userId == userId);
    }
    if (status == null) return filtered.toList();
    return filtered.where((order) => order.status == status).toList();
  }

  void placeOrder({
    required List<CartItem> cartItems,
    required String shippingAddress,
    required String paymentMethod,
    required bool isPaid,
    String userId = '11111111-1111-1111-1111-111111111111',
  }) {
    final items = cartItems
        .map(
          (item) => OrderItem(
            product: Product(
              id: item.product.id,
              name: item.product.name,
              price: item.product.price,
              category: item.product.category,
              description: item.product.description,
              imageUrls: item.product.imageUrls,
              sizes: item.product.sizes,
              colors: item.product.colors,
              reviewsCount: item.product.reviewsCount,
              discountPercent: item.product.discountPercent,
            ),
            quantity: item.quantity,
            size: item.size,
          ),
        )
        .toList();

    final orderId = _generateGuid();
    final orderCode = 'OD${DateTime.now().millisecondsSinceEpoch}';
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final normalizedUserId =
        _isGuid(userId) ? userId : '11111111-1111-1111-1111-111111111111';

    _orders.insert(
      0,
      Order(
        id: orderId,
        userId: normalizedUserId,
        createdAt: DateTime.now(),
        items: items,
        shippingAddress: shippingAddress,
        paymentMethod: paymentMethod,
        status: OrderStatus.processing,
        isPaid: isPaid,
      ),
    );

    _apiService.createOrder(
      id: orderId,
      orderCode: orderCode,
      userId: normalizedUserId,
      shippingAddress: shippingAddress,
      paymentMethod: paymentMethod,
      paymentStatus: isPaid ? 'paid' : 'pending',
      status: 'processing',
      subtotal: subtotal,
      discountAmount: 0,
      total: subtotal,
      items: cartItems
          .map(
            (item) => {
              'productId': item.product.id,
              'sizeLabel': item.size,
              'colorHex': null,
              'quantity': item.quantity,
              'unitPrice': item.product.finalPrice,
              'lineTotal': item.lineTotal,
            },
          )
          .toList(),
    );

    notifyListeners();
  }

  void changeOrderStatus(String orderId, OrderStatus status) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return;
    _orders[index] = _orders[index].copyWith(status: status);
    notifyListeners();
    _apiService.updateOrderStatus(orderId, status);
  }
}
