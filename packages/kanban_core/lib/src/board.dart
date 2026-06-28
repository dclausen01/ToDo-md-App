import 'card.dart';
import 'lane.dart';
import 'line_utils.dart';

/// A parsed Obsidian Kanban board.
///
/// The document is split into three byte-exact regions plus structured lanes:
///
///   [header]  — everything up to the first `## ` lane heading (YAML
///               frontmatter, the `kanban-plugin: board` marker, any preamble).
///   lanes     — the `## Heading` columns and their cards.
///   [footer]  — everything from the `%% kanban:settings` block to EOF.
///
/// [header] and [footer] are preserved verbatim. Serializing an unedited board
/// reproduces the source byte-for-byte.
class KanbanBoard {
  KanbanBoard({
    required this.header,
    required this.lanes,
    required this.footer,
    required this.eol,
    required this.indentUnit,
  });

  String header;
  final List<KanbanLane> lanes;
  String footer;

  /// Dominant EOL of the source (`\n` or `\r\n`).
  final String eol;

  /// Indentation unit detected from the source (tab or spaces).
  final String indentUnit;

  static const _settingsMarker = '%% kanban:settings';

  /// Whether the header declares this as a Kanban board.
  bool get isKanban => RegExp(r'(^|\n)kanban-plugin:\s*board\b').hasMatch(header);

  static final _cardStartRe = RegExp(r'^- \[[ xX]\]');

  /// Parses [source] into a [KanbanBoard].
  factory KanbanBoard.parse(String source) {
    final eol = detectEol(source);
    final indentUnit = detectIndentUnit(source);
    final lines = splitKeepEol(source);

    // Skip YAML frontmatter so a stray `## ` inside it can't be read as a lane.
    var scanStart = 0;
    if (lines.isNotEmpty && lineContent(lines.first).trim() == '---') {
      for (var i = 1; i < lines.length; i++) {
        if (lineContent(lines[i]).trim() == '---') {
          scanStart = i + 1;
          break;
        }
      }
    }

    // Locate the settings block (everything from here on is footer).
    var settingsStart = lines.length;
    for (var i = scanStart; i < lines.length; i++) {
      if (lineContent(lines[i]).trimRight() == _settingsMarker) {
        settingsStart = i;
        break;
      }
    }

    // Locate lane headings.
    final headingIdx = <int>[];
    for (var i = scanStart; i < settingsStart; i++) {
      if (lineContent(lines[i]).startsWith('## ')) headingIdx.add(i);
    }

    final firstLane = headingIdx.isEmpty ? settingsStart : headingIdx.first;
    final header = lines.sublist(0, firstLane).join();
    final footer = lines.sublist(settingsStart).join();

    final lanes = <KanbanLane>[];
    for (var k = 0; k < headingIdx.length; k++) {
      final h = headingIdx[k];
      final end =
          k + 1 < headingIdx.length ? headingIdx[k + 1] : settingsStart;
      final contentLines = lines.sublist(h + 1, end);
      lanes.add(KanbanLane(
        headingLine: lines[h],
        nodes: _buildNodes(contentLines, eol, indentUnit),
      ));
    }

    return KanbanBoard(
      header: header,
      lanes: lanes,
      footer: footer,
      eol: eol,
      indentUnit: indentUnit,
    );
  }

  /// Splits a lane's content lines into [GapNode]s and [CardNode]s such that
  /// concatenating them reproduces the input exactly.
  static List<LaneNode> _buildNodes(
      List<String> contentLines, String eol, String indentUnit) {
    final nodes = <LaneNode>[];
    final gap = StringBuffer();

    void flushGap() {
      if (gap.isNotEmpty) {
        nodes.add(GapNode(gap.toString()));
        gap.clear();
      }
    }

    var i = 0;
    while (i < contentLines.length) {
      if (_cardStartRe.hasMatch(lineContent(contentLines[i]))) {
        flushGap();
        final cardLines = <String>[contentLines[i]];
        i++;
        while (i < contentLines.length &&
            !_cardStartRe.hasMatch(lineContent(contentLines[i]))) {
          cardLines.add(contentLines[i]);
          i++;
        }
        // Trailing blank lines belong to the following gap, not the card.
        final trailing = <String>[];
        while (cardLines.length > 1 && isBlankLine(cardLines.last)) {
          trailing.insert(0, cardLines.removeLast());
        }
        final card = KanbanCard(cardLines)
          ..eol = eol
          ..indentUnit = indentUnit;
        nodes.add(CardNode(card));
        for (final t in trailing) {
          gap.write(t);
        }
      } else {
        gap.write(contentLines[i]);
        i++;
      }
    }
    flushGap();
    return nodes;
  }

  /// Convenience: all cards across all lanes.
  Iterable<KanbanCard> get allCards =>
      lanes.expand((l) => l.cards);

  /// Serializes the board back to markdown.
  String serialize() =>
      header + lanes.map((l) => l.serialize()).join() + footer;

  @override
  String toString() =>
      'KanbanBoard(${lanes.length} lanes, ${allCards.length} cards)';
}
