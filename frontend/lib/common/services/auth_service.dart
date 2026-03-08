import 'package:dio/dio.dart';
import '../models/user_model.dart';

class AuthService {
  final Dio _dio;
  final String baseUrl;

  AuthService({
    Dio? dio,
    this.baseUrl = 'http://localhost:3000/api',
  }) : _dio = dio ?? Dio();

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl/auth/register',
        data: {
          'fullName': fullName,
          'email': email,
          'password': password,
          'phone': phone,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'token': response.data['token'],
          'user': User.fromJson(response.data['user']),
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Registration failed',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'token': response.data['token'],
          'user': User.fromJson(response.data['user']),
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Login failed',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> getCurrentUser(String token) async {
    try {
      final response = await _dio.get(
        '$baseUrl/auth/me',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': User.fromJson(response.data),
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch user',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'Network error',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Update user profile (fullName, email, phone)
  Future<Map<String, dynamic>> updateProfile({
    required String token,
    String? fullName,
    String? email,
    String? phone,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (fullName != null) data['fullName'] = fullName;
      if (email != null) data['email'] = email;
      if (phone != null) data['phone'] = phone;

      if (data.isEmpty) {
        return {
          'success': false,
          'message': 'No fields to update',
        };
      }

      final response = await _dio.patch(
        '$baseUrl/auth/me',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': User.fromJson(response.data['user']),
          'message': response.data['message'] ?? 'Profile updated',
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Update failed',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ??
            e.message ??
            'Network error',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Logout (server-side logout endpoint)
  Future<Map<String, dynamic>> logout(String token) async {
    try {
      final response = await _dio.post(
        '$baseUrl/auth/logout',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'Logged out',
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Logout failed',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'Network error',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Send OTP to email
  Future<Map<String, dynamic>> sendOtp(String email) async {
    try {
      final response = await _dio.post(
        '$baseUrl/auth/send-otp',
        data: {
          'email': email,
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'OTP sent successfully',
          'expiresIn': response.data['expiresIn'] ?? 300,
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Failed to send OTP',
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? e.message ?? 'Network error',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Verify OTP code
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl/auth/verify-otp',
        data: {
          'email': email,
          'otpCode': otpCode,
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': response.data['message'] ?? 'OTP verified successfully',
          'token': response.data['token'],
          'user': response.data['user'] != null ? User.fromJson(response.data['user']) : null,
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'OTP verification failed',
          'remainingAttempts': response.data['remainingAttempts'],
        };
      }
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? e.message ?? 'Network error',
        'remainingAttempts': e.response?.data['remainingAttempts'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}
