import 'package:flutter/material.dart';

class FavoritesProvider extends ChangeNotifier {
  final Set<String> _favoriteProductIds = <String>{};

  Set<String> get favoriteProductIds => Set.unmodifiable(_favoriteProductIds);

  bool isFavorite(String productId) => _favoriteProductIds.contains(productId);

  void toggleFavorite(String productId) {
    if (_favoriteProductIds.contains(productId)) {
      _favoriteProductIds.remove(productId);
    } else {
      _favoriteProductIds.add(productId);
    }
    notifyListeners();
  }

  void removeFavorite(String productId) {
    if (_favoriteProductIds.remove(productId)) {
      notifyListeners();
    }
  }
}
