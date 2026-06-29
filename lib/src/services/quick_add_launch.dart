import 'package:flutter/services.dart';

/// Bridges the home-screen widget tap to the Flutter app: reports whether the
/// app was launched for quick-add (cold start) and pushes a request when the
/// widget is tapped while the app is already running (warm start).
class QuickAddLaunch {
  const QuickAddLaunch();

  static const MethodChannel _channel =
      MethodChannel('de.clausen.todo_md_app/widget');

  /// Returns the pending launch action ("quick_add") once, then clears it.
  Future<String?> getLaunchAction() =>
      _channel.invokeMethod<String>('getLaunchAction');

  /// Registers [onQuickAdd], invoked when the widget is tapped while running.
  void setQuickAddHandler(void Function() onQuickAdd) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'quickAdd') onQuickAdd();
      return null;
    });
  }
}
