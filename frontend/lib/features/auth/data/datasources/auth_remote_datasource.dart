import 'package:dio/dio.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/errors/exceptions.dart';
import 'package:frontend/core/network/dio_client.dart';
import 'package:frontend/core/security/aes_helper.dart';
import 'package:frontend/features/auth/data/models/user_model.dart';

class AuthRemoteDataSource {
  final DioClient dioClient;

  AuthRemoteDataSource({required this.dioClient});

  /// Login with username + AES-encrypted password
  Future<UserModel> login(String username, String password) async {
    try {
      final encryptedPassword = AesHelper.encryptPassword(password);
      final response = await dioClient.dio.post(
        ApiConstants.login,
        data: {'username': username, 'password': encryptedPassword},
      );
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Đăng nhập thất bại';
      throw ServerException(
        message: message,
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Send OTP for registration
  Future<String> sendRegisterOtp(String email) async {
    try {
      final response = await dioClient.dio.post(
        ApiConstants.sendRegisterOtp,
        data: {'email': email},
      );
      return response.data['message'] ?? 'OTP đã gửi';
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Gửi OTP thất bại';
      throw ServerException(
        message: message,
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Register with username, email, AES-encrypted password, fullName, OTP
  Future<String> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    required String otpCode,
  }) async {
    try {
      final encryptedPassword = AesHelper.encryptPassword(password);
      final response = await dioClient.dio.post(
        ApiConstants.register,
        data: {
          'username': username,
          'email': email,
          'password': encryptedPassword,
          'fullName': fullName,
          'otpCode': otpCode,
        },
      );
      return response.data['message'] ?? 'Đăng ký thành công';
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Đăng ký thất bại';
      throw ServerException(
        message: message,
        statusCode: e.response?.statusCode,
      );
    }
  }
}
