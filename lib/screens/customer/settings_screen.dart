import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _notifEnabledKey = 'settings_notifications_enabled';
  static const _orderUpdatesKey = 'settings_order_updates_enabled';

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  bool _notificationsEnabled = true;
  bool _orderUpdatesEnabled = true;
  bool _isSavingProfile = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _notificationsEnabled = prefs.getBool(_notifEnabledKey) ?? true;
      _orderUpdatesEnabled = prefs.getBool(_orderUpdatesKey) ?? true;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty.')),
      );
      return;
    }

    setState(() => _isSavingProfile = true);
    await context.read<AuthProvider>().updateProfile(name: name, phone: phone);
    if (!mounted) return;
    setState(() => _isSavingProfile = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account info updated.')),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    if (user != null &&
        _nameController.text != user.name &&
        !_isSavingProfile) {
      _nameController.text = user.name;
      _phoneController.text = user.phone;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Account settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Personal info',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSavingProfile ? null : _saveProfile,
                      child:
                          Text(_isSavingProfile ? 'Saving...' : 'Save profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Notifications',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Enable notifications'),
                  subtitle: const Text('Receive app alerts and promotions.'),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    _savePreference(_notifEnabledKey, value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Order updates'),
                  subtitle:
                      const Text('Get notified when order status changes.'),
                  value: _orderUpdatesEnabled,
                  onChanged: _notificationsEnabled
                      ? (value) {
                          setState(() => _orderUpdatesEnabled = value);
                          _savePreference(_orderUpdatesKey, value);
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
