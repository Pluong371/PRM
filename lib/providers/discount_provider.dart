import 'package:flutter/material.dart';

import '../models/discount.dart';
import '../services/api_service.dart';

class DiscountProvider extends ChangeNotifier {
  final List<DiscountCode> _discounts = [];
  final ApiService _apiService = ApiService();

  DiscountProvider() {
    loadDiscounts();
  }

  List<DiscountCode> get discounts => _discounts;

  Future<void> loadDiscounts() async {
    try {
      final remote = await _apiService.fetchDiscounts();
      _discounts
        ..clear()
        ..addAll(remote);
      notifyListeners();
    } catch (_) {}
  }

  DiscountCode? findByCode(String code) {
    try {
      return _discounts.firstWhere(
        (discount) => discount.code.toLowerCase() == code.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  void addDiscount(DiscountCode discountCode) {
    _discounts.insert(0, discountCode);
    notifyListeners();
    _apiService.createDiscount(discountCode);
  }
}
