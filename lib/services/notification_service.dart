import 'dart:async';

import 'package:flutter/services.dart';

class NotificationLaunchAction {
  const NotificationLaunchAction({required this.type, this.recurringRuleId});

  final String type;
  final int? recurringRuleId;
}

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
  static final StreamController<NotificationLaunchAction> _launchEvents =
      StreamController<NotificationLaunchAction>.broadcast();
  static bool _initialized = false;

  static Stream<NotificationLaunchAction> get launchEvents =>
      _launchEvents.stream;

  static Future<void> initialize() async {
    if (!_initialized) {
      _initialized = true;
      _channel.setMethodCallHandler((MethodCall call) async {
        if (call.method != 'notificationLaunch') return;
        final NotificationLaunchAction? action = _launchAction(call.arguments);
        if (action != null) _launchEvents.add(action);
      });
    }
    await _channel.invokeMethod<void>('initialize');
  }

  static Future<NotificationLaunchAction?> takeLaunchAction() async {
    final Map<Object?, Object?>? value = await _channel
        .invokeMapMethod<Object?, Object?>('takeLaunchAction');
    return _launchAction(value);
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

  static NotificationLaunchAction? _launchAction(Object? raw) {
    if (raw is! Map) return null;
    final Map<Object?, Object?> value = Map<Object?, Object?>.from(raw);
    final String type = '${value['type'] ?? ''}';
    if (type.isEmpty) return null;
    return NotificationLaunchAction(
      type: type,
      recurringRuleId: (value['recurringRuleId'] as num?)?.toInt(),
    );
  }
}
