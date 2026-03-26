import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

ImageProvider<Object> buildImageProvider(String source) {
  final value = source.trim();
  if (value.startsWith('data:image/')) {
    final bytes = _decodeDataUri(value);
    if (bytes != null) {
      return MemoryImage(bytes);
    }
  }
  return NetworkImage(value);
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
