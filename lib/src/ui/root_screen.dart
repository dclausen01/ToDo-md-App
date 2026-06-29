import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/board_provider.dart';
import '../providers/settings_provider.dart';
import '../services/quick_add_launch.dart';
import 'home_screen.dart';
import 'quick_add.dart';

/// App root. Shows the board, and routes home-screen-widget taps into the
/// quick-add sheet (both on cold start and while already running).
class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> {
  static const _launch = QuickAddLaunch();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Warm start: widget tapped while the app is already running.
    _launch.setQuickAddHandler(() => _handleQuickAdd(closeAppOnDone: false));
    // Cold start: app launched by the widget.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final action = await _launch.getLaunchAction();
      if (action == 'quick_add') {
        _handleQuickAdd(closeAppOnDone: true);
      }
    });
  }

  Future<void> _handleQuickAdd({required bool closeAppOnDone}) async {
    if (_busy) return;
    _busy = true;
    try {
      final settings = await ref.read(settingsProvider.future);
      if (!settings.isConfigured) return; // app just opens normally
      final session = await ref.read(boardProvider.future);
      if (session == null || !mounted) return;
      await showQuickAddFlow(context, ref, session);
      if (closeAppOnDone) {
        await SystemNavigator.pop();
      }
    } catch (_) {
      // If anything goes wrong, fall back to just showing the app.
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
