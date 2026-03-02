import 'package:dio/dio.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/errors/exceptions.dart';
import 'package:frontend/core/network/dio_client.dart';
import 'package:frontend/features/product/data/models/product_model.dart';

class ProductRemoteDataSource {
  final DioClient dioClient;

  ProductRemoteDataSource({required this.dioClient});

  /// Get products with optional filters
  Future<List<ProductModel>> getProducts({
    String? search,
    List<int>? categoryIds,
    double? minPrice,
    double? maxPrice,
    List<String>? brands,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (categoryIds != null && categoryIds.isNotEmpty) {
        queryParams['categoryIds'] = categoryIds;
      }
      if (minPrice != null) queryParams['minPrice'] = minPrice;
      if (maxPrice != null) queryParams['maxPrice'] = maxPrice;
      if (brands != null && brands.isNotEmpty) queryParams['brands'] = brands;

      final response = await dioClient.dio.get(
        ApiConstants.products,
        queryParameters: queryParams,
      );

      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
        message: 'Không thể tải sản phẩm',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Get single product by ID
  Future<ProductModel> getProductById(int id) async {
    try {
      final response = await dioClient.dio.get('${ApiConstants.products}/$id');
      return ProductModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(
        message: 'Không tìm thấy sản phẩm',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Get all categories
  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await dioClient.dio.get(ApiConstants.categories);
      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
        message: 'Không thể tải danh mục',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Get all brands
  Future<List<String>> getBrands() async {
    try {
      final response = await dioClient.dio.get(ApiConstants.brands);
      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((e) => e.toString()).toList();
    } on DioException catch (e) {
      throw ServerException(
        message: 'Không thể tải thương hiệu',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
