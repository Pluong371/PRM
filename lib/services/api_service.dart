import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import '../models/discount.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/product_review.dart';

class AuthResult {
  final String token;
  final AppUser user;

  const AuthResult({required this.token, required this.user});
}

class OwnerRevenueSummary {
  final String ownerId;
  final String ownerName;
  final String ownerEmail;
  final int productCount;
  final int paidOrders;
  final int itemsSold;
  final double revenue;

  const OwnerRevenueSummary({
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    required this.productCount,
    required this.paidOrders,
    required this.itemsSold,
    required this.revenue,
  });
}

class TryOnGarmentInput {
  final String garmentImage;
  final String? garmentName;
  final String? productId;

  const TryOnGarmentInput({
    required this.garmentImage,
    this.garmentName,
    this.productId,
  });

  Map<String, dynamic> toJson() {
    return {
      'garmentImage': garmentImage,
      if (garmentName != null && garmentName!.trim().isNotEmpty)
        'garmentName': garmentName,
      if (productId != null && productId!.trim().isNotEmpty)
        'productId': productId,
    };
  }
}

class TryOnResultItem {
  final String status;
  final String? garmentName;
  final String? productId;
  final String? outputImage;
  final List<String> outputImages;
  final String? error;
  final int creditsUsed;

  const TryOnResultItem({
    required this.status,
    this.garmentName,
    this.productId,
    this.outputImage,
    this.outputImages = const [],
    this.error,
    this.creditsUsed = 0,
  });

  bool get isSuccess => status.toLowerCase() == 'completed';

