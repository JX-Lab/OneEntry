import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/services/notification_service.dart';
import 'package:yibi/services/speech_recognition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel notifications = MethodChannel(
    'com.junxu.yibi/notifications',
  );
  const MethodChannel speech = MethodChannel('com.junxu.yibi/speech');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(speech, null);
  });

  test('每日提醒会把开关和时间传给 Android', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, (MethodCall call) async {
          received = call;
          return null;
        });

    await NotificationService.scheduleDaily(
      enabled: true,
      hour: 20,
      minute: 15,
    );

    expect(received?.method, 'scheduleDaily');
    expect(received?.arguments, <String, Object?>{
      'enabled': true,
      'hour': 20,
      'minute': 15,
    });
  });

  test('权限服务可查询通知和麦克风状态', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, (MethodCall call) async {
          if (call.method == 'notificationsEnabled') return true;
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(speech, (MethodCall call) async {
          if (call.method == 'hasPermission') return true;
          return null;
        });

    expect(await NotificationService.notificationsEnabled(), isTrue);
    expect(await SpeechRecognitionService.hasPermission(), isTrue);
  });
}
