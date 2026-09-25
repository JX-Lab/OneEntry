import 'package:flutter/services.dart';

class NotificationService {
  NotificationService._();

  static const MethodChannel _channel = MethodChannel(
    'com.junxu.yibi/notifications',
  );

  static Future<void> initialize() async {
    await _channel.invokeMethod<void>('initialize');
  }

  static Future<bool> requestPermission() async {
    return await _channel.invokeMethod<bool>('requestPermission') ?? false;
  }

  static Future<void> scheduleDaily({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await _channel.invokeMethod<void>('scheduleDaily', <String, Object?>{
      'enabled': enabled,
      'hour': hour,
      'minute': minute,
    });
  }

  static Future<void> scheduleRecurringCheck() async {
    await _channel.invokeMethod<void>('scheduleRecurringCheck');
  }
}
