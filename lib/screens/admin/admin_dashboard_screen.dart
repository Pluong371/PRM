import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/order.dart';
import '../../providers/admin_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/api_service.dart';
import '../../utils/currency_formatter.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  static final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final adminProvider = context.watch<AdminProvider>();
    final productProvider = context.watch<ProductProvider>();

    final orders = orderProvider.orders;
    final users = adminProvider.accounts;
    final products = productProvider.products;

    final paidOrders = orders.where((order) => order.isPaid).toList();
    final deliveredOrders =
        orders.where((order) => order.status == OrderStatus.delivered).toList();
    final processingOrders = orders
        .where((order) => order.status == OrderStatus.processing)
        .toList();
    final cancelledOrders =
        orders.where((order) => order.status == OrderStatus.cancelled).toList();

    final totalRevenue = paidOrders.fold<double>(
      0,
      (sum, order) => sum + order.total,
    );

    final allOwners =
        users.where((user) => user.role == UserRole.owner).toList();
    final activeOwners = allOwners.where((owner) => owner.isActive).toList();
    final allCustomers =
        users.where((user) => user.role == UserRole.customer).toList();

    final lowStockCount = products
        .where((product) => product.stock > 0 && product.stock <= 20)
        .length;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final revenue7Days = List<_DailyRevenue>.generate(7, (index) {
      final day = today.subtract(Duration(days: 6 - index));
      final value = paidOrders.where((order) {
        final created = order.createdAt;
        return created.year == day.year &&
            created.month == day.month &&
            created.day == day.day;
      }).fold<double>(0, (sum, order) => sum + order.total);
      return _DailyRevenue(day: day, value: value);
    });

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          context.read<OrderProvider>().loadOrders(),
          context.read<AdminProvider>().loadAccounts(),
          context.read<ProductProvider>().loadProducts(),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'System Overview',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _MetricGrid(
            items: [
              _MetricItem(
                title: 'Revenue',
                value: formatCurrency(totalRevenue),
                icon: Icons.payments_outlined,
              ),
              _MetricItem(
                title: 'Total Orders',
                value: '${orders.length}',
                icon: Icons.receipt_long_outlined,
              ),
              _MetricItem(
                title: 'Delivered',
                value: '${deliveredOrders.length}',
                icon: Icons.local_shipping_outlined,
              ),
              _MetricItem(
                title: 'Processing',
                value: '${processingOrders.length}',
                icon: Icons.pending_actions_outlined,
              ),
              _MetricItem(
                title: 'Customers',
                value: '${allCustomers.length}',
                icon: Icons.people_outline,
              ),
              _MetricItem(
                title: 'Active Owners',
                value: '${activeOwners.length}/${allOwners.length}',
                icon: Icons.storefront_outlined,
              ),
              _MetricItem(
                title: 'Products',
                value: '${products.length}',
                icon: Icons.inventory_2_outlined,
              ),
              _MetricItem(
                title: 'Low Stock',
                value: '$lowStockCount',
                icon: Icons.warning_amber_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenue by Shop Owner',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<OwnerRevenueSummary>>(
                    future: _apiService.fetchOwnerRevenueSummary(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final rows = snapshot.data ?? const [];
                      if (rows.isEmpty) {
                        return const Text('No owner revenue data yet.');
                      }

                      return Column(
                        children: rows.map((row) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 16,
                              child: Text(
                                row.ownerName.isEmpty
                                    ? 'O'
                                    : row.ownerName.characters.first
                                        .toUpperCase(),
                              ),
                            ),
                            title: Text(row.ownerName),
                            subtitle: Text(
                              '${row.ownerEmail}\nProducts: ${row.productCount} • Paid orders: ${row.paidOrders} • Sold: ${row.itemsSold}',
                            ),
                            isThreeLine: true,
                            trailing: Text(
                              formatCurrency(row.revenue),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenue 7 Days',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Paid orders only',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  _RevenueMiniChart(data: revenue7Days),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Health',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _HealthRow(
                    label: 'Paid Orders',
                    value: '${paidOrders.length}',
                  ),
                  _HealthRow(
                    label: 'Unpaid Orders',
                    value: '${orders.length - paidOrders.length}',
                  ),
                  _HealthRow(
                    label: 'Delivered',
                    value: '${deliveredOrders.length}',
                  ),
                  _HealthRow(
                    label: 'Processing',
                    value: '${processingOrders.length}',
                  ),
                  _HealthRow(
                    label: 'Cancelled',
                    value: '${cancelledOrders.length}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shop Owners',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (allOwners.isEmpty)
                    const Text('No owner accounts found.')
                  else
                    ...allOwners.map((owner) {
                      final statusColor =
                          owner.isActive ? Colors.green : Colors.red;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          child:
                              Text(owner.name.characters.first.toUpperCase()),
                        ),
                        title: Text(owner.name),
                        subtitle: Text(owner.email),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            owner.isActive ? 'ACTIVE' : 'INACTIVE',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyRevenue {
  final DateTime day;
  final double value;

  const _DailyRevenue({required this.day, required this.value});
}

class _RevenueMiniChart extends StatelessWidget {
  final List<_DailyRevenue> data;

  const _RevenueMiniChart({required this.data});

  static const _weekLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final maxValue = data
        .map((item) => item.value)
        .fold<double>(0, (max, value) => value > max ? value : max);
    final effectiveMax = maxValue <= 0 ? 1 : maxValue;

    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((entry) {
          final ratio = (entry.value / effectiveMax).clamp(0, 1);
          final barHeight = 20.0 + (ratio * 90.0);
          final label = _weekLabels[entry.day.weekday - 1];

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        entry.value <= 0 ? '0' : formatCurrency(entry.value),
                        style: Theme.of(context).textTheme.labelSmall,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    width: double.infinity,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MetricItem {
  final String title;
  final String value;
  final IconData icon;

  const _MetricItem({
    required this.title,
    required this.value,
    required this.icon,
  });
}

class _MetricGrid extends StatelessWidget {
  final List<_MetricItem> items;

  const _MetricGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.7,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, size: 20),
                const Spacer(),
                Text(
                  item.value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(item.title, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final String value;

  const _HealthRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
