import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';

import 'account_management_screen.dart';
import 'admin_dashboard_screen.dart';
import 'order_monitor_screen.dart';
import '../shared/staff_profile_screen.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _index = 0;

  void _refreshOnTabSwitch() {
    context.read<ProductProvider>().loadProducts();
    context.read<OrderProvider>().loadOrders();
    context.read<AdminProvider>().loadAccounts();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshOnTabSwitch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = const [
      AdminDashboardScreen(),
      AccountManagementScreen(),
      OrderMonitorScreen(),
      StaffProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
          _refreshOnTabSwitch();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            label: 'Accounts',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
