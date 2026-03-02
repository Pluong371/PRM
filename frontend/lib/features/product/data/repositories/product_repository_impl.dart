import 'package:frontend/features/product/data/datasources/product_remote_datasource.dart';
import 'package:frontend/features/product/data/models/product_model.dart';
import 'package:frontend/features/product/domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource remoteDataSource;

  ProductRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<ProductModel>> getProducts({
    String? search,
    List<int>? categoryIds,
    double? minPrice,
    double? maxPrice,
    List<String>? brands,
  }) {
    return remoteDataSource.getProducts(
      search: search,
      categoryIds: categoryIds,
      minPrice: minPrice,
      maxPrice: maxPrice,
      brands: brands,
    );
  }

  @override
  Future<ProductModel> getProductById(int id) {
    return remoteDataSource.getProductById(id);
  }

  @override
  Future<List<CategoryModel>> getCategories() {
    return remoteDataSource.getCategories();
  }

  @override
  Future<List<String>> getBrands() {
    return remoteDataSource.getBrands();
  }
}
