class ApiConstants {
  static const String baseUrl =
      'http://10.0.2.2:8080'; // Android emulator → localhost
  // static const String baseUrl = 'http://localhost:8080'; // Web / iOS simulator

  // Auth
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String sendRegisterOtp = '/api/auth/register/send-otp';
  static const String sendForgotPasswordOtp =
      '/api/auth/forgot-password/send-otp';
  static const String resetPassword = '/api/auth/forgot-password/reset';

  // Profile
  static const String profile = '/api/profile';
  static const String profileUpdate = '/api/profile/update';
  static const String profileChangePassword = '/api/profile/change-password';

  // Products
  static const String products = '/api/customer/products';
  static const String categories = '/api/customer/products/categories';
  static const String brands = '/api/customer/products/brands';

  // Cart
  static const String cart = '/api/customer/cart';
  static const String cartItems = '/api/customer/cart/items';

  // Orders
  static const String orders = '/api/customer/orders';
}
