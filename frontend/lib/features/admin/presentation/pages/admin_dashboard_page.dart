import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../common/providers/admin_provider.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<AdminProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, _) {
          if (adminProvider.isLoading && adminProvider.dashboard.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (adminProvider.error != null && adminProvider.dashboard.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(adminProvider.error ?? 'Unknown error'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: adminProvider.loadDashboard,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final stats = adminProvider.dashboard;
          return RefreshIndicator(
            onRefresh: adminProvider.loadDashboard,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Tổng quan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      title: 'Users',
                      value: '${stats['totalUsers'] ?? 0}',
                    ),
                    _StatCard(
                      title: 'Products',
                      value: '${stats['totalProducts'] ?? 0}',
                    ),
                    _StatCard(
                      title: 'Orders',
                      value: '${stats['totalOrders'] ?? 0}',
                    ),
                    _StatCard(
                      title: 'Processing',
                      value: '${stats['processingOrders'] ?? 0}',
                    ),
                    _StatCard(
                      title: 'Revenue',
                      value: '\$${(stats['totalRevenue'] ?? 0).toString()}',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _CategorySection(provider: adminProvider),
                const SizedBox(height: 24),
                _OrdersSection(provider: adminProvider),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final AdminProvider provider;

  const _CategorySection({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Danh mục', style: Theme.of(context).textTheme.titleMedium),
            ElevatedButton(
              onPressed: () => _showCreateCategoryDialog(context),
              child: const Text('Thêm danh mục'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...provider.categories.map((category) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${category['Name'] ?? category['name'] ?? ''}'),
            subtitle: Text('${category['Description'] ?? category['description'] ?? ''}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final id = '${category['Id'] ?? category['id'] ?? ''}';
                if (id.isEmpty) return;
                await provider.deleteCategory(id);
              },
            ),
          );
        }),
      ],
    );
  }

  Future<void> _showCreateCategoryDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tạo danh mục'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên danh mục'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final description = descController.text.trim();
                if (name.isEmpty) return;

                await context.read<AdminProvider>().createCategory(
                      name: name,
                      description: description.isEmpty ? null : description,
                    );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Tạo'),
            ),
          ],
        );
      },
    );
  }
}

class _OrdersSection extends StatelessWidget {
  final AdminProvider provider;

  const _OrdersSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Đơn hàng', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...provider.orders.take(20).map((order) {
          final id = '${order['Id'] ?? ''}';
          final code = '${order['OrderCode'] ?? ''}';
          final customer = '${order['CustomerName'] ?? ''}';
          final status = '${order['Status'] ?? 'processing'}';
          final paymentStatus = '${order['PaymentStatus'] ?? 'pending'}';
          final total = '${order['Total'] ?? 0}';

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$code - $customer'),
                  const SizedBox(height: 6),
                  Text('Total: \$$total'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('Status: '),
                      DropdownButton<String>(
                        value: status,
                        items: const [
                          DropdownMenuItem(value: 'processing', child: Text('processing')),
                          DropdownMenuItem(value: 'delivered', child: Text('delivered')),
                          DropdownMenuItem(value: 'cancelled', child: Text('cancelled')),
                        ],
                        onChanged: (value) async {
                          if (value == null || value == status || id.isEmpty) return;
                          await provider.updateOrderStatus(orderId: id, status: value);
                        },
                      ),
                      const SizedBox(width: 16),
                      const Text('Payment: '),
                      DropdownButton<String>(
                        value: paymentStatus,
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('pending')),
                          DropdownMenuItem(value: 'paid', child: Text('paid')),
                          DropdownMenuItem(value: 'failed', child: Text('failed')),
                        ],
                        onChanged: (value) async {
                          if (value == null || value == paymentStatus || id.isEmpty) return;
                          await provider.updateOrderStatus(orderId: id, paymentStatus: value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