  factory TryOnResultItem.fromJson(Map<String, dynamic> json) {
    return TryOnResultItem(
      status: (json['status'] ?? '').toString(),
      garmentName: (json['garmentName'] ?? '').toString().trim().isEmpty
          ? null
          : (json['garmentName'] ?? '').toString(),
      productId: (json['productId'] ?? '').toString().trim().isEmpty
          ? null
          : (json['productId'] ?? '').toString(),
      outputImage: (json['outputImage'] ?? '').toString().trim().isEmpty
          ? null
          : (json['outputImage'] ?? '').toString(),
      outputImages: (json['outputImages'] as List<dynamic>? ?? [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      error: (json['error'] ?? '').toString().trim().isEmpty
          ? null
          : (json['error'] ?? '').toString(),
      creditsUsed: ((json['creditsUsed'] ?? 0) as num).toInt(),
    );
  }
}

class TryOnBatchResponse {
  final int total;
  final int successCount;
  final int failureCount;
  final int totalCreditsUsed;
  final double estimatedCostUsd;
  final List<TryOnResultItem> results;

  const TryOnBatchResponse({
    required this.total,
    required this.successCount,
    required this.failureCount,
    required this.totalCreditsUsed,
    required this.estimatedCostUsd,
    required this.results,
  });

  factory TryOnBatchResponse.fromJson(Map<String, dynamic> json) {
    return TryOnBatchResponse(
      total: ((json['total'] ?? 0) as num).toInt(),
      successCount: ((json['successCount'] ?? 0) as num).toInt(),
      failureCount: ((json['failureCount'] ?? 0) as num).toInt(),
      totalCreditsUsed: ((json['totalCreditsUsed'] ?? 0) as num).toInt(),
      estimatedCostUsd: ((json['estimatedCostUsd'] ?? 0) as num).toDouble(),
      results: (json['results'] as List<dynamic>? ?? [])
          .map((item) => TryOnResultItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ApiService {
  static String? _sharedAccessToken;

  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:3000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  void setAccessToken(String? token) {
    _sharedAccessToken = token?.trim().isEmpty == true ? null : token?.trim();
  }

  String? get accessToken => _sharedAccessToken;

  Map<String, String> _headers({bool withAuth = false}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (withAuth && _sharedAccessToken != null) {
      headers['Authorization'] = 'Bearer $_sharedAccessToken';
    }
    return headers;
  }

  Future<AuthResult?> login({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          _uri('/auth/login'),
          headers: _headers(),
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final token = (json['token'] ?? '').toString();
    final userJson = (json['user'] as Map<String, dynamic>? ?? {});
    if (token.isEmpty || userJson.isEmpty) return null;

    final user = _userFromApiJson(userJson);
    return AuthResult(token: token, user: user);
  }

  Future<AppUser?> fetchCurrentUser() async {
    if (_sharedAccessToken == null || _sharedAccessToken!.isEmpty) return null;

    final response = await http
        .get(
          _uri('/auth/me'),
          headers: _headers(withAuth: true),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _userFromApiJson(json);
  }

  Future<AuthResult?> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await http
        .post(
          _uri('/auth/register'),
          headers: _headers(),
          body: jsonEncode({
            'fullName': fullName,
            'email': email,
            'phone': phone,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 201) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final token = (json['token'] ?? '').toString();
    final userJson = (json['user'] as Map<String, dynamic>? ?? {});
    if (token.isEmpty || userJson.isEmpty) return null;

    final user = _userFromApiJson(userJson);
    return AuthResult(token: token, user: user);
  }

  Future<List<Product>> fetchProducts() async {
    final response = await http
        .get(
          _uri('/products'),
          headers: _headers(withAuth: true),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return [];
    final list = jsonDecode(response.body) as List<dynamic>;

    return list.map((item) {
      final json = item as Map<String, dynamic>;
      final rawImages = (json['ImageUrls'] as List<dynamic>? ?? [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList();
      final fallbackImage = (json['ImageUrl'] ?? '').toString().trim();
      final imageUrls = rawImages.isNotEmpty
          ? rawImages
          : [
              fallbackImage.isNotEmpty
                  ? fallbackImage
                  : 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=800',
            ];

      final sizeStocksJson =
          (json['SizeStocks'] as Map<String, dynamic>? ?? {});
      final sizeStocks = <String, int>{
        for (final entry in sizeStocksJson.entries)
          entry.key.toString(): ((entry.value ?? 0) as num).toInt(),
      };

      final colorImagesJson =
          (json['ColorImages'] as Map<String, dynamic>? ?? {});
      final colorImageMap = <String, List<String>>{};
      for (final entry in colorImagesJson.entries) {
        colorImageMap[entry.key.toString().toUpperCase()] =
            (entry.value as List<dynamic>? ?? [])
                .map((value) => value.toString().trim())
                .where((value) => value.isNotEmpty)
                .toList();
      }

      final colors =
          colorImageMap.keys.map(_colorFromHex).whereType<Color>().toList();

      return Product(
        id: (json['Id'] ?? '').toString(),
        ownerId: (json['OwnerId'] ?? '').toString().isEmpty
            ? null
            : (json['OwnerId'] ?? '').toString(),
        name: (json['Name'] ?? '').toString(),
        price: ((json['Price'] ?? 0) as num).toDouble(),
        category: (json['Category'] ?? '').toString(),
        description: (json['Description'] ?? '').toString(),
        stock: ((json['Stock'] ?? 0) as num).toInt(),
        soldCount: ((json['SoldCount'] ?? 0) as num).toInt(),
        imageUrls: imageUrls,
        sizes: sizeStocks.keys.isNotEmpty
            ? sizeStocks.keys.toList()
            : const ['S', 'M', 'L', 'XL'],
        colors:
            colors.isNotEmpty ? colors : const [Colors.black, Colors.indigo],
        sizeStocks: sizeStocks,
        colorImageMap: colorImageMap,
        reviewsCount: 0,
        discountPercent: ((json['DiscountPercent'] ?? 0) as num).toDouble(),
      );
    }).toList();
  }

  Future<void> createProduct(Product product) async {
    await http.post(
      _uri('/products'),
      headers: _headers(withAuth: true),
      body: jsonEncode({
        'id': product.id,
        'ownerId': product.ownerId,
        'name': product.name,
        'category': product.category,
        'description': product.description,
        'price': product.price,
        'discountPercent': product.discountPercent ?? 0,
        'stock': product.stock,
        'imageUrls': product.imageUrls,
        'sizeStocks': product.sizeStocks,
        'colorImages': product.colorImageMap,
      }),
    );
  }

  Future<void> updateProduct(Product product) async {
    await http.put(
      _uri('/products/${product.id}'),
      headers: _headers(withAuth: true),
      body: jsonEncode({
        'ownerId': product.ownerId,
        'name': product.name,
        'category': product.category,
        'description': product.description,
        'price': product.price,
        'discountPercent': product.discountPercent ?? 0,
        'stock': product.stock,
        'imageUrls': product.imageUrls,
        'sizeStocks': product.sizeStocks,
        'colorImages': product.colorImageMap,
      }),
    );
  }

  Future<void> deleteProduct(String id) async {
    await http.delete(
      _uri('/products/$id'),
      headers: _headers(withAuth: true),
    );
  }

  Future<List<DiscountCode>> fetchDiscounts() async {
    final response =
        await http.get(_uri('/discounts')).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return [];
    final list = jsonDecode(response.body) as List<dynamic>;

    return list.map((item) {
      final json = item as Map<String, dynamic>;
      return DiscountCode(
        id: (json['Id'] ?? '').toString(),
        code: (json['Code'] ?? '').toString(),
        percent: ((json['Percent'] ?? 0) as num).toDouble(),
        startDate: DateTime.parse((json['StartDate'] ?? '').toString()),
        endDate: DateTime.parse((json['EndDate'] ?? '').toString()),
        minOrderValue: ((json['MinOrderValue'] ?? 0) as num).toDouble(),
      );
    }).toList();
  }

  Future<void> createDiscount(DiscountCode discountCode) async {
    await http.post(
      _uri('/discounts'),
      headers: _headers(withAuth: true),
      body: jsonEncode({
        'id': discountCode.id,
        'code': discountCode.code,
        'percent': discountCode.percent,
        'startDate': discountCode.startDate.toIso8601String(),
        'endDate': discountCode.endDate.toIso8601String(),
        'minOrderValue': discountCode.minOrderValue,
      }),
    );
  }

  Future<List<AppUser>> fetchUsers() async {
    final response =
        await http.get(_uri('/users')).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return [];
    final list = jsonDecode(response.body) as List<dynamic>;

    return list.map((item) {
      final json = item as Map<String, dynamic>;
      return AppUser(
        id: (json['Id'] ?? '').toString(),
        name: (json['FullName'] ?? '').toString(),
        email: (json['Email'] ?? '').toString(),
        phone: (json['Phone'] ?? '').toString(),
        role: _roleFromString((json['Role'] ?? 'customer').toString()),
        isActive: (json['IsActive'] ?? true) as bool,
      );
    }).toList();
  }

  Future<void> createUser(AppUser user) async {
    await http.post(
      _uri('/users'),
      headers: _headers(withAuth: true),
      body: jsonEncode({
        'id': user.id,
        'fullName': user.name,
        'email': user.email,
        'phone': user.phone,
        'role': user.role.name,
        'isActive': user.isActive,
      }),
    );
  }

  Future<void> updateUser(AppUser user) async {
    await http.put(
      _uri('/users/${user.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': user.name,
        'email': user.email,
        'phone': user.phone,
        'role': user.role.name,
        'isActive': user.isActive,
      }),
    );
  }

  Future<void> toggleUserActive(String userId) async {
    await http.patch(
      _uri('/users/$userId/toggle-active'),
      headers: _headers(withAuth: true),
    );
  }

  Future<List<Order>> fetchOrders() async {
    final response = await http
        .get(
          _uri('/orders'),
          headers: _headers(withAuth: true),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return [];
    final list = jsonDecode(response.body) as List<dynamic>;

    return list.map((item) {
      final json = item as Map<String, dynamic>;
      final itemsJson = (json['items'] as List<dynamic>? ?? []);

      return Order(
        id: (json['Id'] ?? '').toString(),
        userId: (json['UserId'] ?? '').toString(),
        createdAt: DateTime.parse((json['CreatedAt'] ?? '').toString()),
        shippingAddress: (json['ShippingAddress'] ?? '').toString(),
        paymentMethod: (json['PaymentMethod'] ?? '').toString(),
        status:
            _orderStatusFromString((json['Status'] ?? 'processing').toString()),
        isPaid: (json['PaymentStatus'] ?? 'pending').toString().toLowerCase() ==
            'paid',
        items: itemsJson.map((value) {
          final row = value as Map<String, dynamic>;
          final unitPrice = ((row['UnitPrice'] ?? 0) as num).toDouble();
          final quantity = (row['Quantity'] ?? 1) as int;
          final rawImage = (row['ImageUrl'] ?? '').toString().trim();

          return OrderItem(
            product: Product(
              id: (row['ProductId'] ?? '').toString(),
              name: (row['Name'] ?? '').toString(),
              price: unitPrice,
              category: (row['Category'] ?? '').toString(),
              description: (row['Description'] ?? '').toString(),
              imageUrls: [
                rawImage.isEmpty
                    ? 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=800'
                    : rawImage,
              ],
              sizes: const ['S', 'M', 'L', 'XL'],
              colors: const [Colors.black],
              reviewsCount: 0,
              discountPercent:
                  ((row['DiscountPercent'] ?? 0) as num).toDouble(),
            ),
            quantity: quantity,
            size: (row['SizeLabel'] ?? 'M').toString(),
          );
        }).toList(),
      );
    }).toList();
  }

  Future<void> createOrder({
    required String id,
    required String orderCode,
    required String userId,
    required String shippingAddress,
    required String paymentMethod,
    required String paymentStatus,
    required String status,
    required double subtotal,
    required double discountAmount,
    required double total,
    required List<Map<String, dynamic>> items,
  }) async {
    await http.post(
      _uri('/orders'),
      headers: _headers(withAuth: true),
      body: jsonEncode({
        'id': id,
        'orderCode': orderCode,
        'userId': userId,
        'shippingAddress': shippingAddress,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'status': status,
        'subtotal': subtotal,
        'discountAmount': discountAmount,
        'total': total,
        'items': items,
      }),
    );
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await http.patch(
      _uri('/orders/$orderId/status'),
      headers: _headers(withAuth: true),
      body: jsonEncode({'status': status.name}),
    );
  }

  Future<List<OwnerRevenueSummary>> fetchOwnerRevenueSummary() async {
    final response = await http
        .get(_uri('/admin/revenue-by-owner'))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return const [];
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((item) {
      final json = item as Map<String, dynamic>;
      return OwnerRevenueSummary(
        ownerId: (json['OwnerId'] ?? '').toString(),
        ownerName: (json['OwnerName'] ?? '').toString(),
        ownerEmail: (json['OwnerEmail'] ?? '').toString(),
        productCount: ((json['ProductCount'] ?? 0) as num).toInt(),
        paidOrders: ((json['PaidOrders'] ?? 0) as num).toInt(),
        itemsSold: ((json['ItemsSold'] ?? 0) as num).toInt(),
        revenue: ((json['Revenue'] ?? 0) as num).toDouble(),
      );
    }).toList();
  }

  Future<List<ProductReview>> fetchProductReviews(String productId) async {
    final response = await http
        .get(_uri('/products/$productId/reviews'))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return [];
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((item) => ProductReview.fromApiJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<({bool canReview, bool hasReviewed})> canReviewProduct({
    required String productId,
    required String userId,
  }) async {
    final response = await http
        .get(_uri('/products/$productId/can-review?userId=$userId'))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      return (canReview: false, hasReviewed: false);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      canReview: json['canReview'] == true,
      hasReviewed: json['hasReviewed'] == true,
    );
  }

  Future<bool> submitProductReview({
    required String productId,
    required String userId,
    required int rating,
    required String comment,
  }) async {
    final response = await http.post(
      _uri('/products/$productId/reviews'),
      headers: _headers(withAuth: true),
      body: jsonEncode({
        'userId': userId,
        'rating': rating,
        'comment': comment,
      }),
    );

    return response.statusCode == 201;
  }

  Future<TryOnBatchResponse> tryOnBatch({
    required String modelImage,
    required List<TryOnGarmentInput> garments,
    String category = 'auto',
    String mode = 'balanced',
  }) async {
    final response = await http
        .post(
          _uri('/tryon/batch'),
          headers: _headers(withAuth: true),
          body: jsonEncode({
            'modelImage': modelImage,
            'category': category,
            'mode': mode,
            'garments': garments.map((item) => item.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 120));

    final bodyJson = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final message = (bodyJson['message'] ?? 'Try-on failed').toString();
      throw Exception(message);
    }

    return TryOnBatchResponse.fromJson(bodyJson);
  }

  AppUser _userFromApiJson(Map<String, dynamic> json) {
    final isActiveRaw = json['IsActive'];
    final isActive = isActiveRaw is bool
        ? isActiveRaw
        : (isActiveRaw is num ? isActiveRaw == 1 : true);

    return AppUser(
      id: (json['Id'] ?? '').toString(),
      name: (json['FullName'] ?? '').toString(),
      email: (json['Email'] ?? '').toString(),
      phone: (json['Phone'] ?? '').toString(),
      role: _roleFromString((json['Role'] ?? 'customer').toString()),
      isActive: isActive,
    );
  }

  UserRole _roleFromString(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.customer;
    }
  }

  OrderStatus _orderStatusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.processing;
    }
  }

  Color? _colorFromHex(String hex) {
    final normalized = hex.trim().replaceAll('#', '').toUpperCase();
    if (normalized.length == 6) {
      return Color(int.parse('FF$normalized', radix: 16));
    }
    if (normalized.length == 8) {
      return Color(int.parse(normalized, radix: 16));
    }
    return null;
  }
}
