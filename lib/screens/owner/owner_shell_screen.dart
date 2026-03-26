import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';

import 'dashboard_screen.dart';
import 'manage_discounts_screen.dart';
import 'manage_products_screen.dart';
import 'order_management_screen.dart';
import '../shared/staff_profile_screen.dart';

class OwnerShellScreen extends StatefulWidget {
  const OwnerShellScreen({super.key});

  @override
  State<OwnerShellScreen> createState() => _OwnerShellScreenState();
}

class _OwnerShellScreenState extends State<OwnerShellScreen> {
  int _index = 0;
  bool _initialized = false;

  void _refreshOnTabSwitch() {
    context.read<ProductProvider>().loadProducts();
    context.read<OrderProvider>().loadOrders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final user = context.read<AuthProvider>().currentUser;
    if (user != null && user.role == UserRole.owner) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refreshOnTabSwitch();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = const [
      DashboardScreen(),
      ManageProductsScreen(),
      ManageDiscountsScreen(),
      OrderManagementScreen(),
      StaffProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Shop Owner')),
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
          _refreshOnTabSwitch();
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.checkroom_outlined), label: 'Products'),
          NavigationDestination(
              icon: Icon(Icons.discount_outlined), label: 'Discounts'),
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined), label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
