import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/quick_add_launch.dart';
import 'home_screen.dart';
import 'quick_add_screen.dart';

/// App root. Shows the board, and routes home-screen-widget taps into the
/// quick-add overlay (both on cold start and while already running).
class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> {
  static const _launch = QuickAddLaunch();
  bool _quickAddOpen = false;

  @override
  void initState() {
    super.initState();
    // Warm start: widget tapped while the app is already running.
    _launch.setQuickAddHandler(() => _openQuickAdd(closeAppOnDone: false));
    // Cold start: app launched by the widget.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final action = await _launch.getLaunchAction();
      if (action == 'quick_add') {
        _openQuickAdd(closeAppOnDone: true);
      }
    });
  }

  Future<void> _openQuickAdd({required bool closeAppOnDone}) async {
    if (_quickAddOpen || !mounted) return;
    _quickAddOpen = true;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => QuickAddScreen(closeAppOnDone: closeAppOnDone),
      ),
    );
    _quickAddOpen = false;
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
