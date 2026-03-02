import 'package:frontend/features/auth/data/models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel> login(String username, String password);
  Future<String> sendRegisterOtp(String email);
  Future<String> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    required String otpCode,
  });
  Future<void> logout();
  Future<UserModel?> getStoredUser();
}
