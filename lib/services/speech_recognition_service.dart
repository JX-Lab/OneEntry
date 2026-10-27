import 'dart:async';

import 'package:flutter/services.dart';

enum SpeechRecognitionStatus { idle, listening, processing, result, error }

class SpeechRecognitionEvent {
  const SpeechRecognitionEvent(this.status, {this.text, this.message});

  final SpeechRecognitionStatus status;
  final String? text;
  final String? message;
}

class SpeechRecognitionService {
  SpeechRecognitionService._();

  static const MethodChannel _channel = MethodChannel('com.junxu.yibi/speech');
  static final StreamController<SpeechRecognitionEvent> _events =
      StreamController<SpeechRecognitionEvent>.broadcast();
  static bool _initialized = false;

  static Stream<SpeechRecognitionEvent> get events => _events.stream;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((MethodCall call) async {
      final Map<Object?, Object?> arguments =
          call.arguments as Map<Object?, Object?>? ?? <Object?, Object?>{};
      switch (call.method) {
        case 'speechEvent':
          final String status = '${arguments['status'] ?? ''}';
          _events.add(
            SpeechRecognitionEvent(
              switch (status) {
                'listening' => SpeechRecognitionStatus.listening,
                'processing' => SpeechRecognitionStatus.processing,
                'result' => SpeechRecognitionStatus.result,
                'error' => SpeechRecognitionStatus.error,
                _ => SpeechRecognitionStatus.idle,
              },
              text: arguments['text'] as String?,
              message: arguments['message'] as String?,
            ),
          );
      }
    });
  }

  static Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  static Future<bool> isAvailable() async =>
      await _channel.invokeMethod<bool>('isAvailable') ?? false;

  static Future<bool> start() async =>
      await _channel.invokeMethod<bool>('start') ?? false;

  static Future<void> stop() => _channel.invokeMethod<void>('stop');

  static Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}
