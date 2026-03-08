import 'package:dio/dio.dart';
import '../models/product_model.dart';

class ProductService {
  final Dio dio;
  final String baseUrl;

  ProductService({
    required this.dio,
    required this.baseUrl,
  });

  /// Get all products
  Future<Map<String, dynamic>> getProducts({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await dio.get(
        '$baseUrl/api/products',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final products = (response.data as List)
            .map((item) => Product.fromJson(item as Map<String, dynamic>))
            .toList();
        return {
          'success': true,
          'data': products,
        };
      }
      return {
        'success': false,
        'error': 'Failed to fetch products',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  /// Get product details by ID
  Future<Map<String, dynamic>> getProductById(String productId) async {
    try {
      final response = await dio.get(
        '$baseUrl/api/products/$productId',
      );

      if (response.statusCode == 200) {
        final product = Product.fromJson(response.data as Map<String, dynamic>);
        return {
          'success': true,
          'data': product,
        };
      }
      return {
        'success': false,
        'error': 'Failed to fetch product',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  /// Search products by query
  Future<Map<String, dynamic>> searchProducts(String query) async {
    try {
      final response = await dio.get(
        '$baseUrl/api/products/search',
        queryParameters: {
          'q': query,
        },
      );

      if (response.statusCode == 200) {
        final products = (response.data as List)
            .map((item) => Product.fromJson(item as Map<String, dynamic>))
            .toList();
        return {
          'success': true,
          'data': products,
        };
      }
      return {
        'success': false,
        'error': 'No products found',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  /// Filter products by category
  Future<Map<String, dynamic>> getProductsByCategory(String category) async {
    try {
      final response = await dio.get(
        '$baseUrl/api/products',
        queryParameters: {
          'category': category,
        },
      );

      if (response.statusCode == 200) {
        final products = (response.data as List)
            .map((item) => Product.fromJson(item as Map<String, dynamic>))
            .toList();
        return {
          'success': true,
          'data': products,
        };
      }
      return {
        'success': false,
        'error': 'Failed to fetch products',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  /// Get categories
  Future<Map<String, dynamic>> getCategories() async {
    try {
      final response = await dio.get(
        '$baseUrl/api/categories',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.data,
        };
      }
      return {
        'success': false,
        'error': 'Failed to fetch categories',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }
}
