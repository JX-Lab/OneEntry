import 'package:flutter/services.dart';

class DailyReminderStatus {
  const DailyReminderStatus({
    this.nextAt,
    this.lastTriggeredAt,
    this.lastShownAt,
  });

  final DateTime? nextAt;
  final DateTime? lastTriggeredAt;
  final DateTime? lastShownAt;
}

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

  static Future<bool> canScheduleExactAlarms() async {
    return await _channel.invokeMethod<bool>('canScheduleExactAlarms') ?? false;
  }

  static Future<DailyReminderStatus> dailyReminderStatus() async {
    final Map<Object?, Object?>? value = await _channel
        .invokeMapMethod<Object?, Object?>('dailyReminderStatus');
    DateTime? date(Object? milliseconds) {
      final int raw = (milliseconds as num?)?.toInt() ?? 0;
      return raw <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(raw);
    }

    return DailyReminderStatus(
      nextAt: date(value?['nextAt']),
      lastTriggeredAt: date(value?['lastTriggeredAt']),
      lastShownAt: date(value?['lastShownAt']),
    );
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

  static Future<bool> showTestNotification() async {
    return await _channel.invokeMethod<bool>('showTestNotification') ?? false;
  }

  static Future<void> openSettings() async {
    await _channel.invokeMethod<void>('openNotificationSettings');
  }

  static Future<void> openExactAlarmSettings() async {
    await _channel.invokeMethod<void>('openExactAlarmSettings');
  }
}
