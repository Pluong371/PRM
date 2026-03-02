import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend/core/errors/exceptions.dart';
import 'package:frontend/features/product/data/models/product_model.dart';
import 'package:frontend/features/product/domain/repositories/product_repository.dart';

// ─── Events ───
abstract class ProductEvent extends Equatable {
  const ProductEvent();
  @override
  List<Object?> get props => [];
}

class LoadProductsEvent extends ProductEvent {
  const LoadProductsEvent();
}

class SearchProductsEvent extends ProductEvent {
  final String query;
  const SearchProductsEvent({required this.query});
  @override
  List<Object?> get props => [query];
}

class FilterByCategoryEvent extends ProductEvent {
  final int? categoryId;
  const FilterByCategoryEvent({this.categoryId});
  @override
  List<Object?> get props => [categoryId];
}

class LoadCategoriesEvent extends ProductEvent {
  const LoadCategoriesEvent();
}

class LoadProductDetailEvent extends ProductEvent {
  final int productId;
  const LoadProductDetailEvent({required this.productId});
  @override
  List<Object?> get props => [productId];
}

// ─── States ───
abstract class ProductState extends Equatable {
  const ProductState();
  @override
  List<Object?> get props => [];
}

class ProductInitial extends ProductState {
  const ProductInitial();
}

class ProductLoading extends ProductState {
  const ProductLoading();
}

class ProductsLoaded extends ProductState {
  final List<ProductModel> products;
  final List<CategoryModel> categories;
  final int? selectedCategoryId;
  final String searchQuery;

  const ProductsLoaded({
    required this.products,
    this.categories = const [],
    this.selectedCategoryId,
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [
    products,
    categories,
    selectedCategoryId,
    searchQuery,
  ];

  ProductsLoaded copyWith({
    List<ProductModel>? products,
    List<CategoryModel>? categories,
    int? selectedCategoryId,
    String? searchQuery,
    bool clearCategory = false,
  }) {
    return ProductsLoaded(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      selectedCategoryId: clearCategory
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ProductDetailLoaded extends ProductState {
  final ProductModel product;
  const ProductDetailLoaded({required this.product});
  @override
  List<Object?> get props => [product];
}

class ProductError extends ProductState {
  final String message;
  const ProductError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final ProductRepository productRepository;

  ProductBloc({required this.productRepository})
    : super(const ProductInitial()) {
    on<LoadProductsEvent>(_onLoadProducts);
    on<SearchProductsEvent>(_onSearchProducts);
    on<FilterByCategoryEvent>(_onFilterByCategory);
    on<LoadCategoriesEvent>(_onLoadCategories);
    on<LoadProductDetailEvent>(_onLoadProductDetail);
  }

  Future<void> _onLoadProducts(
    LoadProductsEvent event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      final results = await Future.wait([
        productRepository.getProducts(),
        productRepository.getCategories(),
      ]);
      emit(
        ProductsLoaded(
          products: results[0] as List<ProductModel>,
          categories: results[1] as List<CategoryModel>,
        ),
      );
    } on ServerException catch (e) {
      emit(ProductError(message: e.message));
    } catch (e) {
      emit(ProductError(message: 'Đã xảy ra lỗi: ${e.toString()}'));
    }
  }

  Future<void> _onSearchProducts(
    SearchProductsEvent event,
    Emitter<ProductState> emit,
  ) async {
    final currentState = state;
    List<CategoryModel> categories = [];
    if (currentState is ProductsLoaded) {
      categories = currentState.categories;
    }
    emit(const ProductLoading());
    try {
      final products = await productRepository.getProducts(search: event.query);
      emit(
        ProductsLoaded(
          products: products,
          categories: categories,
          searchQuery: event.query,
        ),
      );
    } on ServerException catch (e) {
      emit(ProductError(message: e.message));
    }
  }

  Future<void> _onFilterByCategory(
    FilterByCategoryEvent event,
    Emitter<ProductState> emit,
  ) async {
    final currentState = state;
    List<CategoryModel> categories = [];
    if (currentState is ProductsLoaded) {
      categories = currentState.categories;
    }
    emit(const ProductLoading());
    try {
      final categoryIds = event.categoryId != null ? [event.categoryId!] : null;
      final products = await productRepository.getProducts(
        categoryIds: categoryIds,
      );
      emit(
        ProductsLoaded(
          products: products,
          categories: categories,
          selectedCategoryId: event.categoryId,
          clearCategory: event.categoryId == null,
        ),
      );
    } on ServerException catch (e) {
      emit(ProductError(message: e.message));
    }
  }

  Future<void> _onLoadCategories(
    LoadCategoriesEvent event,
    Emitter<ProductState> emit,
  ) async {
    try {
      final categories = await productRepository.getCategories();
      if (state is ProductsLoaded) {
        emit((state as ProductsLoaded).copyWith(categories: categories));
      }
    } catch (_) {}
  }

  Future<void> _onLoadProductDetail(
    LoadProductDetailEvent event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      final product = await productRepository.getProductById(event.productId);
      emit(ProductDetailLoaded(product: product));
    } on ServerException catch (e) {
      emit(ProductError(message: e.message));
    } catch (e) {
      emit(ProductError(message: 'Không thể tải chi tiết sản phẩm'));
    }
  }
}
