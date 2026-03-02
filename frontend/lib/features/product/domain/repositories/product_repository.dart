import 'package:frontend/features/product/data/models/product_model.dart';

abstract class ProductRepository {
  Future<List<ProductModel>> getProducts({
    String? search,
    List<int>? categoryIds,
    double? minPrice,
    double? maxPrice,
    List<String>? brands,
  });
  Future<ProductModel> getProductById(int id);
  Future<List<CategoryModel>> getCategories();
  Future<List<String>> getBrands();
}
