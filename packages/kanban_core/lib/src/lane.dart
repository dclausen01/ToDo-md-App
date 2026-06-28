import 'card.dart';
import 'line_utils.dart';

/// A node inside a lane's body: either raw filler text ([GapNode]) or a
/// [CardNode]. The concatenation of all nodes (plus the heading) always equals
/// the lane's original text until something is edited — this is what guarantees
/// round-trip safety even for content the parser does not understand.
sealed class LaneNode {
  String serialize();
}

/// Raw, structurally-insignificant text between cards: blank lines, stray
/// separators (`***` / `---`), or anything else that is not a top-level card.
class GapNode extends LaneNode {
  GapNode(this.text);
  String text;
  @override
  String serialize() => text;
}

/// Wraps a [KanbanCard].
class CardNode extends LaneNode {
  CardNode(this.card);
  final KanbanCard card;
  @override
  String serialize() => card.serialize();
}

/// A Kanban lane (a `## Heading` column and its cards).
class KanbanLane {
  KanbanLane({required this.headingLine, required this.nodes});

  /// The raw `## ...` heading line, including its EOL.
  String headingLine;

  /// Body nodes after the heading (gaps interleaved with cards).
  final List<LaneNode> nodes;

  /// Lane title: the heading text after `## `, kept raw (may contain markdown).
  String get title {
    final content = lineContent(headingLine);
    return content.startsWith('## ') ? content.substring(3) : content;
  }

  set title(String value) {
    final prefix = lineContent(headingLine).startsWith('## ') ? '## ' : '';
    headingLine = '$prefix$value${lineEol(headingLine)}';
  }

  /// The cards in this lane, in order.
  List<KanbanCard> get cards =>
      nodes.whereType<CardNode>().map((n) => n.card).toList(growable: false);

  /// Removes [card] from this lane (and tidies the surrounding gap).
  bool removeCard(KanbanCard card) {
    final idx = nodes.indexWhere((n) => n is CardNode && n.card == card);
    if (idx < 0) return false;
    nodes.removeAt(idx);
    return true;
  }

  /// Inserts [card] at card-position [index] (counting only cards). A negative
  /// or out-of-range index appends. New cards are placed adjacent to existing
  /// ones, matching this file family's convention of no blank line between
  /// consecutive cards.
  void insertCard(KanbanCard card, {int index = -1}) {
    final cardNodeIndices = <int>[];
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i] is CardNode) cardNodeIndices.add(i);
    }
    int nodeInsertAt;
    if (index < 0 || index >= cardNodeIndices.length) {
      // Append after the last card, before any trailing gap.
      nodeInsertAt =
          cardNodeIndices.isEmpty ? nodes.length : cardNodeIndices.last + 1;
    } else {
      nodeInsertAt = cardNodeIndices[index];
    }
    nodes.insert(nodeInsertAt, CardNode(card));
  }

  /// Serializes the lane back to markdown.
  String serialize() =>
      headingLine + nodes.map((n) => n.serialize()).join();
}
