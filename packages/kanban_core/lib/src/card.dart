import 'line_utils.dart';

/// A parsed Kanban card.
///
/// Source of truth is [lines] — the original markdown lines (each keeping its
/// own EOL). All mutators perform *minimal, local* edits to these lines so that
/// anything the parser did not explicitly understand survives untouched. Until
/// a card is edited, [serialize] reproduces the original bytes exactly.
class KanbanCard {
  KanbanCard(this.lines) : assert(lines.isNotEmpty);

  /// The raw lines of this card, each including its trailing `\n`/`\r\n`.
  final List<String> lines;

  /// EOL to use when this card needs to synthesize a new line.
  String eol = '\n';

  /// Indentation unit to use when synthesizing nested lines.
  String indentUnit = '\t';

  static final _firstLineRe = RegExp(r'^(\s*)- \[([ xX])\] ?(.*)$');
  static final _blockIdRe = RegExp(r'(\s+)(\^[0-9a-zA-Z]+)\s*$');
  static final _tagRe = RegExp(r'(?<![\w#])#[A-Za-z0-9_/äöüÄÖÜß][\w/äöüÄÖÜß-]*');
  static final _dateRe = RegExp(r'@\{(\d{4}-\d{2}-\d{2})\}');
  static final _timeRe = RegExp(r'@@+\{([^}]*)\}');
  static final _subtaskRe = RegExp(r'^(\s+)- \[([ xX])\] ?(.*)$');

  String get _firstContent => lineContent(lines.first);

  /// Whether the card's checkbox is checked (`- [x]`).
  bool get checked {
    final m = _firstLineRe.firstMatch(_firstContent);
    return m != null && m.group(2)!.toLowerCase() == 'x';
  }

  set checked(bool value) {
    final content = _firstContent;
    final m = _firstLineRe.firstMatch(content);
    if (m == null) return;
    final replacement = '${m.group(1)}- [${value ? 'x' : ' '}] ${m.group(3)}';
    lines[0] = replacement + lineEol(lines.first);
  }

  void toggleChecked() => checked = !checked;

  ({String title, String blockSuffix, String prefix})? _titleParts() {
    final m = _firstLineRe.firstMatch(_firstContent);
    if (m == null) return null;
    final prefix = '${m.group(1)}- [${m.group(2)}] ';
    var rest = m.group(3)!;
    var blockSuffix = '';
    final b = _blockIdRe.firstMatch(rest);
    if (b != null) {
      blockSuffix = b.group(0)!;
      rest = rest.substring(0, b.start);
    }
    return (title: rest, blockSuffix: blockSuffix, prefix: prefix);
  }

  /// The card title: the first line's text after the checkbox, excluding a
  /// trailing block id. May still contain markdown (e.g. `**bold**`) or a
  /// `[[wikilink]]`, which is intentional so editing stays loss-free.
  String get title => _titleParts()?.title ?? _firstContent;

  set title(String value) {
    final parts = _titleParts();
    if (parts == null) return;
    lines[0] = parts.prefix + value + parts.blockSuffix + lineEol(lines.first);
  }

  /// The card's Obsidian block id (without the leading `^`), if any.
  String? get blockId {
    final s = _titleParts()?.blockSuffix;
    if (s == null || s.isEmpty) return null;
    return s.trim().substring(1);
  }

  String get _allText => lines.join();

  /// All tags found anywhere in the card, in document order, without `#`.
  List<String> get tags => _tagRe
      .allMatches(_allText)
      .map((m) => m.group(0)!.substring(1))
      .toList(growable: false);

  /// First `@{YYYY-MM-DD}` date found in the card, or null.
  String? get date => _dateRe.firstMatch(_allText)?.group(1);

  /// All `@@{...}` / `@@@{...}` time annotations found, raw inner text.
  List<String> get times => _timeRe
      .allMatches(_allText)
      .map((m) => m.group(1)!)
      .toList(growable: false);

  /// Subtasks: nested (indented) checkbox items within the card body.
  List<KanbanSubtask> get subtasks {
    final result = <KanbanSubtask>[];
    for (var i = 1; i < lines.length; i++) {
      final m = _subtaskRe.firstMatch(lineContent(lines[i]));
      if (m != null) {
        result.add(KanbanSubtask(
          lineIndex: i,
          checked: m.group(2)!.toLowerCase() == 'x',
          text: m.group(3)!,
        ));
      }
    }
    return result;
  }

  /// Toggles the checkbox of the subtask on line [lineIndex].
  void toggleSubtask(int lineIndex) {
    if (lineIndex <= 0 || lineIndex >= lines.length) return;
    final content = lineContent(lines[lineIndex]);
    final m = _subtaskRe.firstMatch(content);
    if (m == null) return;
    final nowChecked = m.group(2)!.toLowerCase() == 'x';
    final replacement =
        '${m.group(1)}- [${nowChecked ? ' ' : 'x'}] ${m.group(3)}';
    lines[lineIndex] = replacement + lineEol(lines[lineIndex]);
  }

