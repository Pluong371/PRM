import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/smart_image.dart';

class ManageProductsScreen extends StatelessWidget {
  const ManageProductsScreen({super.key});

  List<String> _parseImageSources(String raw) {
    return raw
        .split(RegExp(r'[\n,;]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  String _generateGuid() {
    final now = DateTime.now();
    final raw = (now.microsecondsSinceEpoch.toRadixString(16) +
            now.millisecondsSinceEpoch.toRadixString(16))
        .padRight(32, '0')
        .substring(0, 32);
    return '${raw.substring(0, 8)}-${raw.substring(8, 12)}-${raw.substring(12, 16)}-${raw.substring(16, 20)}-${raw.substring(20, 32)}';
  }

  Color _parseColorHex(String raw) {
    final hex = raw.trim().replaceAll('#', '').toUpperCase();
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return Colors.black;
  }

  String _toHex(Color color) {
    final value = color.value.toRadixString(16).toUpperCase().padLeft(8, '0');
    return '#${value.substring(2)}';
  }

  void _openProductForm(BuildContext context, {Product? editing}) {
    final picker = ImagePicker();

    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final categoryCtrl =
        TextEditingController(text: editing?.category ?? 'Men');
    final priceCtrl = TextEditingController(
      text: editing != null ? editing.price.toStringAsFixed(0) : '',
    );
    final descriptionCtrl = TextEditingController(
      text: editing?.description ?? '',
    );

    final coverImageCtrl = TextEditingController(
      text: editing != null && editing.imageUrls.isNotEmpty
          ? editing.imageUrls.first
          : '',
    );
    final extraImagesCtrl = TextEditingController(
      text: editing != null && editing.imageUrls.length > 1
          ? editing.imageUrls.skip(1).join('\n')
          : '',
    );

    final sizeDrafts = <Map<String, TextEditingController>>[];
    final sourceSizes = editing != null && editing.sizeStocks.isNotEmpty
        ? editing.sizeStocks.keys.toList()
        : editing != null && editing.sizes.isNotEmpty
            ? editing.sizes
            : const ['S', 'M', 'L', 'XL'];
    final eachStock =
        sourceSizes.isEmpty ? 0 : (editing?.stock ?? 0) ~/ sourceSizes.length;
    var usedStock = 0;

    for (var i = 0; i < sourceSizes.length; i += 1) {
      final isLast = i == sourceSizes.length - 1;
      final stockValue = editing == null
          ? (sourceSizes[i] == 'M' ? 10 : 0)
          : (editing.sizeStocks[sourceSizes[i]] ??
              (isLast
                  ? (editing.stock - usedStock).clamp(0, 999999)
                  : eachStock));
      usedStock += stockValue;
      sizeDrafts.add({
        'size': TextEditingController(text: sourceSizes[i]),
        'stock': TextEditingController(text: stockValue.toString()),
      });
    }

    final colorDrafts = <Map<String, TextEditingController>>[];
    if (editing != null && editing.colorImageMap.isNotEmpty) {
      for (final entry in editing.colorImageMap.entries) {
        colorDrafts.add({
          'hex': TextEditingController(text: entry.key),
          'images': TextEditingController(
            text: entry.value.join('\n'),
          ),
        });
      }
    } else if (editing != null && editing.colors.isNotEmpty) {
      for (var i = 0; i < editing.colors.length; i += 1) {
        colorDrafts.add({
          'hex': TextEditingController(text: _toHex(editing.colors[i])),
          'images': TextEditingController(
              text: i == 0 ? editing.imageUrls.join('\n') : ''),
        });
      }
    } else {
      colorDrafts.add({
        'hex': TextEditingController(text: '#000000'),
        'images': TextEditingController(text: ''),
      });
    }

    String previewImage() {
      final cover = coverImageCtrl.text.trim();
      if (cover.isNotEmpty) return cover;

      final extras = _parseImageSources(extraImagesCtrl.text);
      if (extras.isNotEmpty) return extras.first;

      for (final draft in colorDrafts) {
        final colorImages = _parseImageSources(draft['images']!.text);
        if (colorImages.isNotEmpty) return colorImages.first;
      }

      return 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=800';
    }

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    editing == null ? 'Add Product' : 'Edit Product',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SmartImage(
                      source: previewImage(),
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Product name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: categoryCtrl,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Price'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Product Images',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: coverImageCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Cover image URL / local path',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 85,
                        );
                        if (picked == null) return;
                        coverImageCtrl.text = picked.path;
                        setState(() {});
                      },
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Upload cover image'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: extraImagesCtrl,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'More images (one line each)',
                      hintText: 'Paste URL or local path, each line one image',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final pickedList = await picker.pickMultiImage(
                          imageQuality: 85,
                        );
                        if (pickedList.isEmpty) return;
                        final merged = [
                          ..._parseImageSources(extraImagesCtrl.text),
                          ...pickedList.map((item) => item.path),
                        ];
                        extraImagesCtrl.text = merged.join('\n');
                        setState(() {});
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Upload more images'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Sizes & Stock',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(sizeDrafts.length, (index) {
                    final sizeCtrl = sizeDrafts[index]['size']!;
                    final sizeStockCtrl = sizeDrafts[index]['stock']!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: sizeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Size',
                                hintText: 'S / M / L / XL',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: sizeStockCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Stock',
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: sizeDrafts.length <= 1
                                ? null
                                : () {
                                    sizeDrafts.removeAt(index);
                                    setState(() {});
                                  },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
                    );
                  }),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        sizeDrafts.add({
                          'size': TextEditingController(text: ''),
                          'stock': TextEditingController(text: '0'),
                        });
                        setState(() {});
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add size'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Color Variants (each color can have many images)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(colorDrafts.length, (index) {
                    final hexCtrl = colorDrafts[index]['hex']!;
                    final imagesCtrl = colorDrafts[index]['images']!;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: hexCtrl,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Color hex',
                                      hintText: '#000000',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: _parseColorHex(hexCtrl.text),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black12),
                                  ),
                                ),
                                IconButton(
                                  onPressed: colorDrafts.length <= 1
                                      ? null
                                      : () {
                                          colorDrafts.removeAt(index);
                                          setState(() {});
                                        },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: imagesCtrl,
                              minLines: 2,
                              maxLines: 4,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Images of this color',
                                hintText: 'One line one image URL/path',
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await picker.pickMultiImage(
                                    imageQuality: 85,
                                  );
                                  if (picked.isEmpty) return;
                                  imagesCtrl.text = [
                                    ..._parseImageSources(imagesCtrl.text),
                                    ...picked.map((item) => item.path),
                                  ].join('\n');
                                  setState(() {});
                                },
                                icon: const Icon(Icons.photo_library_outlined),
                                label:
                                    const Text('Upload images for this color'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        colorDrafts.add({
                          'hex': TextEditingController(text: '#000000'),
                          'images': TextEditingController(text: ''),
                        });
                        setState(() {});
                      },
                      icon: const Icon(Icons.palette_outlined),
                      label: const Text('Add color variant'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final provider = context.read<ProductProvider>();
                        final currentUser =
                            context.read<AuthProvider>().currentUser;
                        final ownerId = currentUser != null &&
                                currentUser.role == UserRole.owner
                            ? currentUser.id
                            : editing?.ownerId;

                        final sizes = <String>[];
                        final sizeStocks = <String, int>{};
                        var totalStock = 0;
                        for (final draft in sizeDrafts) {
                          final size = draft['size']!.text.trim().toUpperCase();
                          if (size.isEmpty) continue;
                          final stock = int.tryParse(draft['stock']!.text) ?? 0;
                          sizes.add(size);
                          sizeStocks[size] = stock;
                          if (stock > 0) totalStock += stock;
                        }

                        final colors = <Color>[];
                        final colorImageMap = <String, List<String>>{};
                        final allImages = <String>[
                          ..._parseImageSources(coverImageCtrl.text),
                          ..._parseImageSources(extraImagesCtrl.text),
                        ];

                        for (final draft in colorDrafts) {
                          final normalizedHex =
                              draft['hex']!.text.trim().toUpperCase();
                          final safeHex = normalizedHex.startsWith('#')
                              ? normalizedHex
                              : '#$normalizedHex';
                          final colorImages =
                              _parseImageSources(draft['images']!.text);

                          colors.add(_parseColorHex(safeHex));
                          colorImageMap[safeHex] = colorImages;
                          allImages.addAll(colorImages);
                        }

                        final uniqueImages = allImages
                            .map((value) => value.trim())
                            .where((value) => value.isNotEmpty)
                            .toSet()
                            .toList();

                        final product = Product(
                          id: editing?.id ?? _generateGuid(),
                          ownerId: ownerId,
                          name: nameCtrl.text.trim(),
                          price: double.tryParse(priceCtrl.text) ?? 0,
                          category: categoryCtrl.text.trim().isEmpty
                              ? 'Men'
                              : categoryCtrl.text.trim(),
                          description: descriptionCtrl.text.trim().isEmpty
                              ? 'New product description'
                              : descriptionCtrl.text.trim(),
                          stock: totalStock,
                          imageUrls: uniqueImages.isEmpty
                              ? [
                                  'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=800',
                                ]
                              : uniqueImages,
                          sizes: sizes.isEmpty ? const ['M'] : sizes,
                          colors:
                              colors.isEmpty ? const [Colors.black] : colors,
                          sizeStocks: sizeStocks,
                          colorImageMap: colorImageMap,
                          reviewsCount: editing?.reviewsCount ?? 0,
                          discountPercent: editing?.discountPercent,
                        );

                        if (product.name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter product name'),
                            ),
                          );
                          return;
                        }

                        if (editing == null) {
                          provider.addProduct(product);
                        } else {
                          provider.updateProduct(product);
                        }

                        Navigator.pop(context);
                      },
                      child: Text(
                        editing == null ? 'Add product' : 'Save changes',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().products;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openProductForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];

                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: CircleAvatar(
                      child: ClipOval(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: SmartImage(
                            source: product.imageUrls.first,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    title: Text(product.name),
                    subtitle: Text(
                      '${formatCurrency(product.price)} • Còn lại: ${product.stock}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () =>
                              _openProductForm(context, editing: product),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => context
                              .read<ProductProvider>()
                              .deleteProduct(product.id),
                          icon: const Icon(Icons.delete_outline),
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
