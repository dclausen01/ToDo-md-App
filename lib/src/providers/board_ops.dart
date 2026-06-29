import 'package:kanban_core/kanban_core.dart';

/// A stable-ish reference to a card, so the same card can be re-located on a
/// freshly parsed board (e.g. after Obsidian re-wrote the file). Matching order:
/// Obsidian block-id (truly stable) → exact original text in the same lane
/// (respecting duplicates via [occurrence]) → exact text anywhere.
class CardAnchor {
  CardAnchor({
    required this.blockId,
    required this.rawText,
    required this.laneTitle,
    required this.occurrence,
  });

  factory CardAnchor.of(KanbanBoard board, KanbanCard card) {
    final lane = board.laneOf(card);
    final raw = card.serialize();
    var occ = 0;
    if (lane != null) {
      for (final c in lane.cards) {
        if (identical(c, card)) break;
        if (c.serialize() == raw) occ++;
      }
    }
    return CardAnchor(
      blockId: card.blockId,
      rawText: raw,
      laneTitle: lane?.title ?? '',
      occurrence: occ,
    );
  }

  final String? blockId;
  final String rawText;
  final String laneTitle;
  final int occurrence;

  KanbanCard? locate(KanbanBoard board) {
    if (blockId != null) {
      for (final lane in board.lanes) {
        for (final c in lane.cards) {
          if (c.blockId == blockId) return c;
        }
      }
    }
    final lane = _laneByTitle(board, laneTitle);
    if (lane != null) {
      final inLane =
          lane.cards.where((c) => c.serialize() == rawText).toList();
      if (occurrence < inLane.length) return inLane[occurrence];
      if (inLane.isNotEmpty) return inLane.first;
    }
    for (final l in board.lanes) {
      for (final c in l.cards) {
        if (c.serialize() == rawText) return c;
      }
    }
    return null;
  }
}

KanbanLane? _laneByTitle(KanbanBoard board, String title) {
  for (final lane in board.lanes) {
    if (lane.title == title) return lane;
  }
  return null;
}

/// A user edit expressed so it can be applied to *any* version of the board —
/// the live in-memory one for the optimistic update, and a freshly re-read one
/// when auto-merging after an external change.
sealed class BoardOp {
  /// Applies the edit to [board]. Returns false if the target could no longer
  /// be found (then the change cannot be auto-merged and the caller asks the
  /// user how to proceed).
  bool apply(KanbanBoard board);
}

class ToggleCardOp extends BoardOp {
  ToggleCardOp(this.anchor);
  factory ToggleCardOp.of(KanbanBoard board, KanbanCard card) =>
      ToggleCardOp(CardAnchor.of(board, card));
  final CardAnchor anchor;

  @override
  bool apply(KanbanBoard board) {
    final card = anchor.locate(board);
    if (card == null) return false;
    card.toggleChecked();
    return true;
  }
}

class MoveCardOp extends BoardOp {
  MoveCardOp(this.anchor, this.targetLaneTitle, this.index);
  factory MoveCardOp.of(
    KanbanBoard board,
    KanbanCard card,
    KanbanLane target,
    int index,
  ) =>
      MoveCardOp(CardAnchor.of(board, card), target.title, index);

  final CardAnchor anchor;
  final String targetLaneTitle;
  final int index;

  @override
  bool apply(KanbanBoard board) {
    final card = anchor.locate(board);
    if (card == null) return false;
    final target = _laneByTitle(board, targetLaneTitle);
    if (target == null) return false;
    return board.moveCard(card, target, index: index);
  }
}

/// Marks a card done (`[x]`) and moves it to the top of the done lane — one
/// atomic edit so it auto-merges as a single operation.
class MoveToDoneOp extends BoardOp {
  MoveToDoneOp(this.anchor, this.doneLaneTitle);
  factory MoveToDoneOp.of(
    KanbanBoard board,
    KanbanCard card,
    KanbanLane doneLane,
  ) =>
      MoveToDoneOp(CardAnchor.of(board, card), doneLane.title);

  final CardAnchor anchor;
  final String doneLaneTitle;

  @override
  bool apply(KanbanBoard board) {
    final card = anchor.locate(board);
    if (card == null) return false;
    final target = _laneByTitle(board, doneLaneTitle);
    if (target == null) return false;
    card.checked = true;
    return board.moveCard(card, target, index: 0);
  }
}

class DeleteCardOp extends BoardOp {
  DeleteCardOp(this.anchor);
  factory DeleteCardOp.of(KanbanBoard board, KanbanCard card) =>
      DeleteCardOp(CardAnchor.of(board, card));
  final CardAnchor anchor;

  @override
  bool apply(KanbanBoard board) {
    final card = anchor.locate(board);
    if (card == null) return false;
    return board.deleteCard(card);
  }
}

class AddCardOp extends BoardOp {
  AddCardOp({
    required this.laneTitle,
    required this.title,
    this.tags = const [],
    this.date,
    this.index = -1,
  });

  final String laneTitle;
  final String title;
  final List<String> tags;
  final String? date;
  final int index;

  @override
  bool apply(KanbanBoard board) {
    final lane = _laneByTitle(board, laneTitle);
    if (lane == null) return false;
    board.addCard(lane, title: title, tags: tags, date: date, index: index);
    return true;
  }
}

/// Replaces a card's full text (editor save), optionally moving it to another
/// lane.
class ReplaceCardOp extends BoardOp {
  ReplaceCardOp({
    required this.anchor,
    required this.newRawText,
    this.targetLaneTitle,
  });

  final CardAnchor anchor;
  final String newRawText;
  final String? targetLaneTitle;

  @override
  bool apply(KanbanBoard board) {
    final card = anchor.locate(board);
    if (card == null) return false;
    card.replaceRaw(newRawText);
    final target = targetLaneTitle;
    if (target != null) {
      final lane = _laneByTitle(board, target);
      if (lane != null) board.moveCard(card, lane);
    }
    return true;
  }
}
