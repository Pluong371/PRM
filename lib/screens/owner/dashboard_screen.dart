import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/discount_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/stat_card.dart';
import '../../utils/currency_formatter.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>().orders;
    final products = context.watch<ProductProvider>().products;
    final discounts = context.watch<DiscountProvider>().discounts;

    final revenue = orders.fold<double>(0, (sum, order) => sum + order.total);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatCard(
          label: 'Total Revenue',
          value: formatCurrency(revenue),
          icon: Icons.payments_outlined,
        ),
        StatCard(
          label: 'Total Orders',
          value: '${orders.length}',
          icon: Icons.receipt_long_outlined,
        ),
        StatCard(
          label: 'Total Products',
          value: '${products.length}',
          icon: Icons.inventory_2_outlined,
        ),
        StatCard(
          label: 'Total Discounts',
          value: '${discounts.length}',
          icon: Icons.percent_outlined,
        ),
      ],
    );
  }
}
