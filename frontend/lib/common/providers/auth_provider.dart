import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final FlutterSecureStorage _secureStorage;

  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider({
    AuthService? authService,
    FlutterSecureStorage? secureStorage,
  })  : _authService = authService ?? AuthService(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  // Getters
  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _token != null && _user != null;

  // Register
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.register(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
      );

      if (result['success']) {
        _token = result['token'];
        _user = result['user'];
        await _secureStorage.write(
          key: 'auth_token',
          value: _token!,
        );
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(
        email: email,
        password: password,
      );

      if (result['success']) {
        _token = result['token'];
        _user = result['user'];
        await _secureStorage.write(
          key: 'auth_token',
          value: _token!,
        );
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Get current user
  Future<void> getCurrentUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _secureStorage.read(key: 'auth_token');
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      _token = token;
      final result = await _authService.getCurrentUser(token);

      if (result['success']) {
        _user = result['user'];
      } else {
        _token = null;
        await _secureStorage.delete(key: 'auth_token');
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Logout
  Future<void> logout() async {
    _token = null;
    _user = null;
    _errorMessage = null;
    await _secureStorage.delete(key: 'auth_token');
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
