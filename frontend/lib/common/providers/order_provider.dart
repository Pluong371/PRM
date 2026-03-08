import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';

class OrderProvider extends ChangeNotifier {
  final OrderService orderService;
  final String baseUrl;

  List<Order> _userOrders = [];
  Order? _selectedOrder;
  bool _isLoading = false;
  String? _error;

  OrderProvider({
    required this.orderService,
    required this.baseUrl,
  });

  // Getters
  List<Order> get userOrders => List.unmodifiable(_userOrders);
  Order? get selectedOrder => _selectedOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch all user orders from API
  Future<void> fetchUserOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await orderService.getUserOrders();
      if (result['success']) {
        _userOrders = result['data'] ?? [];
        _error = null;
      } else {
        _error = result['error'] as String? ?? 'Failed to fetch orders';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get order details by ID
  Future<void> fetchOrderById(String orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await orderService.getOrderById(orderId);
      if (result['success']) {
        _selectedOrder = result['data'];
        _error = null;
      } else {
        _error = result['error'] as String? ?? 'Failed to fetch order';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create order
  Future<bool> createOrder({
    required String userId,
    required String shippingAddress,
    required String paymentMethod,
    required double subtotal,
    required double discountAmount,
    required double total,
    required List<Map<String, dynamic>> items,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await orderService.createOrder(
        userId: userId,
        shippingAddress: shippingAddress,
        paymentMethod: paymentMethod,
        subtotal: subtotal,
        discountAmount: discountAmount,
        total: total,
        items: items,
      );

      if (result['success']) {
        _error = null;
        return true;
      } else {
        _error = result['error'] as String? ?? 'Failed to create order';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update order status (admin only)
  Future<bool> updateOrderStatus(String orderId, String status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await orderService.updateOrderStatus(orderId, status);
      if (result['success']) {
        // Update the selected order if it matches
        if (_selectedOrder?.id == orderId) {
          _selectedOrder = _selectedOrder?.copyWith(status: status);
        }
        // Update in user orders list
        final index = _userOrders.indexWhere((o) => o.id == orderId);
        if (index >= 0) {
          _userOrders[index] = _userOrders[index].copyWith(status: status);
        }
        _error = null;
        return true;
      } else {
        _error = result['error'] as String? ?? 'Failed to update order';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear selected order
  void clearSelectedOrder() {
    _selectedOrder = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get order by ID from cached list
  Order? getCachedOrder(String orderId) {
    try {
      return _userOrders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      return null;
    }
  }

  /// Get orders by status
  List<Order> getOrdersByStatus(String status) {
    return _userOrders.where((order) => order.status == status).toList();
  }

  /// Get total order count
  int get orderCount => _userOrders.length;

  /// Get pending orders count
  int get pendingOrdersCount => _userOrders.where((o) => o.status == 'processing').length;

  /// Get delivered orders count
  int get deliveredOrdersCount => _userOrders.where((o) => o.status == 'delivered').length;
}
