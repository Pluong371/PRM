import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../utils/currency_formatter.dart';
import 'payment_qr_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressController =
      TextEditingController(text: '123 Tran Hung Dao, Ho Chi Minh City');
  String _payment = 'COD';

  Future<void> _confirmOrder(BuildContext context) async {
    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter shipping address')),
      );
      return;
    }

    var paid = true;
    if (_payment == 'VNPay' || _payment == 'Momo') {
      final orderCode = 'OD${DateTime.now().millisecondsSinceEpoch}';
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentQrScreen(
            amount: cart.total,
            orderCode: orderCode,
            paymentMethod: _payment,
          ),
        ),
      );
      paid = result == true;
    }

    if (!mounted || !paid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment was not completed')),
        );
      }
      return;
    }

    context.read<OrderProvider>().placeOrder(
          cartItems: List.of(cart.items),
          shippingAddress: _addressController.text.trim(),
          paymentMethod: _payment,
          isPaid: _payment == 'COD' ? false : true,
          userId: context.read<AuthProvider>().currentUser?.id ??
              '11111111-1111-1111-1111-111111111111',
        );

    cart.clearCart();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Order confirmed!')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _addressController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Shipping address',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Payment Method',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ...['COD', 'VNPay', 'Momo'].map(
              (method) => RadioListTile<String>(
                value: method,
                groupValue: _payment,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _payment = value);
                  }
                },
                title: Text(method),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Order Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ...cart.items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.product.name),
                subtitle: Text('x${item.quantity} • Size ${item.size}'),
                trailing: Text(formatCurrency(item.lineTotal)),
              ),
            ),
            const Divider(),
            Text('Total: ${formatCurrency(cart.total)}'),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _confirmOrder(context),
                child: const Text('Confirm order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
