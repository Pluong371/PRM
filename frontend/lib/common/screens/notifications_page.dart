import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thong bao'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.notifications.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: () async {
                  await provider.markAllAsRead();
                },
                child: const Text('Doc het'),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.error ?? 'Co loi xay ra'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: provider.loadNotifications,
                    child: const Text('Thu lai'),
                  ),
                ],
              ),
            );
          }

          if (provider.notifications.isEmpty) {
            return const Center(
              child: Text('Chua co thong bao nao'),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.loadNotifications,
            child: ListView.builder(
              itemCount: provider.notifications.length,
              itemBuilder: (context, index) {
                final item = provider.notifications[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: item.isRead ? Colors.grey.shade300 : Colors.blue.shade100,
                    child: Icon(
                      item.isRead ? Icons.notifications_none : Icons.notifications,
                      color: item.isRead ? Colors.grey.shade700 : Colors.blue.shade700,
                    ),
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: item.isRead ? FontWeight.w400 : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(item.message),
                  trailing: item.isRead
                      ? null
                      : TextButton(
                          onPressed: () => provider.markAsRead(item.id),
                          child: const Text('Da doc'),
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
