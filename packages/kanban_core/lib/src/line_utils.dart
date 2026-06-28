/// Low-level line helpers used throughout the parser/serializer.
///
/// The golden rule of this package is round-trip safety: parsing a document and
/// serializing it again without edits must reproduce the input byte-for-byte.
/// To make that achievable we always work on "lines that keep their own line
/// terminator", so concatenating a list of such lines reproduces the source
/// exactly (including a possibly missing terminator on the final line, and any
/// mix of `\n` / `\r\n`).
library;

/// Splits [source] into lines, keeping each line's trailing terminator
/// (`\n` or `\r\n`) attached. The final line keeps whatever terminator it had
/// (possibly none). Joining the result with `''` reproduces [source] exactly.
List<String> splitKeepEol(String source) {
  final lines = <String>[];
  var start = 0;
  for (var i = 0; i < source.length; i++) {
    if (source.codeUnitAt(i) == 0x0a /* \n */) {
      lines.add(source.substring(start, i + 1));
      start = i + 1;
    }
  }
  if (start < source.length) {
    lines.add(source.substring(start));
  }
  return lines;
}

/// Returns the content of a kept-EOL [line] without its trailing `\r?\n`.
String lineContent(String line) {
  var end = line.length;
  if (end > 0 && line.codeUnitAt(end - 1) == 0x0a) {
    end--;
    if (end > 0 && line.codeUnitAt(end - 1) == 0x0d) {
      end--;
    }
  }
  return line.substring(0, end);
}

/// Returns just the trailing terminator of a kept-EOL [line] (`''`, `'\n'` or
/// `'\r\n'`).
String lineEol(String line) => line.substring(lineContent(line).length);

/// Whether a line is blank (only whitespace, ignoring its terminator).
bool isBlankLine(String line) => lineContent(line).trim().isEmpty;

/// Detects the dominant end-of-line sequence of [source]. Defaults to `'\n'`.
String detectEol(String source) {
  final i = source.indexOf('\n');
  if (i > 0 && source.codeUnitAt(i - 1) == 0x0d) return '\r\n';
  return '\n';
}

/// Detects the indentation unit used for nested content. Obsidian's Kanban
/// plugin writes tabs, but vaults edited elsewhere may use spaces. We look at
/// the first indented line and reuse whatever it used; default is a single tab.
String detectIndentUnit(String source) {
  for (final line in splitKeepEol(source)) {
    final content = lineContent(line);
    if (content.isEmpty) continue;
    final first = content.codeUnitAt(0);
    if (first == 0x09) return '\t';
    if (first == 0x20) {
      var n = 0;
      while (n < content.length && content.codeUnitAt(n) == 0x20) {
        n++;
      }
      // Heuristic: nested markdown is usually 2- or 4-space; reuse the run.
      return ' ' * (n >= 4 ? 4 : 2);
    }
  }
  return '\t';
}
