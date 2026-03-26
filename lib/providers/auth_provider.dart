import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  final ApiService _apiService = ApiService();
  AppUser? _currentUser;
  bool _isRestoringSession = true;

  AuthProvider() {
    _restoreSession();
  }

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isRestoringSession => _isRestoringSession;

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    if (token == null || token.trim().isEmpty) {
      _isRestoringSession = false;
      notifyListeners();
      return;
    }

    _apiService.setAccessToken(token);
    final fromApi = await _apiService.fetchCurrentUser();
    if (fromApi != null) {
      _currentUser = fromApi;
      await prefs.setString(_userKey, jsonEncode(fromApi.toJson()));
    } else {
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      _apiService.setAccessToken(null);
      _currentUser = null;
    }

    _isRestoringSession = false;
    notifyListeners();
  }

  Future<void> _saveSession(
      {required String token, required AppUser user}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();

    final fromApi = await _apiService.login(
      email: normalizedEmail,
      password: normalizedPassword,
    );
    if (fromApi != null) {
      _apiService.setAccessToken(fromApi.token);
      _currentUser = fromApi.user;
      await _saveSession(token: fromApi.token, user: fromApi.user);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final created = await _apiService.register(
      fullName: name.trim().isEmpty ? 'New Customer' : name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      password: password,
    );

    if (created == null) {
      return false;
    }

    _apiService.setAccessToken(created.token);
    _currentUser = created.user;
    await _saveSession(token: created.token, user: created.user);
    notifyListeners();
    return true;
  }

  Future<void> updateProfile(
      {required String name, required String phone}) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(name: name, phone: phone);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(_currentUser!.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    _apiService.setAccessToken(null);
    _currentUser = null;
    notifyListeners();
  }
}
