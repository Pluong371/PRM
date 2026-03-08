import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../common/providers/admin_provider.dart';
import 'admin_dashboard_page.dart';
import 'admin_products_page.dart';
import 'admin_users_page.dart';

class AdminMainPage extends StatefulWidget {
  const AdminMainPage({super.key});

  @override
  State<AdminMainPage> createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const AdminDashboardPage(),
    const AdminProductsPage(),
    const AdminUsersPage(),
  ];

  final List<String> _pageTitles = [
    'Dashboard',
    'Quản lý Sản phẩm',
    'Quản lý Người dùng',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.grey[100],
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Sản phẩm'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Người dùng'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _pageTitles[_selectedIndex],
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      // Admin Info
                      Consumer<AdminProvider>(
                        builder: (context, adminProvider, _) {
                          final stats = adminProvider.dashboard;
                          return Row(
                            children: [
                              _QuickStat(
                                icon: Icons.shopping_bag,
                                label: 'Đơn hàng',
                                value: '${stats['totalOrders'] ?? 0}',
                              ),
                              const SizedBox(width: 16),
                              _QuickStat(
                                icon: Icons.attach_money,
                                label: 'Doanh thu',
                                value: '\$${stats['totalRevenue'] ?? 0}',
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Page Content
                Expanded(
                  child: _pages[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
