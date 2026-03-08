import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../common/providers/product_provider.dart';

class FilterDialog extends StatefulWidget {
  final Function(Map<String, dynamic> filters) onApply;

  const FilterDialog({
    Key? key,
    required this.onApply,
  }) : super(key: key);

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late double _minPrice;
  late double _maxPrice;
  late bool _inStockOnly;
  late String _sortBy;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ProductProvider>();
    _minPrice = provider.minPrice;
    _maxPrice = provider.maxPrice;
    _inStockOnly = provider.inStockOnly;
    _sortBy = provider.sortBy;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bộ lọc sản phẩm',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),

              // Price Range Filter
              Text(
                'Khoảng giá',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      initialValue: _minPrice.toStringAsFixed(0),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Tối thiểu',
                        prefixText: '₫ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          _minPrice = double.tryParse(value) ?? 0;
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      initialValue: _maxPrice.toStringAsFixed(0),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Tối đa',
                        prefixText: '₫ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          _maxPrice = double.tryParse(value) ?? 999999;
                        }
                      },
                    ),
                  ),
                ],
              ),

              // Slider for visual price range
              Slider(
                min: 0,
                max: 999999,
                divisions: 100,
                onChanged: (value) {
                  setState(() {
                    _maxPrice = value;
                  });
                },
                value: _maxPrice,
                label: '₫ ${_maxPrice.toStringAsFixed(0)}',
              ),

              const SizedBox(height: 24),

              // In Stock Only Filter
              CheckboxListTile(
                title: const Text('Chỉ hiển thị hàng còn stock'),
                subtitle: const Text('Bỏ qua các sản phẩm đã hết'),
                value: _inStockOnly,
                onChanged: (value) {
                  setState(() {
                    _inStockOnly = value ?? false;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 24),

              // Sort By Filter
              Text(
                'Sắp xếp theo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  _buildSortOption('newest', 'Mới nhất'),
                  _buildSortOption('price-asc', 'Giá: Thấp đến Cao'),
                  _buildSortOption('price-desc', 'Giá: Cao đến Thấp'),
                  _buildSortOption('rating', 'Xếp hạng cao nhất'),
                ],
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Reset to defaults
                        setState(() {
                          _minPrice = 0;
                          _maxPrice = 999999;
                          _inStockOnly = false;
                          _sortBy = 'newest';
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Đặt lại'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onApply({
                          'minPrice': _minPrice,
                          'maxPrice': _maxPrice,
                          'inStockOnly': _inStockOnly,
                          'sortBy': _sortBy,
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Áp dụng'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(String value, String label) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: _sortBy,
      onChanged: (newValue) {
        if (newValue != null) {
          setState(() {
            _sortBy = newValue;
          });
        }
      },
      contentPadding: EdgeInsets.zero,
    );
  }
}
