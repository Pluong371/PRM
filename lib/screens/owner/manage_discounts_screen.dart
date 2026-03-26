import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/discount.dart';
import '../../providers/discount_provider.dart';
import '../../utils/currency_formatter.dart';

class ManageDiscountsScreen extends StatelessWidget {
  const ManageDiscountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiscountProvider>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                final codeCtrl = TextEditingController();
                final percentCtrl = TextEditingController();
                final minCtrl = TextEditingController();
                var startDate = DateTime.now();
                var endDate = DateTime.now().add(const Duration(days: 30));

                showModalBottomSheet(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  builder: (_) => StatefulBuilder(
                    builder: (context, setStateModal) => Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        MediaQuery.of(context).viewInsets.bottom + 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: codeCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Code'),
                          ),
                          TextField(
                            controller: percentCtrl,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Percentage'),
                          ),
                          TextField(
                            controller: minCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Minimum order value'),
                          ),
                          const SizedBox(height: 10),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Start date'),
                            subtitle: Text(
                              startDate.toLocal().toString().split(' ').first,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.calendar_today_outlined),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setStateModal(() {
                                    startDate = picked;
                                    if (endDate.isBefore(startDate)) {
                                      endDate = startDate;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('End date'),
                            subtitle: Text(
                              endDate.toLocal().toString().split(' ').first,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.calendar_today_outlined),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate,
                                  firstDate: startDate,
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setStateModal(() => endDate = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () {
                                final code = codeCtrl.text.trim();
                                final percent =
                                    double.tryParse(percentCtrl.text) ?? 0;
                                final minOrder =
                                    double.tryParse(minCtrl.text) ?? 0;

                                if (code.isEmpty ||
                                    percent <= 0 ||
                                    percent > 100) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please enter valid code and percentage (1-100)',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                provider.addDiscount(
                                  DiscountCode(
                                    id: DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString(),
                                    code: code,
                                    percent: percent,
                                    startDate: startDate,
                                    endDate: endDate,
                                    minOrderValue: minOrder,
                                  ),
                                );
                                Navigator.pop(context);
                              },
                              child: const Text('Create discount'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Discount'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: provider.discounts.length,
              itemBuilder: (context, index) {
                final discount = provider.discounts[index];
                return Card(
                  elevation: 0,
                  child: ListTile(
                    title: Text(discount.code),
                    subtitle: Text(
                      '${discount.percent.toStringAsFixed(0)}% • Min ${formatCurrency(discount.minOrderValue)}\n${discount.startDate.toLocal().toString().split(' ').first} - ${discount.endDate.toLocal().toString().split(' ').first}',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
