import 'board.dart';
import 'card.dart';
import 'lane.dart';

/// High-level editing operations on a [KanbanBoard]. These keep edits local and
/// reuse the lane/card primitives so untouched content stays byte-exact.
extension KanbanBoardOps on KanbanBoard {
  /// Finds the lane that currently contains [card].
  KanbanLane? laneOf(KanbanCard card) {
    for (final lane in lanes) {
      if (lane.cards.contains(card)) return lane;
    }
    return null;
  }

  /// Moves [card] from its current lane into [target] at card-position [index]
  /// (append when negative/out-of-range). Returns false if the card wasn't
  /// found in any lane.
  bool moveCard(KanbanCard card, KanbanLane target, {int index = -1}) {
    final source = laneOf(card);
    if (source == null) return false;
    source.removeCard(card);
    target.insertCard(card, index: index);
    return true;
  }

  /// Builds a new card consistent with this board's EOL/indentation and adds it
  /// to [lane]. Returns the created card.
  KanbanCard addCard(
    KanbanLane lane, {
    required String title,
    bool checked = false,
    List<String> tags = const [],
    String? date,
    int index = -1,
  }) {
    final card = newCard(
      title: title,
      checked: checked,
      tags: tags,
      date: date,
    );
    lane.insertCard(card, index: index);
    return card;
  }

  /// Constructs a standalone card (not yet attached to a lane) using this
  /// board's EOL and indentation conventions.
  KanbanCard newCard({
    required String title,
    bool checked = false,
    List<String> tags = const [],
    String? date,
  }) {
    final meta = <String>[
      ...tags.map((t) => t.startsWith('#') ? t : '#$t'),
      if (date != null) '@{$date}',
    ];
    final buf = StringBuffer('- [${checked ? 'x' : ' '}] $title$eol');
    if (meta.isNotEmpty) {
      buf.write('$indentUnit${meta.join(' ')}$eol');
    }
    return KanbanCard(splitLinesForCard(buf.toString(), eol))
      ..eol = eol
      ..indentUnit = indentUnit;
  }

  /// Deletes [card] from whichever lane holds it. Returns false if not found.
  bool deleteCard(KanbanCard card) {
    final lane = laneOf(card);
    if (lane == null) return false;
    return lane.removeCard(card);
  }
}

/// Splits already-EOL-terminated card text into kept-EOL lines.
List<String> splitLinesForCard(String text, String eol) {
  final lines = <String>[];
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x0a) {
      lines.add(text.substring(start, i + 1));
      start = i + 1;
    }
  }
  if (start < text.length) lines.add(text.substring(start));
  return lines;
}
