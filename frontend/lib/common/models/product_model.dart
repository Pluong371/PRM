class Product {
  final String id;
  final String? ownerId;
  final String name;
  final String category;
  final String? description;
  final double price;
  final double discountPercent;
  final int stock;
  final int soldCount;
  final List<String> imageUrls;
  final String? imageUrl;
  final Map<String, int> sizeStocks;
  final Map<String, List<String>> colorImages;

  Product({
    required this.id,
    this.ownerId,
    required this.name,
    required this.category,
    this.description,
    required this.price,
    this.discountPercent = 0,
    this.stock = 0,
    this.soldCount = 0,
    this.imageUrls = const [],
    this.imageUrl,
    this.sizeStocks = const {},
    this.colorImages = const {},
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    List<String> imageUrlsList = [];
    if (json['ImageUrls'] != null) {
      if (json['ImageUrls'] is List) {
        imageUrlsList = List<String>.from(json['ImageUrls']);
      }
    }

    Map<String, int> sizeStocksMap = {};
    if (json['SizeStocks'] != null && json['SizeStocks'] is Map) {
      json['SizeStocks'].forEach((key, value) {
        sizeStocksMap[key.toString()] = (value is int) ? value : int.tryParse(value.toString()) ?? 0;
      });
    }

    Map<String, List<String>> colorImagesMap = {};
    if (json['ColorImages'] != null && json['ColorImages'] is Map) {
      json['ColorImages'].forEach((key, value) {
        if (value is List) {
          colorImagesMap[key.toString()] = List<String>.from(value);
        }
      });
    }

    return Product(
      id: json['Id'] ?? '',
      ownerId: json['OwnerId'],
      name: json['Name'] ?? '',
      category: json['Category'] ?? '',
      description: json['Description'],
      price: (json['Price'] is num) ? (json['Price'] as num).toDouble() : 0.0,
      discountPercent: (json['DiscountPercent'] is num) 
          ? (json['DiscountPercent'] as num).toDouble() 
          : 0.0,
      stock: (json['Stock'] is int) ? json['Stock'] : int.tryParse(json['Stock'].toString()) ?? 0,
      soldCount: (json['SoldCount'] is int) ? json['SoldCount'] : int.tryParse(json['SoldCount'].toString()) ?? 0,
      imageUrls: imageUrlsList,
      imageUrl: json['ImageUrl'],
      sizeStocks: sizeStocksMap,
      colorImages: colorImagesMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'OwnerId': ownerId,
      'Name': name,
      'Category': category,
      'Description': description,
      'Price': price,
      'DiscountPercent': discountPercent,
      'Stock': stock,
      'SoldCount': soldCount,
      'ImageUrls': imageUrls,
      'ImageUrl': imageUrl,
      'SizeStocks': sizeStocks,
      'ColorImages': colorImages,
    };
  }

  double get finalPrice {
    if (discountPercent > 0) {
      return price * (1 - discountPercent / 100);
    }
    return price;
  }

  bool get hasDiscount => discountPercent > 0;

  bool get isAvailable => stock > 0;
}
