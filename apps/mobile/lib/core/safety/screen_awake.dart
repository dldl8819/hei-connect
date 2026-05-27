import 'package:flutter/services.dart';

class ScreenAwake {
  static const MethodChannel _channel = MethodChannel(
    'connect.dev/screen_awake',
  );

  Future<void> keepAwake() async {
    try {
      await _channel.invokeMethod<void>('keepAwake');
    } on MissingPluginException {
      // Platforms without a native implementation can still run the app.
    } on PlatformException {
      // Screen wake is a safety aid, but media shutdown should never be blocked.
    }
  }

  Future<void> allowSleep() async {
    try {
      await _channel.invokeMethod<void>('allowSleep');
    } on MissingPluginException {
      // Platforms without a native implementation can still run the app.
    } on PlatformException {
      // Ignore cleanup failures.
    }
  }
}
