/// Kind of link found inside a card.
enum CardLinkKind { wiki, embed, url }

class CardLink {
  const CardLink({
    required this.kind,
    required this.target,
    required this.display,
  });

  final CardLinkKind kind;

  /// For wiki/embed: the raw inner target (may include `#heading`/`|alias`).
  /// For url: the full URL.
  final String target;

  /// Human-friendly label for a chip/button.
  final String display;
}

final _wikiRe = RegExp(r'(!?)\[\[([^\]]+)\]\]');
final _urlRe = RegExp(r'https?://[^\s)>\]]+');
final _mdLinkRe = RegExp(r'\[([^\]]+)\]\((https?://[^)]+)\)');

/// Extracts all links (wikilinks, embeds and URLs) from [text] in document
/// order, de-duplicated by target.
List<CardLink> extractLinks(String text) {
  final seen = <String>{};
  final out = <CardLink>[];

  for (final m in _wikiRe.allMatches(text)) {
    final embed = m.group(1) == '!';
    final inner = m.group(2)!;
    final key = '${embed ? 'embed' : 'wiki'}:$inner';
    if (seen.add(key)) {
      out.add(CardLink(
        kind: embed ? CardLinkKind.embed : CardLinkKind.wiki,
        target: inner,
        display: _wikiDisplay(inner),
      ));
    }
  }

  // Markdown links first so their inner URL isn't double-counted by _urlRe.
  for (final m in _mdLinkRe.allMatches(text)) {
    final url = m.group(2)!;
    if (seen.add('url:$url')) {
      out.add(CardLink(
          kind: CardLinkKind.url, target: url, display: m.group(1)!));
    }
  }
  for (final m in _urlRe.allMatches(text)) {
    final url = m.group(0)!;
    if (seen.add('url:$url')) {
      out.add(CardLink(
          kind: CardLinkKind.url, target: url, display: _shortUrl(url)));
    }
  }
  return out;
}

String _wikiDisplay(String inner) {
  var t = inner;
  final pipe = t.indexOf('|');
  if (pipe >= 0) return t.substring(pipe + 1).trim();
  final hash = t.indexOf('#');
  if (hash >= 0) t = t.substring(0, hash);
  final slash = t.lastIndexOf('/');
  if (slash >= 0) t = t.substring(slash + 1);
  // Drop a trailing file extension for nicer display.
  final dot = t.lastIndexOf('.');
  if (dot > 0) t = t.substring(0, dot);
  return t.trim();
}

String _shortUrl(String url) {
  final m = RegExp(r'^https?://([^/]+)').firstMatch(url);
  return m == null ? url : m.group(1)!;
}

/// Removes inline markdown noise for previews/titles: `**bold**`, `_italic_`,
/// wikilink/embed brackets (keeping the visible text) and bare URLs.
String stripInlineMarkdown(String text) {
  var t = text;
  t = t.replaceAllMapped(_wikiRe, (m) => _wikiDisplay(m.group(2)!));
  t = t.replaceAllMapped(_mdLinkRe, (m) => m.group(1)!);
  t = t.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1)!)
      .replaceAll('**', '');
  t = t.replaceAllMapped(RegExp(r'(?<!\w)_([^_]+)_(?!\w)'), (m) => m.group(1)!);
  t = t.replaceAll(_urlRe, '🔗');
  return t.trim();
}
