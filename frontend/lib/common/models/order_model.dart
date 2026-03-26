class OrderItem {
  final String orderId;
  final String productId;
  final String productName;
  final String? productCategory;
  final String? productDescription;
  final String? imageUrl;
  final String sizeLabel;
  final String? colorHex;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  const OrderItem({
    required this.orderId,
    required this.productId,
    required this.productName,
    this.productCategory,
    this.productDescription,
    this.imageUrl,
    required this.sizeLabel,
    this.colorHex,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['Quantity'] ?? json['quantity'] ?? 0) as num;
    final unit = (json['UnitPrice'] ?? json['unitPrice'] ?? 0) as num;
    final line = (json['LineTotal'] ?? json['lineTotal'] ?? 0) as num;

    return OrderItem(
      orderId: (json['OrderId'] ?? json['orderId'] ?? '').toString(),
      productId: (json['ProductId'] ?? json['productId'] ?? '').toString(),
      productName: (json['Name'] ?? json['productName'] ?? '').toString(),
      productCategory: (json['Category'] ?? json['productCategory'])?.toString(),
      productDescription:
          (json['Description'] ?? json['productDescription'])?.toString(),
      imageUrl: (json['ImageUrl'] ?? json['imageUrl'])?.toString(),
      sizeLabel: (json['SizeLabel'] ?? json['sizeLabel'] ?? '').toString(),
      colorHex: (json['ColorHex'] ?? json['colorHex'])?.toString(),
      quantity: qty.toInt(),
      unitPrice: unit.toDouble(),
      lineTotal: line.toDouble(),
    );
  }
}

class Order {
  final String id;
  final String orderCode;
  final String userId;
  final String shippingAddress;
  final String paymentMethod;
  final String paymentStatus;
  final String status;
  final double subtotal;
  final double discountAmount;
  final double total;
  final DateTime createdAt;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.orderCode,
    required this.userId,
    required this.shippingAddress,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.subtotal,
    required this.discountAmount,
    required this.total,
    required this.createdAt,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final subtotalRaw = (json['Subtotal'] ?? json['subtotal'] ?? 0) as num;
    final discountRaw =
        (json['DiscountAmount'] ?? json['discountAmount'] ?? 0) as num;
    final totalRaw = (json['Total'] ?? json['total'] ?? 0) as num;
    final createdRaw =
        (json['CreatedAt'] ?? json['createdAt'] ?? DateTime.now().toIso8601String())
            .toString();

    final rawItems = (json['items'] ?? json['Items']);
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map(
              (e) => OrderItem.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList()
        : <OrderItem>[];

    return Order(
      id: (json['Id'] ?? json['id'] ?? '').toString(),
      orderCode: (json['OrderCode'] ?? json['orderCode'] ?? '').toString(),
      userId: (json['UserId'] ?? json['userId'] ?? '').toString(),
      shippingAddress:
          (json['ShippingAddress'] ?? json['shippingAddress'] ?? '').toString(),
      paymentMethod:
          (json['PaymentMethod'] ?? json['paymentMethod'] ?? '').toString(),
      paymentStatus:
          (json['PaymentStatus'] ?? json['paymentStatus'] ?? '').toString(),
      status: (json['Status'] ?? json['status'] ?? '').toString(),
      subtotal: subtotalRaw.toDouble(),
      discountAmount: discountRaw.toDouble(),
      total: totalRaw.toDouble(),
      createdAt: DateTime.tryParse(createdRaw) ?? DateTime.now(),
      items: items,
    );
  }

  Order copyWith({
    String? status,
    String? paymentStatus,
    List<OrderItem>? items,
  }) {
    return Order(
      id: id,
      orderCode: orderCode,
      userId: userId,
      shippingAddress: shippingAddress,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      status: status ?? this.status,
      subtotal: subtotal,
      discountAmount: discountAmount,
      total: total,
      createdAt: createdAt,
      items: items ?? this.items,
    );
  }
}