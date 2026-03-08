import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/notification_model.dart';

class NotificationService {
  final Dio dio;
  final String baseUrl;
  final FlutterSecureStorage secureStorage;

  NotificationService({
    Dio? dio,
    String? baseUrl,
    FlutterSecureStorage? secureStorage,
  })  : dio = dio ?? Dio(),
        baseUrl = baseUrl ?? 'http://localhost:3000',
        secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<Options> _authOptions() async {
    final token = await secureStorage.read(key: 'auth_token');
    return Options(
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }

  Future<Map<String, dynamic>> getNotifications() async {
    try {
      final response = await dio.get(
        '$baseUrl/api/notifications',
        options: await _authOptions(),
      );
      final notifications = (response.data as List)
          .map((item) => UserNotification.fromJson(item as Map<String, dynamic>))
          .toList();
      return {'success': true, 'data': notifications};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  Future<Map<String, dynamic>> markAsRead(String id) async {
    try {
      final response = await dio.patch(
        '$baseUrl/api/notifications/$id/read',
        options: await _authOptions(),
      );
      return {'success': response.statusCode == 200};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  Future<Map<String, dynamic>> markAllAsRead() async {
    try {
      final response = await dio.patch(
        '$baseUrl/api/notifications/read-all',
        options: await _authOptions(),
      );
      return {'success': response.statusCode == 200};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }
}
