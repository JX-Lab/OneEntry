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

  static Future<bool> notificationsEnabled() async {
    return await _channel.invokeMethod<bool>('notificationsEnabled') ?? false;
  }

  static Future<void> scheduleRecurringCheck() async {
    await _channel.invokeMethod<void>('scheduleRecurringCheck');
  }

  static Future<void> openSettings() async {
    await _channel.invokeMethod<void>('openNotificationSettings');
  }
}
