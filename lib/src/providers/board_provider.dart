import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_core/kanban_core.dart';

import '../storage/board_repository.dart';
import 'settings_provider.dart';

/// In-memory state of the currently loaded board.
class BoardSession {
  const BoardSession({
    required this.board,
    required this.treeUri,
    required this.boardPath,
    required this.loadedContent,
    this.revision = 0,
  });

  final KanbanBoard board;
  final String treeUri;
  final String boardPath;

  /// Exact text last read from disk — used to detect external edits.
  final String loadedContent;

  /// Bumped on every in-memory mutation so listeners rebuild (the board model
  /// is mutable, so identity alone would not change).
  final int revision;

  BoardSession copyWith({String? loadedContent, int? revision}) {
    return BoardSession(
      board: board,
      treeUri: treeUri,
      boardPath: boardPath,
      loadedContent: loadedContent ?? this.loadedContent,
      revision: revision ?? this.revision,
    );
  }
}

/// Loads the board and applies edits, persisting each change with backup and
/// external-change protection.
class BoardController extends AsyncNotifier<BoardSession?> {
  BoardRepository get _repo => BoardRepository(ref.read(safServiceProvider));

  @override
  Future<BoardSession?> build() async {
    final settings = await ref.watch(settingsProvider.future);
    if (!settings.isConfigured) return null;
    final content = await _repo.load(settings.vaultTreeUri!, settings.boardPath);
    return BoardSession(
      board: KanbanBoard.parse(content),
      treeUri: settings.vaultTreeUri!,
      boardPath: settings.boardPath,
      loadedContent: content,
    );
  }

  /// Re-reads the board from disk, discarding any unsaved in-memory edits.
  Future<void> reload() async {
    final session = state.valueOrNull;
    if (session == null) {
      ref.invalidateSelf();
      return;
    }
    state = const AsyncLoading<BoardSession?>().copyWithPrevious(state);
    final content = await _repo.load(session.treeUri, session.boardPath);
    state = AsyncData(BoardSession(
      board: KanbanBoard.parse(content),
      treeUri: session.treeUri,
      boardPath: session.boardPath,
      loadedContent: content,
    ));
  }

  /// Re-reads the board from disk only if it actually changed since it was
  /// loaded, and replaces the in-memory board with the fresh version. Returns
  /// true if a reload happened. Cheap no-op when nothing changed (keeps scroll
  /// position and avoids needless rebuilds).
  ///
  /// Safe to call on app resume because the app auto-saves after every edit, so
  /// there are never unsaved board-level changes to lose.
  Future<bool> refreshIfChanged() async {
    final session = state.valueOrNull;
    if (session == null) return false;
    final onDisk = await _repo.load(session.treeUri, session.boardPath);
    if (onDisk == session.loadedContent) return false;
    state = AsyncData(BoardSession(
      board: KanbanBoard.parse(onDisk),
      treeUri: session.treeUri,
      boardPath: session.boardPath,
      loadedContent: onDisk,
    ));
    return true;
  }

  /// Applies [action] to the board, updates the UI optimistically, then saves.
  ///
  /// Throws [ExternalChangeException] if the file changed on disk; the in-memory
  /// edit is kept so the caller can offer "reload" (discard) or "overwrite"
  /// ([forceSave]).
  Future<void> mutate(void Function(KanbanBoard board) action) async {
    final session = state.valueOrNull;
    if (session == null) return;
    action(session.board);
    // Optimistic UI refresh.
    state = AsyncData(session.copyWith(revision: session.revision + 1));
    await _persist(session);
  }

  Future<void> _persist(BoardSession session, {bool force = false}) async {
    final current = state.valueOrNull ?? session;
    final newContent = current.board.serialize();
    await _repo.save(
      current.treeUri,
      current.boardPath,
      newContent,
      loadedContent: current.loadedContent,
      force: force,
    );
    state = AsyncData(current.copyWith(
      loadedContent: newContent,
      revision: current.revision + 1,
    ));
  }

  /// Overwrites the on-disk file with the current in-memory board, even if it
  /// changed externally (a backup of the on-disk version is still made).
  Future<void> forceSave() async {
    final session = state.valueOrNull;
    if (session == null) return;
    await _persist(session, force: true);
  }
}

final boardProvider =
    AsyncNotifierProvider<BoardController, BoardSession?>(BoardController.new);
