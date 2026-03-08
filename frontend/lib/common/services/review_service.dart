import 'package:dio/dio.dart';
import '../models/review_model.dart';

class ReviewService {
  final Dio dio;
  final String baseUrl;

  ReviewService({
    Dio? dio,
    String? baseUrl,
  })  : dio = dio ?? Dio(),
        baseUrl = baseUrl ?? 'http://localhost:3000';

  Future<Map<String, dynamic>> getProductReviews({
    required String productId,
    String? userId,
    String sortBy = 'newest',
  }) async {
    try {
      final response = await dio.get(
        '$baseUrl/api/products/$productId/reviews',
        queryParameters: {
          if (userId != null && userId.isNotEmpty) 'userId': userId,
          'sortBy': sortBy,
        },
      );

      final reviews = (response.data as List)
          .map((item) => Review.fromJson(item as Map<String, dynamic>))
          .toList();
      return {'success': true, 'data': reviews};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  Future<Map<String, dynamic>> canReview({
    required String productId,
    required String userId,
  }) async {
    try {
      final response = await dio.get(
        '$baseUrl/api/products/$productId/can-review',
        queryParameters: {'userId': userId},
      );
      return {
        'success': true,
        'canReview': response.data['canReview'] == true,
        'hasReviewed': response.data['hasReviewed'] == true,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  Future<Map<String, dynamic>> createOrUpdateReview({
    required String productId,
    required String userId,
    required int rating,
    required String comment,
  }) async {
    try {
      final response = await dio.post(
        '$baseUrl/api/products/$productId/reviews',
        data: {
          'userId': userId,
          'rating': rating,
          'comment': comment,
        },
      );
      return {'success': response.statusCode == 201 || response.statusCode == 200};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  Future<Map<String, dynamic>> updateReview({
    required String reviewId,
    required String userId,
    required int rating,
    required String comment,
  }) async {
    try {
      final response = await dio.patch(
        '$baseUrl/api/reviews/$reviewId',
        data: {
          'userId': userId,
          'rating': rating,
          'comment': comment,
        },
      );
      return {'success': response.statusCode == 200};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  Future<Map<String, dynamic>> deleteReview({
    required String reviewId,
    required String userId,
  }) async {
    try {
      final response = await dio.delete(
        '$baseUrl/api/reviews/$reviewId',
        queryParameters: {'userId': userId},
      );
      return {'success': response.statusCode == 200};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  Future<Map<String, dynamic>> toggleHelpful({
    required String reviewId,
    required String userId,
  }) async {
    try {
      final response = await dio.post(
        '$baseUrl/api/reviews/$reviewId/helpful',
        data: {'userId': userId},
      );
      return {
        'success': true,
        'helpfulCount': response.data['helpfulCount'] ?? 0,
        'isHelpful': response.data['isHelpful'] == true,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }

  Future<Map<String, dynamic>> getHelpfulReviews({int limit = 10}) async {
    try {
      final response = await dio.get(
        '$baseUrl/api/reviews/helpful',
        queryParameters: {'limit': limit},
      );
      final reviews = (response.data as List)
          .map((item) => Review.fromJson(item as Map<String, dynamic>))
          .toList();
      return {'success': true, 'data': reviews};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['message'] ?? e.message,
      };
    }
  }
}
