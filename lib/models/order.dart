import 'product.dart';

enum OrderStatus { processing, delivered, cancelled }

class OrderItem {
  final Product product;
  final int quantity;
  final String size;

  const OrderItem({
    required this.product,
    required this.quantity,
    required this.size,
  });

  double get lineTotal => product.finalPrice * quantity;
}

class Order {
  final String id;
  final String userId;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String shippingAddress;
  final String paymentMethod;
  final OrderStatus status;
  final bool isPaid;

  const Order({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.items,
    required this.shippingAddress,
    required this.paymentMethod,
    required this.status,
    required this.isPaid,
  });

  double get total => items.fold(0, (sum, item) => sum + item.lineTotal);

  Order copyWith({
    String? id,
    String? userId,
    DateTime? createdAt,
    List<OrderItem>? items,
    String? shippingAddress,
    String? paymentMethod,
    OrderStatus? status,
    bool? isPaid,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}
