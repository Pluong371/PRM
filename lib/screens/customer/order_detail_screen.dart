import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../utils/currency_formatter.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>().orders;
    Order? found;
    for (final item in orders) {
      if (item.id == orderId) {
        found = item;
        break;
      }
    }

    if (found == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Detail')),
        body: const Center(
          child: Text('Order not found or has been updated.'),
        ),
      );
    }

    final order = found;

    return Scaffold(
      appBar: AppBar(title: const Text('Order Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ID: ${order.id}'),
            Text('Status: ${order.status.name}'),
            Text('Payment: ${order.paymentMethod}'),
            Text(
              'Payment status: ${order.isPaid ? 'Paid' : 'Unpaid'}',
              style: TextStyle(
                color: order.isPaid ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text('Address: ${order.shippingAddress}'),
            const SizedBox(height: 12),
            Text(
              'Items',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: order.items.length,
                itemBuilder: (context, index) {
                  final item = order.items[index];
                  return ListTile(
                    title: Text(item.product.name),
                    subtitle: Text('x${item.quantity} • Size ${item.size}'),
                    trailing: Text(formatCurrency(item.lineTotal)),
                  );
                },
              ),
            ),
            Text(
              'Total: ${formatCurrency(order.total)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
