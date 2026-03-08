class UserNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final String? refId;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? readAt;

  UserNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.refId,
    this.isRead = false,
    this.createdAt,
    this.readAt,
  });

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    return UserNotification(
      id: (json['Id'] ?? json['id'] ?? '').toString(),
      userId: (json['UserId'] ?? json['userId'] ?? '').toString(),
      type: (json['Type'] ?? json['type'] ?? '').toString(),
      title: (json['Title'] ?? json['title'] ?? '').toString(),
      message: (json['Message'] ?? json['message'] ?? '').toString(),
      refId: (json['RefId'] ?? json['refId'])?.toString(),
      isRead: json['IsRead'] == true ||
          (json['IsRead'] is num && (json['IsRead'] as num) == 1),
      createdAt: DateTime.tryParse((json['CreatedAt'] ?? '').toString()),
      readAt: DateTime.tryParse((json['ReadAt'] ?? '').toString()),
    );
  }
}
