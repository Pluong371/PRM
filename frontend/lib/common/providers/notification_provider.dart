import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService;

  List<UserNotification> _notifications = [];
  bool _isLoading = false;
  String? _error;

  NotificationProvider({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService();

  List<UserNotification> get notifications => List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> loadNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _notificationService.getNotifications();
    _isLoading = false;

    if (result['success'] == true) {
      _notifications = result['data'] as List<UserNotification>;
      _error = null;
    } else {
      _error = result['error']?.toString() ?? 'Khong the tai thong bao';
    }
    notifyListeners();
  }

  Future<bool> markAsRead(String id) async {
    final result = await _notificationService.markAsRead(id);
    if (result['success'] == true) {
      await loadNotifications();
      return true;
    }
    _error = result['error']?.toString() ?? 'Danh dau da doc that bai';
    notifyListeners();
    return false;
  }

  Future<bool> markAllAsRead() async {
    final result = await _notificationService.markAllAsRead();
    if (result['success'] == true) {
      await loadNotifications();
      return true;
    }
    _error = result['error']?.toString() ?? 'Danh dau tat ca that bai';
    notifyListeners();
    return false;
  }
}
