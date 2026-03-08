import 'package:flutter/foundation.dart';
import '../services/admin_service.dart';

class AdminProvider extends ChangeNotifier {
  final AdminService _adminService;

  AdminProvider({AdminService? adminService})
      : _adminService = adminService ?? AdminService();

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _dashboard = {};
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _categories = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic> get dashboard => _dashboard;
  List<Map<String, dynamic>> get orders => List.unmodifiable(_orders);
  List<Map<String, dynamic>> get categories => List.unmodifiable(_categories);

  Future<void> loadDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final dashboardResult = await _adminService.getDashboard();
    if (dashboardResult['success'] == true) {
      _dashboard = Map<String, dynamic>.from(dashboardResult['data'] as Map);
    } else {
      _error = dashboardResult['error']?.toString() ?? 'Failed to load dashboard';
    }

    final ordersResult = await _adminService.getOrders();
    if (ordersResult['success'] == true) {
      _orders = (ordersResult['data'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } else {
      _error = ordersResult['error']?.toString() ?? _error;
    }

    final categoriesResult = await _adminService.getCategories();
    if (categoriesResult['success'] == true) {
      _categories = (categoriesResult['data'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } else {
      _error = categoriesResult['error']?.toString() ?? _error;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateOrderStatus({
    required String orderId,
    String? status,
    String? paymentStatus,
  }) async {
    final result = await _adminService.updateOrderStatus(
      orderId: orderId,
      status: status,
      paymentStatus: paymentStatus,
    );

    if (result['success'] != true) {
      _error = result['error']?.toString() ?? 'Failed to update order status';
      notifyListeners();
      return false;
    }

    await loadDashboard();
    return true;
  }

  Future<bool> createCategory({
    required String name,
    String? description,
    String? imageUrl,
  }) async {
    final result = await _adminService.createCategory(
      name: name,
      description: description,
      imageUrl: imageUrl,
    );

    if (result['success'] != true) {
      _error = result['error']?.toString() ?? 'Failed to create category';
      notifyListeners();
      return false;
    }

    await loadDashboard();
    return true;
  }

  Future<bool> deleteCategory(String id) async {
    final result = await _adminService.deleteCategory(id);
    if (result['success'] != true) {
      _error = result['error']?.toString() ?? 'Failed to delete category';
      notifyListeners();
      return false;
    }

    await loadDashboard();
    return true;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
