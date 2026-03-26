class VnPayDemoService {
  static const String demoUrl =
      'http://sandbox.vnpayment.vn/tryitnow/Home/CreateOrder';

  static String buildDemoUrl({
    required String orderCode,
    required int amount,
    required String paymentMethod,
  }) {
    return demoUrl;
  }

  static bool isSuccessUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('vnp_responsecode=00') ||
        lower.contains('transactionstatus=00') ||
        lower.contains('responsecode=00') ||
        lower.contains('thanhtoanthanhcong');
  }

  static bool isFailureUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('vnp_responsecode=24') ||
        lower.contains('vnp_responsecode=99') ||
        lower.contains('transactionstatus=02') ||
        lower.contains('huy') ||
        lower.contains('cancel');
  }
}
