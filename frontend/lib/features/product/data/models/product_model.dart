class ProductModel {
  final int id;
  final String name;
  final String? description;
  final double price;
  final String? brand;
  final String? model;
  final String? imageUrl;
  final List<CategoryModel> categories;
  final int? stockQuantity;
  final bool? isActive;
  final List<ProductAttributeModel> attributes;

  ProductModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.brand,
    this.model,
    this.imageUrl,
    this.categories = const [],
    this.stockQuantity,
    this.isActive,
    this.attributes = const [],
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: (json['price'] is int)
          ? (json['price'] as int).toDouble()
          : (json['price'] as num?)?.toDouble() ?? 0,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      imageUrl: json['imageUrl'] as String?,
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      stockQuantity: json['stockQuantity'] as int?,
      isActive: json['isActive'] as bool?,
      attributes:
          (json['attributes'] as List<dynamic>?)
              ?.map(
                (e) =>
                    ProductAttributeModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  bool get inStock => (stockQuantity ?? 0) > 0;
}

class CategoryModel {
  final int id;
  final String name;
  final String? description;
  final int? parentId;
  final List<CategoryModel> children;
  final bool? isActive;

  CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.parentId,
    this.children = const [],
    this.isActive,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      parentId: json['parentId'] as int?,
      children:
          (json['children'] as List<dynamic>?)
              ?.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isActive: json['isActive'] as bool?,
    );
  }
}

class ProductAttributeModel {
  final int id;
  final String attributeName;
  final String attributeValue;

  ProductAttributeModel({
    required this.id,
    required this.attributeName,
    required this.attributeValue,
  });

  factory ProductAttributeModel.fromJson(Map<String, dynamic> json) {
    return ProductAttributeModel(
      id: json['id'] as int,
      attributeName: json['attributeName'] as String? ?? '',
      attributeValue: json['attributeValue'] as String? ?? '',
    );
  }
}
