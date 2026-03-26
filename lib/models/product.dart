import 'package:flutter/material.dart';

class Product {
  final String id;
  final String? ownerId;
  final String name;
  final double price;
  final String category;
  final String description;
  final int stock;
  final int soldCount;
  final List<String> imageUrls;
  final List<String> sizes;
  final List<Color> colors;
  final Map<String, int> sizeStocks;
  final Map<String, List<String>> colorImageMap;
  final int reviewsCount;
  final double? discountPercent;

  const Product({
    required this.id,
    this.ownerId,
    required this.name,
    required this.price,
    required this.category,
    required this.description,
    this.stock = 0,
    this.soldCount = 0,
    required this.imageUrls,
    required this.sizes,
    required this.colors,
    this.sizeStocks = const {},
    this.colorImageMap = const {},
    required this.reviewsCount,
    this.discountPercent,
  });

  double get finalPrice {
    if (discountPercent == null || discountPercent == 0) return price;
    return price * (1 - discountPercent! / 100);
  }
}
