import 'product.dart';

class CartItem {
  final Product product;
  final int quantity;
  final String size;

  const CartItem({
    required this.product,
    required this.quantity,
    required this.size,
  });

  CartItem copyWith({Product? product, int? quantity, String? size}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      size: size ?? this.size,
    );
  }

  double get lineTotal => product.finalPrice * quantity;
}
