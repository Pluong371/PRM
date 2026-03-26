import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/smart_image.dart';

class TryOnScreen extends StatefulWidget {
  const TryOnScreen({super.key});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  static const String _sampleModelFolderPath =
      r'D:\PRM393\BanHang\backend\molde';
  static const List<String> _sampleModels = [
    r'1hang.png',
    r'2hang.png',
    r'3hang.png',
    r'4hang.png',
    r'6hang.png',
  ];

  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  bool _isRunning = false;
  String _modelMode = 'sample';
  String _selectedSampleModel = _sampleModelFolderPath + r'\1hang.png';
  XFile? _pickedModelFile;
  final Set<String> _selectedProductIds = <String>{};
  final List<XFile> _localGarmentFiles = <XFile>[];
  final Set<String> _downloadingResultKeys = <String>{};
  TryOnBatchResponse? _result;
  String? _error;

  String get _backendBaseUrl {
    if (kIsWeb) return 'http://localhost:3000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  String _sampleModelPath(String fileName) {
    return '$_sampleModelFolderPath\\$fileName';
  }

  String _sampleModelPreviewUrl(String fileName) {
    return '$_backendBaseUrl/model-images/$fileName';
  }

  Future<void> _pickModelImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;
    setState(() {
      _pickedModelFile = picked;
      _modelMode = 'self';
    });
  }

  Future<void> _pickLocalGarments() async {
    final picked = await _picker.pickMultiImage(imageQuality: 90);
    if (picked.isEmpty) return;
    setState(() {
      _localGarmentFiles
        ..clear()
        ..addAll(picked);
    });
  }

  String _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _dataUriFromBytes(Uint8List bytes, String mimeType) {
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  Future<String> _normalizeImageInput({
    required String source,
    XFile? pickedFile,
  }) async {
    final value = source.trim();
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('data:image/')) {
      return value;
    }

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      return _dataUriFromBytes(bytes, _mimeFromPath(pickedFile.path));
    }

    return value;
  }

  String _safeFileName(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Future<Uint8List> _loadImageBytesForDownload(String source) async {
    final value = source.trim();
    if (value.startsWith('data:image/')) {
      final commaIndex = value.indexOf(',');
      if (commaIndex == -1) {
        throw Exception('Ảnh base64 không hợp lệ.');
      }
      return base64Decode(value.substring(commaIndex + 1));
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      final response =
          await http.get(Uri.parse(value)).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        throw Exception(
            'Không tải được ảnh từ server (${response.statusCode}).');
      }
      return response.bodyBytes;
    }

    throw Exception('Định dạng ảnh không hỗ trợ tải xuống.');
  }

  Future<void> _downloadOutputImage({
    required String source,
    required String key,
    required String name,
  }) async {
    if (_downloadingResultKeys.contains(key)) return;

    setState(() => _downloadingResultKeys.add(key));

    try {
      if (kIsWeb) {
        throw Exception(
          'Web chưa hỗ trợ lưu file cục bộ trong app này. Hãy dùng Android/Windows.',
        );
      }

      final bytes = await _loadImageBytesForDownload(source);
      final fileName =
          'tryon_${_safeFileName(name)}_${DateTime.now().millisecondsSinceEpoch}';
      final baseDirectory = defaultTargetPlatform == TargetPlatform.android
          ? await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory()
          : await getApplicationDocumentsDirectory();
      final outputDirectory =
          Directory('${baseDirectory.path}/tryon_downloads');
      if (!await outputDirectory.exists()) {
        await outputDirectory.create(recursive: true);
      }
      final outputFile = File('${outputDirectory.path}/$fileName.jpg');
      await outputFile.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã lưu ảnh: ${outputFile.path}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tải ảnh thất bại: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _downloadingResultKeys.remove(key));
      }
    }
  }

  Future<void> _runTryOn(List<Product> products) async {
    final fromShop = products
        .where((product) => _selectedProductIds.contains(product.id))
        .toList();

    if (_modelMode == 'self' && _pickedModelFile == null) {
      setState(() => _error = 'Vui lòng chọn ảnh bản thân.');
      return;
    }

    if (fromShop.isEmpty && _localGarmentFiles.isEmpty) {
      setState(() => _error = 'Hãy chọn ít nhất 1 sản phẩm để thử.');
      return;
    }

    setState(() {
      _isRunning = true;
      _error = null;
      _result = null;
    });

    try {
      final modelInput = await _normalizeImageInput(
        source: _modelMode == 'sample'
            ? _selectedSampleModel
            : (_pickedModelFile?.path ?? ''),
        pickedFile: _modelMode == 'self' ? _pickedModelFile : null,
      );

      final garmentInputs = <TryOnGarmentInput>[];

      for (final product in fromShop) {
        final source =
            product.imageUrls.isNotEmpty ? product.imageUrls.first : '';
        if (source.trim().isEmpty) continue;
        garmentInputs.add(
          TryOnGarmentInput(
            productId: product.id,
            garmentName: product.name,
            garmentImage: await _normalizeImageInput(source: source),
          ),
        );
      }

      for (var i = 0; i < _localGarmentFiles.length; i += 1) {
        final file = _localGarmentFiles[i];
        garmentInputs.add(
          TryOnGarmentInput(
            garmentName: 'Ảnh máy #${i + 1}',
            garmentImage: await _normalizeImageInput(
              source: file.path,
              pickedFile: file,
            ),
          ),
        );
      }

      if (garmentInputs.isEmpty) {
        throw Exception('Không có ảnh quần áo hợp lệ để gửi lên API.');
      }

      final response = await _apiService.tryOnBatch(
        modelImage: modelInput,
        garments: garmentInputs,
      );

      if (!mounted) return;
      setState(() => _result = response);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isRunning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().products;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Virtual Try-On',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1) Chọn ảnh người mặc',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'sample', label: Text('Mẫu có sẵn')),
                      ButtonSegment(value: 'self', label: Text('Ảnh bản thân')),
                    ],
                    selected: {_modelMode},
                    onSelectionChanged: (value) {
                      setState(() => _modelMode = value.first);
                    },
                  ),
                  const SizedBox(height: 10),
                  if (_modelMode == 'sample')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xem trước mẫu toàn thân (từ chân đến đầu)',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 300,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SmartImage(
                            source: _sampleModelPreviewUrl(
                              _selectedSampleModel.replaceFirst(
                                  '$_sampleModelFolderPath\\', ''),
                            ),
                            fit: BoxFit.contain,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 132,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _sampleModels.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final fileName = _sampleModels[index];
                              final source = _sampleModelPath(fileName);
                              final selected = source == _selectedSampleModel;
                              return GestureDetector(
                                onTap: () => setState(
                                    () => _selectedSampleModel = source),
                                child: Container(
                                  width: 100,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: SmartImage(
                                    source: _sampleModelPreviewUrl(fileName),
                                    fit: BoxFit.contain,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickModelImage,
                        icon: const Icon(Icons.person_2_outlined),
                        label: const Text('Chọn ảnh bản thân'),
                      ),
                    ),
                    if (_pickedModelFile != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          width: double.infinity,
                          height: 300,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SmartImage(
                            source: _pickedModelFile!.path,
                            fit: BoxFit.contain,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2) Chọn quần áo từ shop',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Chưa có sản phẩm nào.'),
                    )
                  else
                    ...products.map((product) {
                      final source = product.imageUrls.isNotEmpty
                          ? product.imageUrls.first
                          : '';
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _selectedProductIds.contains(product.id),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedProductIds.add(product.id);
                            } else {
                              _selectedProductIds.remove(product.id);
                            }
                          });
                        },
                        title: Text(product.name),
                        subtitle: Text(product.category),
                        secondary: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: SmartImage(source: source),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3) Hoặc chọn ảnh quần áo trong máy',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickLocalGarments,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Chọn nhiều ảnh từ máy'),
                    ),
                  ),
                  if (_localGarmentFiles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            List.generate(_localGarmentFiles.length, (index) {
                          final file = _localGarmentFiles[index];
                          return Chip(
                            label: Text('Ảnh #${index + 1}'),
                            onDeleted: () {
                              setState(() => _localGarmentFiles.remove(file));
                            },
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _isRunning ? null : () => _runTryOn(products),
            icon: _isRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_isRunning ? 'Đang xử lý...' : 'Thử đồ ngay'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            Text(
              'Kết quả: ${_result!.successCount}/${_result!.total} thành công',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._result!.results.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final resultKey =
                  '${item.productId ?? item.garmentName ?? 'result'}_$index';
              final isDownloading = _downloadingResultKeys.contains(resultKey);
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.garmentName ?? 'Sản phẩm',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      if (item.isSuccess && item.outputImage != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 360,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SmartImage(
                                source: item.outputImage!,
                                fit: BoxFit.contain,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: isDownloading
                                    ? null
                                    : () => _downloadOutputImage(
                                          source: item.outputImage!,
                                          key: resultKey,
                                          name: item.garmentName ?? 'tryon',
                                        ),
                                icon: isDownloading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.download_outlined),
                                label: Text(
                                    isDownloading ? 'Đang tải...' : 'Tải ảnh'),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          item.error ?? 'Try-on thất bại',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
