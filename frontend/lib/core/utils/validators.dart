class Validators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email không được để trống';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Email không hợp lệ';
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.isEmpty)
      return 'Tên đăng nhập không được để trống';
    if (value.length < 3) return 'Tên đăng nhập phải có ít nhất 3 ký tự';
    if (value.length > 50) return 'Tên đăng nhập không quá 50 ký tự';
    if (value.contains('<') || value.contains('>')) {
      return 'Tên đăng nhập không được chứa ký tự < hoặc >';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Mật khẩu không được để trống';
    if (value.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty)
      return 'Xác nhận mật khẩu không được để trống';
    if (value != password) return 'Mật khẩu không khớp';
    return null;
  }

  static String? fullName(String? value) {
    if (value == null || value.isEmpty) return 'Họ tên không được để trống';
    if (value.contains('<') || value.contains('>')) {
      return 'Họ tên không được chứa ký tự < hoặc >';
    }
    return null;
  }

  static String? required(String? value, [String fieldName = 'Trường này']) {
    if (value == null || value.isEmpty) return '$fieldName không được để trống';
    return null;
  }
}
