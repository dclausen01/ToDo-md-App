import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_core/kanban_core.dart';

import '../providers/board_ops.dart';
import '../providers/board_provider.dart';
import '../providers/settings_provider.dart';
import 'quick_add_sheet.dart';
import 'save_helpers.dart';

/// Shows the quick-add bottom sheet over the current screen and adds the card.
/// Returns true if a card was added. Shared by the board's FAB/lane buttons and
/// by the home-screen widget launch flow.
Future<bool> showQuickAddFlow(
  BuildContext context,
  WidgetRef ref,
  BoardSession session, {
  KanbanLane? lane,
}) async {
  final lanes = session.board.lanes;
  if (lanes.isEmpty) return false;
  final settings = ref.read(settingsProvider).valueOrNull;
  final target = lane ?? defaultLaneFor(session, settings);

  final result = await showModalBottomSheet<QuickAddResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => QuickAddSheet(lanes: lanes, initialLane: target),
  );
  if (result == null || result.title.trim().isEmpty) return false;
  if (!context.mounted) return false;

  return runBoardEdit(
    ref,
    context,
    AddCardOp(
      laneTitle: result.lane.title,
      title: result.title.trim(),
      tags: result.tags,
      date: result.date,
    ),
  );
}

/// The lane new tasks default to: the configured default lane, else the first.
KanbanLane defaultLaneFor(BoardSession session, AppSettings? settings) {
  final title = settings?.defaultLaneTitle;
  if (title != null) {
    for (final lane in session.board.lanes) {
      if (lane.title == title) return lane;
    }
  }
  return session.board.lanes.first;
}
