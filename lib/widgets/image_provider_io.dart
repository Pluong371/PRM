import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

ImageProvider<Object> buildImageProvider(String source) {
  final value = source.trim();
  if (value.isEmpty) {
    return const NetworkImage(
      'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=800',
    );
  }
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return NetworkImage(value);
  }
  if (value.startsWith('data:image/')) {
    final bytes = _decodeDataUri(value);
    if (bytes != null) {
      return MemoryImage(bytes);
    }
  }

  final normalized =
      value.startsWith('file://') ? Uri.parse(value).toFilePath() : value;
  return FileImage(File(normalized));
}

Uint8List? _decodeDataUri(String dataUri) {
  final commaIndex = dataUri.indexOf(',');
  if (commaIndex == -1 || commaIndex == dataUri.length - 1) return null;
  final encoded = dataUri.substring(commaIndex + 1);
  try {
    return base64Decode(encoded);
  } catch (_) {
    return null;
  }
}
