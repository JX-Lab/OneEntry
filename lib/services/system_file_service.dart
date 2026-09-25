import 'dart:typed_data';

import 'package:flutter/services.dart';

class PickedDocument {
  const PickedDocument({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

class SystemFileService {
  SystemFileService._();

  static const MethodChannel _channel = MethodChannel('com.junxu.yibi/files');

  static Future<PickedDocument?> open({required List<String> mimeTypes}) async {
    final Map<Object?, Object?>? result = await _channel
        .invokeMapMethod<Object?, Object?>('openFile', <String, Object?>{
          'mimeTypes': mimeTypes,
        });
    if (result == null) return null;
    return PickedDocument(
      name: result['name'] as String? ?? 'import-file',
      bytes: result['bytes'] as Uint8List,
    );
  }

  static Future<bool> save({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    return await _channel.invokeMethod<bool>('saveFile', <String, Object?>{
          'name': name,
          'mimeType': mimeType,
          'bytes': bytes,
        }) ??
        false;
  }
}
