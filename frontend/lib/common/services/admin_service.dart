import 'package:dio/dio.dart';

class AdminService {
  final Dio dio;
  final String baseUrl;

  AdminService({
    Dio? dio,
    String? baseUrl,
  })  : dio = dio ?? Dio(),
        baseUrl = baseUrl ?? 'http://localhost:3000';

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final response = await dio.get('$baseUrl/api/admin/dashboard');
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  Future<Map<String, dynamic>> getOrders() async {
    try {
      final response = await dio.get('$baseUrl/api/admin/orders');
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    String? status,
    String? paymentStatus,
  }) async {
    try {
      final response = await dio.patch(
        '$baseUrl/api/admin/orders/$orderId/status',
        data: {
          if (status != null) 'status': status,
          if (paymentStatus != null) 'paymentStatus': paymentStatus,
        },
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  Future<Map<String, dynamic>> getCategories() async {
    try {
      final response = await dio.get('$baseUrl/api/categories');
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  Future<Map<String, dynamic>> createCategory({
    required String name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final response = await dio.post(
        '$baseUrl/api/categories',
        data: {
          'name': name,
          'description': description,
          'imageUrl': imageUrl,
        },
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  Future<Map<String, dynamic>> updateCategory({
    required String id,
    required String name,
    String? description,
    String? imageUrl,
    bool isActive = true,
  }) async {
    try {
      final response = await dio.put(
        '$baseUrl/api/categories/$id',
        data: {
          'name': name,
          'description': description,
          'imageUrl': imageUrl,
          'isActive': isActive,
        },
      );
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  Future<Map<String, dynamic>> deleteCategory(String id) async {
    try {
      final response = await dio.delete('$baseUrl/api/categories/$id');
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  Future<Map<String, dynamic>> getUsers() async {
    try {
      final response = await dio.get('$baseUrl/api/users');
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  Future<Map<String, dynamic>> toggleUserActive(String userId) async {
    try {
      final response = await dio.patch('$baseUrl/api/users/$userId/toggle-active');
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }
}
