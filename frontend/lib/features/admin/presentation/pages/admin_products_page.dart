import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../common/providers/admin_provider.dart';
import '../../../../common/providers/product_provider.dart';
import '../../../../common/models/product_model.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  String _searchQuery = '';
  String? _selectedCategory;
  bool _showActiveOnly = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<ProductProvider>().fetchProducts();
      context.read<AdminProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Sản phẩm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ProductProvider>().fetchProducts();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Thêm sản phẩm'),
      ),
      body: Consumer2<ProductProvider, AdminProvider>(
        builder: (context, productProvider, adminProvider, _) {
          if (productProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (productProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(productProvider.error ?? 'Lỗi không xác định'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => productProvider.fetchProducts(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          // Filter products
          final filteredProducts = productProvider.products.where((product) {
            if (_showActiveOnly && !(product.isActive ?? true)) {
              return false;
            }
            if (_selectedCategory != null &&
                _selectedCategory!.isNotEmpty &&
                product.category != _selectedCategory) {
              return false;
            }
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              return product.name.toLowerCase().contains(query) ||
                  (product.description?.toLowerCase().contains(query) ?? false);
            }
            return true;
          }).toList();

          return Column(
            children: [
              // Filter Section
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm sản phẩm...',
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
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Danh mục',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Tất cả'),
                              ),
                              ...adminProvider.categories.map((cat) {
                                final name = cat['Name'] ?? cat['name'] ?? '';
                                return DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilterChip(
                          label: const Text('Chỉ hiển thị đang bán'),
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
                      label: 'Tổng SP',
                      value: '${productProvider.products.length}',
                      color: Colors.blue,
                    ),
                    _StatChip(
                      label: 'Đang bán',
                      value: '${productProvider.products.where((p) => p.isActive ?? true).length}',
                      color: Colors.green,
                    ),
                    _StatChip(
                      label: 'Kết quả',
                      value: '${filteredProducts.length}',
                      color: Colors.orange,
                    ),
                  ],
                ),
              ),

              // Products List
              Expanded(
                child: filteredProducts.isEmpty
                    ? const Center(
                        child: Text('Không tìm thấy sản phẩm'),
                      )
                    : ListView.builder(
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return _ProductCard(
                            product: product,
                            onEdit: () => _showProductDialog(context, product),
                            onDelete: () => _confirmDelete(context, product),
                            onToggleActive: () => _toggleProductActive(product),
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

  Future<void> _showProductDialog(BuildContext context, Product? product) async {
    final nameController = TextEditingController(text: product?.name ?? '');
    final priceController = TextEditingController(
      text: product?.price.toString() ?? '',
    );
    final stockController = TextEditingController(
      text: product?.stock.toString() ?? '',
    );
    final descController = TextEditingController(
      text: product?.description ?? '',
    );
    final discountController = TextEditingController(
      text: product?.discountPercent?.toString() ?? '0',
    );

    String? selectedCategory = product?.category;
    final adminProvider = context.read<AdminProvider>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(product == null ? 'Thêm Sản phẩm' : 'Sửa Sản phẩm'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tên sản phẩm *'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Danh mục *'),
                      items: adminProvider.categories.map((cat) {
                        final name = cat['Name'] ?? cat['name'] ?? '';
                        return DropdownMenuItem(
                          value: name,
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Giá *'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockController,
                      decoration: const InputDecoration(labelText: 'Số lượng *'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: discountController,
                      decoration: const InputDecoration(labelText: 'Giảm giá (%)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final price = double.tryParse(priceController.text.trim()) ?? 0;
                    final stock = int.tryParse(stockController.text.trim()) ?? 0;
                    final desc = descController.text.trim();
                    final discount =
                        double.tryParse(discountController.text.trim()) ?? 0;

                    if (name.isEmpty || selectedCategory == null || price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng điền đầy đủ thông tin'),
                        ),
                      );
                      return;
                    }

                    // TODO: Call API to create/update product
                    // For now, just close dialog
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            product == null
                                ? 'Thêm sản phẩm thành công'
                                : 'Cập nhật sản phẩm thành công',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(product == null ? 'Thêm' : 'Cập nhật'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa sản phẩm "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Call delete API
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa sản phẩm')),
        );
      }
    }
  }

  Future<void> _toggleProductActive(Product product) async {
    // TODO: Call API to toggle product active status
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (product.isActive ?? true)
              ? 'Đã ẩn sản phẩm'
              : 'Đã hiển thị sản phẩm',
        ),
      ),
    );
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

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = product.isActive ?? true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: product.imageUrls.isNotEmpty
            ? Image.network(
                product.imageUrls.first,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported),
                ),
              )
            : Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: const Icon(Icons.shopping_bag),
              ),
        title: Text(
          product.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Danh mục: ${product.category}'),
            Text(
              'Giá: \$${product.price.toStringAsFixed(2)} ${product.discountPercent != null && product.discountPercent! > 0 ? "(-${product.discountPercent}%)" : ""}',
            ),
            Text('Kho: ${product.stock}'),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.green[100] : Colors.red[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? 'Đang bán' : 'Đã ẩn',
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.green[900] : Colors.red[900],
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Sửa'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(isActive ? Icons.visibility_off : Icons.visibility,
                      size: 20),
                  const SizedBox(width: 8),
                  Text(isActive ? 'Ẩn' : 'Hiển thị'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Xóa', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
                break;
              case 'toggle':
                onToggleActive();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
        ),
      ),
    );
  }
}
