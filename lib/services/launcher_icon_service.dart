import 'package:flutter/services.dart';

abstract final class LauncherIconService {
  static const MethodChannel _channel = MethodChannel(
    'com.junxu.yibi/launcher_icon',
  );

  static Future<String> currentMode() async {
    try {
      return await _channel.invokeMethod<String>('getMode') ?? 'brand';
    } on MissingPluginException {
      return 'brand';
    } on PlatformException {
      return 'brand';
    }
  }

  static Future<bool> setMode({
    required String mode,
    required String themeKey,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('setMode', <String, String>{
            'mode': mode,
            'themeKey': themeKey,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> syncTheme(String themeKey) async {
    try {
      await _channel.invokeMethod<void>('syncTheme', <String, String>{
        'themeKey': themeKey,
      });
    } on MissingPluginException {
      // Launcher icon switching is Android-only.
    } on PlatformException {
      // Some launchers delay or reject component changes; the UI theme still works.
    }
  }
}
