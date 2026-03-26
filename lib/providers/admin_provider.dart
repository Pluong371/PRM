import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/api_service.dart';

class AdminProvider extends ChangeNotifier {
  final List<AppUser> _accounts = [];
  final ApiService _apiService = ApiService();

  AdminProvider() {
    loadAccounts();
  }

  List<AppUser> get accounts => _accounts;

  Future<void> loadAccounts() async {
    try {
      final remote = await _apiService.fetchUsers();
      _accounts
        ..clear()
        ..addAll(remote);
      notifyListeners();
    } catch (_) {}
  }

  void toggleActive(String userId) {
    final index = _accounts.indexWhere((account) => account.id == userId);
    if (index == -1) return;

    final current = _accounts[index];
    _accounts[index] = current.copyWith(isActive: !current.isActive);
    notifyListeners();
    _apiService.toggleUserActive(userId);
  }

  void createAccount(AppUser user) {
    _accounts.insert(0, user);
    notifyListeners();
    _apiService.createUser(user);
  }

  void updateAccount(AppUser updatedUser) {
    final index = _accounts.indexWhere(
      (account) => account.id == updatedUser.id,
    );
    if (index == -1) return;
    _accounts[index] = updatedUser;
    notifyListeners();
    _apiService.updateUser(updatedUser);
  }
}
