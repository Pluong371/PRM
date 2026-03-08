import 'package:dio/dio.dart';
import '../models/order_model.dart';

class OrderService {
  final Dio dio;
  final String baseUrl;

  OrderService({
    required this.dio,
    required this.baseUrl,
  });

  /// Create a new order
  /// Returns order ID on success
  Future<Map<String, dynamic>> createOrder({
    required String userId,
    required String shippingAddress,
    required String paymentMethod,
    required double subtotal,
    required double discountAmount,
    required double total,
    required List<Map<String, dynamic>> items,
    String? orderCode,
    String paymentStatus = 'pending',
    String status = 'processing',
  }) async {
    try {
      final response = await dio.post(
        '$baseUrl/api/orders',
        data: {
          'id': _generateGuid(),
          'orderCode': orderCode ?? _generateOrderCode(),
          'userId': userId,
          'shippingAddress': shippingAddress,
          'paymentMethod': paymentMethod,
          'paymentStatus': paymentStatus,
          'status': status,
          'subtotal': subtotal,
          'discountAmount': discountAmount,
          'total': total,
          'items': items,
        },
      );

      return {
        'success': response.statusCode == 201,
        'data': response.data,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  /// Get order by ID
  Future<Map<String, dynamic>> getOrderById(String orderId) async {
    try {
      final response = await dio.get(
        '$baseUrl/api/orders/$orderId',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': Order.fromJson(response.data),
        };
      }
      return {
        'success': false,
        'error': 'Failed to fetch order',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  /// Get user's orders (requires authentication)
  Future<Map<String, dynamic>> getUserOrders() async {
    try {
      final response = await dio.get(
        '$baseUrl/api/orders',
      );

      if (response.statusCode == 200) {
        final orders = (response.data as List)
            .map((item) => Order.fromJson(item as Map<String, dynamic>))
            .toList();
        return {
          'success': true,
          'data': orders,
        };
      }
      return {
        'success': false,
        'error': 'Failed to fetch orders',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  /// Update order status (Admin only)
  Future<Map<String, dynamic>> updateOrderStatus(
    String orderId,
    String status,
  ) async {
    try {
      final response = await dio.patch(
        '$baseUrl/api/orders/$orderId/status',
        data: {'status': status},
      );

      return {
        'success': response.statusCode == 200,
        'data': response.data,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  /// Cancel order (user can only cancel processing orders)
  Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    try {
      final response = await dio.patch(
        '$baseUrl/api/orders/$orderId/status',
        data: {'status': 'cancelled'},
      );

      return {
        'success': response.statusCode == 200,
        'message': 'Order cancelled successfully',
        'data': response.data,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  String _generateGuid() {
    return '${DateTime.now().millisecondsSinceEpoch}-${(DateTime.now().microsecond).toString().padLeft(6, '0')}';
  }

  String _generateOrderCode() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final random = (DateTime.now().microsecond % 99999).toString().padLeft(5, '0');
    return 'ORD-$dateStr-$random';
  }
}
