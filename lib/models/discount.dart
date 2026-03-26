class DiscountCode {
  final String id;
  final String code;
  final double percent;
  final DateTime startDate;
  final DateTime endDate;
  final double minOrderValue;

  const DiscountCode({
    required this.id,
    required this.code,
    required this.percent,
    required this.startDate,
    required this.endDate,
    required this.minOrderValue,
  });

  bool isValidFor(double amount, DateTime now) {
    final inDateRange = !now.isBefore(startDate) && !now.isAfter(endDate);
    return inDateRange && amount >= minOrderValue;
  }
}
