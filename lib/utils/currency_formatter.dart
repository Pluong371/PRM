String formatCurrency(num value, {String suffix = 'đ'}) {
  final rounded = value.round();
  final absolute = rounded.abs().toString();
  final formatted = absolute.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final sign = rounded < 0 ? '-' : '';

  if (suffix.isEmpty) {
    return '$sign$formatted';
  }

  return '$sign$formatted $suffix';
}
