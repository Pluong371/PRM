import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:frontend/features/auth/data/models/user_model.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final FlutterSecureStorage storage;

  AuthRepositoryImpl({required this.remoteDataSource, required this.storage});

  @override
  Future<UserModel> login(String username, String password) async {
    final user = await remoteDataSource.login(username, password);
    // Store token and user data
    await storage.write(key: 'access_token', value: user.accessToken);
    await storage.write(
      key: 'user_data',
      value: jsonEncode({
        'id': user.id,
        'username': user.username,
        'email': user.email,
        'roles': user.roles,
        'accessToken': user.accessToken,
      }),
    );
    return user;
  }

  @override
  Future<String> sendRegisterOtp(String email) {
    return remoteDataSource.sendRegisterOtp(email);
  }

  @override
  Future<String> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    required String otpCode,
  }) {
    return remoteDataSource.register(
      username: username,
      email: email,
      password: password,
      fullName: fullName,
      otpCode: otpCode,
    );
  }

  @override
  Future<void> logout() async {
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'user_data');
  }

  @override
  Future<UserModel?> getStoredUser() async {
    final userData = await storage.read(key: 'user_data');
    if (userData == null) return null;
    try {
      final json = jsonDecode(userData) as Map<String, dynamic>;
      return UserModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
