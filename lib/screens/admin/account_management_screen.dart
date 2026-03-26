import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/admin_provider.dart';

class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  String _generateGuid() {
    final now = DateTime.now();
    final raw = (now.microsecondsSinceEpoch.toRadixString(16) +
            now.millisecondsSinceEpoch.toRadixString(16))
        .padRight(32, '0')
        .substring(0, 32);
    return '${raw.substring(0, 8)}-${raw.substring(8, 12)}-${raw.substring(12, 16)}-${raw.substring(16, 20)}-${raw.substring(20, 32)}';
  }

  void _openEditAccountSheet(BuildContext context, AppUser account) {
    final provider = context.read<AdminProvider>();
    final nameCtrl = TextEditingController(text: account.name);
    final emailCtrl = TextEditingController(text: account.email);
    final phoneCtrl = TextEditingController(text: account.phone);
    var role = account.role;

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
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<UserRole>(
                value: role,
                items: UserRole.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setStateModal(() => role = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty ||
                        emailCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Name and email are required'),
                        ),
                      );
                      return;
                    }

                    provider.updateAccount(
                      account.copyWith(
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        role: role,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Save account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                final nameCtrl = TextEditingController();
                final emailCtrl = TextEditingController();
                final phoneCtrl = TextEditingController();
                UserRole role = UserRole.customer;

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
                            controller: nameCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Name'),
                          ),
                          TextField(
                            controller: emailCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                          ),
                          TextField(
                            controller: phoneCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Phone'),
                          ),
                          DropdownButtonFormField<UserRole>(
                            value: role,
                            items: UserRole.values
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setStateModal(() => role = value);
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () {
                                if (nameCtrl.text.trim().isEmpty ||
                                    emailCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Name and email are required',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                provider.createAccount(
                                  AppUser(
                                    id: _generateGuid(),
                                    name: nameCtrl.text.trim(),
                                    email: emailCtrl.text.trim(),
                                    phone: phoneCtrl.text.trim(),
                                    role: role,
                                  ),
                                );
                                Navigator.pop(context);
                              },
                              child: const Text('Create account'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create New Account'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: provider.accounts.length,
              itemBuilder: (context, index) {
                final account = provider.accounts[index];
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(account.name.characters.first.toUpperCase()),
                    ),
                    title: Text(account.name),
                    subtitle:
                        Text('${account.email}\nRole: ${account.role.name}'),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          onPressed: () =>
                              _openEditAccountSheet(context, account),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        Switch(
                          value: account.isActive,
                          onChanged: (_) => provider.toggleActive(account.id),
                        ),
                      ],
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
