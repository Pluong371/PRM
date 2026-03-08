import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import '../injection_container.dart';

class CouponService {
  final DioClient _dioClient;

  CouponService({DioClient? dioClient}) : _dioClient = dioClient ?? sl<DioClient>();

  /// Fetch all active discount codes
  Future<List<Map<String, dynamic>>> getActiveDiscounts() async {
    try {
      final response = await _dioClient.dio.get('/api/discounts');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data ?? [];
        return List<Map<String, dynamic>>.from(
          data.map((item) => Map<String, dynamic>.from(item as Map)),
        );
      }
      return [];
    } on DioException catch (e) {
      print('Error fetching discounts: $e');
      throw Exception('Failed to fetch discounts: ${e.message}');
    }
  }

  /// Validate coupon code
  /// Returns: {valid: bool, percent: int, minOrderValue: double, message: string}
  Future<Map<String, dynamic>> validateCoupon(String couponCode) async {
    try {
      if (couponCode.isEmpty) {
        return {
          'valid': false,
          'message': 'Coupon code cannot be empty',
        };
      }

      final discounts = await getActiveDiscounts();
      
      // Find matching coupon
      final coupon = discounts.firstWhere(
        (d) => (d['Code'] as String).toUpperCase() == couponCode.toUpperCase(),
        orElse: () => {},
      );

      if (coupon.isEmpty) {
        return {
          'valid': false,
          'message': 'Invalid coupon code',
        };
      }

      // Check date validity
      final startDate = DateTime.tryParse(coupon['StartDate'] as String? ?? '');
      final endDate = DateTime.tryParse(coupon['EndDate'] as String? ?? '');
      final now = DateTime.now();

      if (startDate != null && now.isBefore(startDate)) {
        return {
          'valid': false,
          'message': 'Coupon not yet valid',
        };
      }

      if (endDate != null && now.isAfter(endDate)) {
        return {
          'valid': false,
          'message': 'Coupon has expired',
        };
      }

      return {
        'valid': true,
        'percent': coupon['Percent'] ?? 0,
        'minOrderValue': coupon['MinOrderValue'] ?? 0.0,
        'message': 'Coupon applied successfully',
      };
    } catch (e) {
      print('Error validating coupon: $e');
      return {
        'valid': false,
        'message': 'Error validating coupon',
      };
    }
  }

  /// Apply coupon and calculate discount
  /// Returns: {valid: bool, discountPercent: double, discountAmount: double, message: string}
  Future<Map<String, dynamic>> applyCoupon({
    required String couponCode,
    required double subtotal,
  }) async {
    try {
      final validation = await validateCoupon(couponCode);

      if (!(validation['valid'] as bool)) {
        return {
          'valid': false,
          'discountPercent': 0.0,
          'discountAmount': 0.0,
          'message': validation['message'] ?? 'Invalid coupon',
        };
      }

      final minOrderValue = (validation['minOrderValue'] as num?)?.toDouble() ?? 0.0;
      if (subtotal < minOrderValue) {
        return {
          'valid': false,
          'discountPercent': 0.0,
          'discountAmount': 0.0,
          'message': 'Minimum order value of \$${minOrderValue.toStringAsFixed(2)} required',
        };
      }

      final discountPercent = ((validation['percent'] as num?)?.toDouble() ?? 0.0);
      final discountAmount = subtotal * (discountPercent / 100);

      return {
        'valid': true,
        'discountPercent': discountPercent,
        'discountAmount': discountAmount,
        'message': 'Coupon applied successfully! ${discountPercent.toStringAsFixed(0)}% discount',
      };
    } catch (e) {
      print('Error applying coupon: $e');
      return {
        'valid': false,
        'discountPercent': 0.0,
        'discountAmount': 0.0,
        'message': 'Error applying coupon',
      };
    }
  }
}
