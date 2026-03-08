import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../common/providers/admin_provider.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  String _searchQuery = '';
  bool _showActiveOnly = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<AdminProvider>().loadUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Người dùng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AdminProvider>().loadUsers();
            },
          ),
        ],
      ),
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, _) {
          if (adminProvider.isLoading && adminProvider.users.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (adminProvider.error != null && adminProvider.users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(adminProvider.error ?? 'Lỗi không xác định'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => adminProvider.loadUsers(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          // Filter users
          final filteredUsers = adminProvider.users.where((user) {
            final isActive = user['IsActive'] == true || user['isActive'] == true;
            if (_showActiveOnly && !isActive) {
              return false;
            }
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final fullName =
                  (user['FullName'] ?? user['fullName'] ?? '').toString().toLowerCase();
              final email =
                  (user['Email'] ?? user['email'] ?? '').toString().toLowerCase();
              return fullName.contains(query) || email.contains(query);
            }
            return true;
          }).toList();

          return Column(
            children: [
              // Search Section
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm người dùng...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilterChip(
                          label: const Text('Chỉ hiển thị đang hoạt động'),
                          selected: _showActiveOnly,
                          onSelected: (value) {
                            setState(() {
                              _showActiveOnly = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Stats Row
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatChip(
                      label: 'Tổng',
                      value: '${adminProvider.users.length}',
                      color: Colors.blue,
                    ),
                    _StatChip(
                      label: 'Đang hoạt động',
                      value: '${adminProvider.users.where((u) => u['IsActive'] == true || u['isActive'] == true).length}',
                      color: Colors.green,
                    ),
                    _StatChip(
                      label: 'Kết quả',
                      value: '${filteredUsers.length}',
                      color: Colors.orange,
                    ),
                  ],
                ),
              ),

              // Users List
              Expanded(
                child: filteredUsers.isEmpty
                    ? const Center(
                        child: Text('Không tìm thấy người dùng'),
                      )
                    : ListView.builder(
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return _UserCard(
                            user: user,
                            onToggleActive: () => _toggleUserActive(user),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleUserActive(Map<String, dynamic> user) async {
    final userId = user['Id'] ?? user['id'] ?? '';
    final isActive = user['IsActive'] == true || user['isActive'] == true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isActive ? 'Vô hiệu hóa người dùng?' : 'Kích hoạt người dùng?'),
        content: Text(
          isActive
              ? 'Người dùng sẽ không thể đăng nhập vào hệ thống.'
              : 'Người dùng sẽ có thể đăng nhập trở lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.red : Colors.green,
            ),
            child: Text(isActive ? 'Vô hiệu hóa' : 'Kích hoạt'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<AdminProvider>().toggleUserActive(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (isActive
                      ? 'Đã vô hiệu hóa người dùng'
                      : 'Đã kích hoạt người dùng')
                  : 'Lỗi khi cập nhật trạng thái',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onToggleActive;

  const _UserCard({
    required this.user,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final fullName = user['FullName'] ?? user['fullName'] ?? 'N/A';
    final email = user['Email'] ?? user['email'] ?? 'N/A';
    final role = user['Role'] ?? user['role'] ?? 'user';
    final isActive = user['IsActive'] == true || user['isActive'] == true;
    final createdAt = user['CreatedAt'] ?? user['createdAt'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.blue[100] : Colors.grey[300],
          child: Icon(
            Icons.person,
            color: isActive ? Colors.blue[900] : Colors.grey[700],
          ),
        ),
        title: Text(
          fullName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: $email'),
            Text('Vai trò: ${_getRoleLabel(role)}'),
            if (createdAt.isNotEmpty)
              Text(
                'Tham gia: ${_formatDate(createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.green[100] : Colors.red[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? 'Đang hoạt động' : 'Đã vô hiệu hóa',
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.green[900] : Colors.red[900],
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            isActive ? Icons.block : Icons.check_circle,
            color: isActive ? Colors.red : Colors.green,
          ),
          onPressed: onToggleActive,
          tooltip: isActive ? 'Vô hiệu hóa' : 'Kích hoạt',
        ),
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Quản trị viên';
      case 'owner':
        return 'Chủ shop';
      case 'user':
        return 'Người dùng';
      default:
        return role;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
