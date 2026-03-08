import 'package:flutter/foundation.dart';
import '../models/review_model.dart';
import '../services/review_service.dart';

class ReviewProvider extends ChangeNotifier {
  final ReviewService _reviewService;

  List<Review> _reviews = [];
  List<Review> _helpfulReviews = [];
  bool _isLoading = false;
  String? _error;
  bool _canReview = false;
  bool _hasReviewed = false;
  String _sortBy = 'newest';

  ReviewProvider({ReviewService? reviewService})
      : _reviewService = reviewService ?? ReviewService();

  List<Review> get reviews => List.unmodifiable(_reviews);
  List<Review> get helpfulReviews => List.unmodifiable(_helpfulReviews);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get canReview => _canReview;
  bool get hasReviewed => _hasReviewed;
  String get sortBy => _sortBy;

  Future<void> loadProductReviews({
    required String productId,
    String? userId,
    String? sortBy,
  }) async {
    _isLoading = true;
    _error = null;
    if (sortBy != null && sortBy.isNotEmpty) {
      _sortBy = sortBy;
    }
    notifyListeners();

    try {
      final result = await _reviewService.getProductReviews(
        productId: productId,
        userId: userId,
        sortBy: _sortBy,
      );
      if (result['success'] == true) {
        _reviews = result['data'] as List<Review>;
      } else {
        _error = result['error']?.toString() ?? 'Khong the tai danh gia';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkCanReview({
    required String productId,
    required String userId,
  }) async {
    final result = await _reviewService.canReview(productId: productId, userId: userId);
    if (result['success'] == true) {
      _canReview = result['canReview'] == true;
      _hasReviewed = result['hasReviewed'] == true;
    } else {
      _canReview = false;
      _hasReviewed = false;
    }
    notifyListeners();
  }

  Future<bool> submitReview({
    required String productId,
    required String userId,
    required int rating,
    required String comment,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _reviewService.createOrUpdateReview(
      productId: productId,
      userId: userId,
      rating: rating,
      comment: comment,
    );

    _isLoading = false;
    if (result['success'] == true) {
      _hasReviewed = true;
      notifyListeners();
      await loadProductReviews(productId: productId, userId: userId);
      return true;
    }

    _error = result['error']?.toString() ?? 'Gui danh gia that bai';
    notifyListeners();
    return false;
  }

  Future<bool> deleteReview({
    required String reviewId,
    required String userId,
    required String productId,
  }) async {
    final result = await _reviewService.deleteReview(reviewId: reviewId, userId: userId);
    if (result['success'] == true) {
      _hasReviewed = false;
      await loadProductReviews(productId: productId, userId: userId);
      notifyListeners();
      return true;
    }
    _error = result['error']?.toString() ?? 'Xoa danh gia that bai';
    notifyListeners();
    return false;
  }

  Future<void> toggleHelpful({
    required String reviewId,
    required String userId,
    required String productId,
  }) async {
    final result = await _reviewService.toggleHelpful(reviewId: reviewId, userId: userId);
    if (result['success'] != true) {
      _error = result['error']?.toString() ?? 'Khong the thao tac huu ich';
      notifyListeners();
      return;
    }
    await loadProductReviews(productId: productId, userId: userId);
  }

  Future<void> loadHelpfulReviews({int limit = 10}) async {
    final result = await _reviewService.getHelpfulReviews(limit: limit);
    if (result['success'] == true) {
      _helpfulReviews = result['data'] as List<Review>;
    }
    notifyListeners();
  }

  void setSortBy(String value) {
    _sortBy = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
