import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_core/kanban_core.dart';

import '../providers/board_ops.dart';
import '../providers/board_provider.dart';
import '../providers/settings_provider.dart';
import 'quick_add_sheet.dart';
import 'save_helpers.dart';

/// Lightweight overlay launched by the home-screen widget: opens the quick-add
/// input straight away, saves the new card, then (on a cold start) closes the
/// app again so it feels like an instant capture.
class QuickAddScreen extends ConsumerStatefulWidget {
  const QuickAddScreen({super.key, required this.closeAppOnDone});

  /// When true (launched fresh from the widget), finishing closes the app and
  /// returns to the home screen. When false (app was already open), it just
  /// pops back to where the user was.
  final bool closeAppOnDone;

  @override
  ConsumerState<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends ConsumerState<QuickAddScreen> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final boardAsync = ref.watch(boardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Neue Aufgabe')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _message('Einstellungen konnten nicht geladen werden:\n$e'),
        data: (settings) {
          if (!settings.isConfigured) {
            return _message(
              'Bitte richte zuerst in der App deinen Vault ein, dann '
              'funktioniert auch das Widget.',
            );
          }
          return boardAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _message('Board konnte nicht geladen werden:\n$e'),
            data: (session) {
              if (session == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!_opened) {
                _opened = true;
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _showSheet(session));
              }
              return const Center(child: CircularProgressIndicator());
            },
          );
        },
      ),
    );
  }

  KanbanLane _defaultLane(BoardSession session, AppSettings settings) {
    final title = settings.defaultLaneTitle;
    if (title != null) {
      for (final lane in session.board.lanes) {
        if (lane.title == title) return lane;
      }
    }
    return session.board.lanes.first;
  }

  Future<void> _showSheet(BoardSession session) async {
    final settings = ref.read(settingsProvider).valueOrNull;
    final lanes = session.board.lanes;
    if (lanes.isEmpty || settings == null) {
      _finish();
      return;
    }
    final result = await showModalBottomSheet<QuickAddResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickAddSheet(
        lanes: lanes,
        initialLane: _defaultLane(session, settings),
      ),
    );
    if (!mounted) return;
    if (result == null || result.title.trim().isEmpty) {
      _finish();
      return;
    }
    await runBoardEdit(
      ref,
      context,
      AddCardOp(
        laneTitle: result.lane.title,
        title: result.title.trim(),
        tags: result.tags,
        date: result.date,
      ),
    );
    _finish();
  }

  void _finish() {
    if (widget.closeAppOnDone) {
      SystemNavigator.pop();
    } else if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Widget _message(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}