  /// The "notes" of a card: every body line that is not a subtask, returned as
  /// raw content (without EOLs). Used by the editor's verbatim notes field.
  List<String> get noteLines {
    final result = <String>[];
    for (var i = 1; i < lines.length; i++) {
      if (_subtaskRe.firstMatch(lineContent(lines[i])) == null) {
        result.add(lineContent(lines[i]));
      }
    }
    return result;
  }

  /// Adds a tag to the card if not already present. Appends it to the first
  /// existing line that already carries a tag, otherwise to the last non-blank
  /// line, otherwise as a new indented line.
  void addTag(String tag) {
    final clean = tag.startsWith('#') ? tag.substring(1) : tag;
    if (tags.contains(clean)) return;
    final token = '#$clean';
    for (var i = 0; i < lines.length; i++) {
      if (_tagRe.hasMatch(lineContent(lines[i]))) {
        lines[i] = '${lineContent(lines[i])} $token${lineEol(lines[i])}';
        return;
      }
    }
    for (var i = lines.length - 1; i >= 0; i--) {
      if (!isBlankLine(lines[i])) {
        if (i == 0) {
          lines[0] = '$_firstContent $token${lineEol(lines.first)}';
        } else {
          lines[i] = '${lineContent(lines[i])} $token${lineEol(lines[i])}';
        }
        return;
      }
    }
  }

  /// Removes the first occurrence of [tag] (with a leading space if present).
  void removeTag(String tag) {
    final clean = tag.startsWith('#') ? tag.substring(1) : tag;
    final token = '#$clean';
    for (var i = 0; i < lines.length; i++) {
      final content = lineContent(lines[i]);
      final idx = content.indexOf(token);
      if (idx < 0) continue;
      // Make sure we matched a whole tag token, not a prefix of a longer one.
      final after = idx + token.length;
      if (after < content.length && RegExp(r'[\w/-]').hasMatch(content[after])) {
        continue;
      }
      var removeStart = idx;
      if (removeStart > 0 && content[removeStart - 1] == ' ') removeStart--;
      final newContent =
          content.substring(0, removeStart) + content.substring(after);
      lines[i] = newContent + lineEol(lines[i]);
      return;
    }
  }

  /// Sets (or with null, clears) the card's first `@{date}`. When adding a date
  /// where none exists, it is appended to the tag/metadata line.
  void setDate(String? isoDate) {
    final allText = _allText;
    final existing = _dateRe.firstMatch(allText);
    if (existing != null) {
      for (var i = 0; i < lines.length; i++) {
        final content = lineContent(lines[i]);
        final m = _dateRe.firstMatch(content);
        if (m == null) continue;
        final replaced = isoDate == null
            ? _stripToken(content, m.start, m.end)
            : content.replaceRange(m.start, m.end, '@{$isoDate}');
        lines[i] = replaced + lineEol(lines[i]);
        return;
      }
    }
    if (isoDate == null) return;
    final token = '@{$isoDate}';
    for (var i = 0; i < lines.length; i++) {
      if (_tagRe.hasMatch(lineContent(lines[i]))) {
        lines[i] = '${lineContent(lines[i])} $token${lineEol(lines[i])}';
        return;
      }
    }
    // No tag line: append a new indented metadata line after the title.
    final insertAt = lines.length;
    lines.insert(insertAt, '$indentUnit$token$eol');
  }

  String _stripToken(String content, int start, int end) {
    var s = start;
    if (s > 0 && content[s - 1] == ' ') s--;
    return content.substring(0, s) + content.substring(end);
  }

  /// Replaces the entire card with [rawText] (used by the editor's raw mode and
  /// when constructing brand-new cards). [rawText] should already use the
  /// desired EOLs; a trailing EOL is ensured.
  void replaceRaw(String rawText) {
    var text = rawText;
    if (!text.endsWith('\n')) text += eol;
    lines
      ..clear()
      ..addAll(splitKeepEol(text));
  }

  /// The card serialized back to markdown (its current lines joined).
  String serialize() => lines.join();

  @override
  String toString() => 'KanbanCard(${title.isEmpty ? '<untitled>' : title})';
}

/// A nested checkbox item inside a card body.
class KanbanSubtask {
  const KanbanSubtask({
    required this.lineIndex,
    required this.checked,
    required this.text,
  });

  /// Index into the owning card's [KanbanCard.lines].
  final int lineIndex;
  final bool checked;
  final String text;
}
