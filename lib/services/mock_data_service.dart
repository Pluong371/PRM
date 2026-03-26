import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/discount.dart';
import '../models/order.dart';
import '../models/product.dart';

class MockDataService {
  static final List<Product> products = [
    Product(
      id: 'p1',
      name: 'Classic Denim Jacket',
      price: 899000,
      category: 'Men',
      description:
          'A timeless denim jacket for casual and smart-casual outfits.',
      imageUrls: const [
        'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=800',
        'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=800',
      ],
      sizes: const ['S', 'M', 'L', 'XL'],
      colors: const [Colors.indigo, Colors.black, Colors.blueGrey],
      reviewsCount: 124,
      discountPercent: 10,
    ),
    Product(
      id: 'p2',
      name: 'Minimal White Shirt',
      price: 459000,
      category: 'Women',
      description:
          'Soft cotton white shirt designed for effortless daily style.',
      imageUrls: const [
        'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800',
        'https://images.unsplash.com/photo-1543076447-215ad9ba6923?w=800',
      ],
      sizes: const ['S', 'M', 'L'],
      colors: const [Colors.white, Colors.purple, Colors.indigo],
      reviewsCount: 89,
    ),
    Product(
      id: 'p3',
      name: 'Urban Hoodie',
      price: 699000,
      category: 'New Arrival',
      description: 'Relaxed-fit hoodie with premium fabric and clean finish.',
      imageUrls: const [
        'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?w=800',
        'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=800',
      ],
      sizes: const ['M', 'L', 'XL'],
      colors: const [Colors.deepPurple, Colors.grey, Colors.black],
      reviewsCount: 65,
      discountPercent: 15,
    ),
    Product(
      id: 'p4',
      name: 'Kids Summer Set',
      price: 349000,
      category: 'Kids',
      description: 'Breathable and playful matching set for active kids.',
      imageUrls: const [
        'https://images.unsplash.com/photo-1475180098004-ca77a66827be?w=800',
        'https://images.unsplash.com/photo-1518834107812-67b0b7c58434?w=800',
      ],
      sizes: const ['S', 'M', 'L'],
      colors: const [Colors.orange, Colors.lightBlue, Colors.pinkAccent],
      reviewsCount: 41,
      discountPercent: 20,
    ),
    Product(
      id: 'p5',
      name: 'Tailored Blazer',
      price: 1259000,
      category: 'Women',
      description:
          'Structured blazer that elevates both office and event looks.',
      imageUrls: const [
        'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=800',
        'https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=800',
      ],
      sizes: const ['S', 'M', 'L'],
      colors: const [Colors.black, Colors.brown, Colors.indigo],
      reviewsCount: 72,
    ),
    Product(
      id: 'p6',
      name: 'Sale Jogger Pants',
      price: 399000,
      category: 'Sale',
      description: 'Daily joggers with stretch comfort and modern silhouette.',
      imageUrls: const [
        'https://images.unsplash.com/photo-1473966968600-fa801b869a1a?w=800',
        'https://images.unsplash.com/photo-1434389677669-e08b4cac3105?w=800',
      ],
      sizes: const ['S', 'M', 'L', 'XL'],
      colors: const [Colors.grey, Colors.black54, Colors.blueGrey],
      reviewsCount: 113,
      discountPercent: 25,
    ),
  ];

  static final List<DiscountCode> discountCodes = [
    DiscountCode(
      id: 'd1',
      code: 'SPRING10',
      percent: 10,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      minOrderValue: 500000,
    ),
    DiscountCode(
      id: 'd2',
      code: 'FREESTYLE15',
      percent: 15,
      startDate: DateTime(2026, 2, 1),
      endDate: DateTime(2026, 7, 31),
      minOrderValue: 1000000,
    ),
  ];

  static final List<AppUser> users = [
    const AppUser(
      id: 'u1',
      name: 'Nguyen An',
      email: 'user@fashion.app',
      phone: '0901000001',
      role: UserRole.customer,
    ),
    const AppUser(
      id: 'o1',
      name: 'Shop Owner',
      email: 'owner@fashion.app',
      phone: '0901000002',
      role: UserRole.owner,
    ),
    const AppUser(
      id: 'a1',
      name: 'System Admin',
      email: 'admin@fashion.app',
      phone: '0901000003',
      role: UserRole.admin,
    ),
  ];

  static final List<Order> orders = [
    Order(
      id: 'ord1',
      userId: 'u1',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      items: [
        OrderItem(product: products[0], quantity: 1, size: 'M'),
        OrderItem(product: products[2], quantity: 2, size: 'L'),
      ],
      shippingAddress: '123 Tran Hung Dao, Ho Chi Minh City',
      paymentMethod: 'VNPay',
      status: OrderStatus.processing,
      isPaid: true,
    ),
    Order(
      id: 'ord2',
      userId: 'u1',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      items: [OrderItem(product: products[1], quantity: 1, size: 'S')],
      shippingAddress: '66 Le Loi, Da Nang',
      paymentMethod: 'COD',
      status: OrderStatus.delivered,
      isPaid: true,
    ),
    Order(
      id: 'ord3',
      userId: 'u1',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      items: [OrderItem(product: products[5], quantity: 1, size: 'M')],
      shippingAddress: '12 Hai Ba Trung, Ha Noi',
      paymentMethod: 'Momo',
      status: OrderStatus.cancelled,
      isPaid: false,
    ),
  ];
}
