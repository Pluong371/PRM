import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/smart_image.dart';

class OrderMonitorScreen extends StatelessWidget {
  const OrderMonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>().orders;

    if (orders.isEmpty) {
      return const Center(child: Text('No orders found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final firstItem = order.items.first;
        final product = firstItem.product;
        final previewItems = order.items.take(3).toList();
        final createdDate =
            '${order.createdAt.day.toString().padLeft(2, '0')}/${order.createdAt.month.toString().padLeft(2, '0')}/${order.createdAt.year}';
        final totalItems = order.items.fold<int>(0, (sum, item) {
          return sum + item.quantity;
        });
        final extraItems = order.items.length - 1;
        final statusColor = switch (order.status) {
          OrderStatus.processing => Colors.blue,
          OrderStatus.delivered => Colors.green,
          OrderStatus.cancelled => Colors.red,
        };
        final paymentColor = order.isPaid ? Colors.green : Colors.orange;
        final paymentLabel = order.isPaid ? 'PAID' : 'UNPAID';

        return Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.id.substring(0, 8)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalItems item(s) • $createdDate',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    DropdownButton<OrderStatus>(
                      value: order.status,
                      items: OrderStatus.values
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          context
                              .read<OrderProvider>()
                              .changeOrderStatus(order.id, value);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        order.status.name,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: paymentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            order.isPaid
                                ? Icons.check_circle
                                : Icons.access_time_filled,
                            size: 12,
                            color: paymentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            paymentLabel,
                            style: TextStyle(
                              color: paymentColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(previewItems.length, (imgIndex) {
                        final imageProduct = previewItems[imgIndex].product;
                        final source = imageProduct.imageUrls.isNotEmpty
                            ? imageProduct.imageUrls.first
                            : 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=800';

                        return Padding(
                          padding: EdgeInsets.only(
                            right: imgIndex == previewItems.length - 1 ? 0 : 6,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SmartImage(
                                source: source,
                                width: 44,
                                height: 64,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              if (imgIndex == previewItems.length - 1 &&
                                  order.items.length > 3)
                                Container(
                                  width: 44,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '+${order.items.length - 3}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            extraItems > 0
                                ? '+$extraItems sản phẩm khác'
                                : '1 sản phẩm',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Total: ${formatCurrency(order.total)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Payment: ${order.paymentMethod}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.shippingAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
