import '../storage/saf.dart';

/// Resolves Obsidian `[[wikilinks]]` to concrete files within the vault,
/// approximating Obsidian's "shortest path when possible" behaviour.
class LinkResolver {
  LinkResolver(List<SafFile> files)
      : _files = files.where((f) => !f.isDir).toList(growable: false);

  final List<SafFile> _files;

  /// Strips a `#heading` and/or `|alias` suffix from a raw link target.
  static String cleanTarget(String raw) {
    var t = raw.trim();
    final pipe = t.indexOf('|');
    if (pipe >= 0) t = t.substring(0, pipe);
    final hash = t.indexOf('#');
    if (hash >= 0) t = t.substring(0, hash);
    return t.trim();
  }

  /// Returns the best-matching file for [rawTarget], or null if none is found.
  SafFile? resolve(String rawTarget) {
    final target = cleanTarget(rawTarget);
    if (target.isEmpty) return null;

    final hasExt = RegExp(r'\.[A-Za-z0-9]+$').hasMatch(target);

    if (target.contains('/')) {
      // Path-qualified link: match by path suffix.
      final wanted = hasExt ? target : '$target.md';
      final exact = _files.where((f) => f.path == wanted);
      if (exact.isNotEmpty) return exact.first;
      final suffix = _byShortestPath(
          _files.where((f) => f.path == wanted || f.path.endsWith('/$wanted')));
      if (suffix != null) return suffix;
    }

    // Match by basename.
    final base = target.toLowerCase();
    final matches = _files.where((f) {
      final name = f.name.toLowerCase();
      final noExt = _stripExt(name);
      if (hasExt) return name == base;
      return noExt == base || name == base;
    });
    return _byShortestPath(matches);
  }

  SafFile? _byShortestPath(Iterable<SafFile> candidates) {
    SafFile? best;
    var bestDepth = 1 << 30;
    for (final f in candidates) {
      final depth = '/'.allMatches(f.path).length;
      if (depth < bestDepth) {
        best = f;
        bestDepth = depth;
      }
    }
    return best;
  }

  static String _stripExt(String name) {
    final i = name.lastIndexOf('.');
    return i <= 0 ? name : name.substring(0, i);
  }
}
