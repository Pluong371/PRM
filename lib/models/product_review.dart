class ProductReview {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  const ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ProductReview.fromApiJson(Map<String, dynamic> json) {
    return ProductReview(
      id: (json['Id'] ?? '').toString(),
      productId: (json['ProductId'] ?? '').toString(),
      userId: (json['UserId'] ?? '').toString(),
      userName: (json['UserName'] ?? 'Customer').toString(),
      rating: ((json['Rating'] ?? 0) as num).toInt(),
      comment: (json['Comment'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['CreatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
