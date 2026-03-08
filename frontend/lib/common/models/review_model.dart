class Review {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final int rating;
  final String comment;
  final int helpfulCount;
  final bool isHelpfulByMe;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Review({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    this.helpfulCount = 0,
    this.isHelpfulByMe = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: (json['Id'] ?? json['id'] ?? '').toString(),
      productId: (json['ProductId'] ?? json['productId'] ?? '').toString(),
      userId: (json['UserId'] ?? json['userId'] ?? '').toString(),
      userName: (json['UserName'] ?? json['userName'] ?? 'Khach hang').toString(),
      rating: (json['Rating'] is num)
          ? (json['Rating'] as num).toInt()
          : int.tryParse((json['Rating'] ?? '0').toString()) ?? 0,
      comment: (json['Comment'] ?? json['comment'] ?? '').toString(),
      helpfulCount: (json['HelpfulCount'] is num)
          ? (json['HelpfulCount'] as num).toInt()
          : int.tryParse((json['HelpfulCount'] ?? '0').toString()) ?? 0,
      isHelpfulByMe: json['IsHelpfulByMe'] == true ||
          (json['IsHelpfulByMe'] is num && (json['IsHelpfulByMe'] as num) == 1),
      createdAt: DateTime.tryParse((json['CreatedAt'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['UpdatedAt'] ?? '').toString()),
    );
  }
}
