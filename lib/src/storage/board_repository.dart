import 'saf.dart';

/// Thrown by [BoardRepository.save] when the board file on disk changed since it
/// was loaded (e.g. Obsidian wrote to it). The caller can show the user a
/// reload/overwrite choice instead of silently clobbering their data.
class ExternalChangeException implements Exception {
  ExternalChangeException(this.onDiskContent);
  final String onDiskContent;
  @override
  String toString() => 'ExternalChangeException: board changed on disk';
}

/// Loads and saves the board file, with a safety net: a backup before every
/// write and detection of concurrent external edits.
class BoardRepository {
  BoardRepository(this.saf);

  final SafService saf;

  static const backupDir = '.todo-md-app-backups';
  static const _maxBackups = 12;

  Future<String> load(String treeUri, String path) =>
      saf.readFile(treeUri, path);

  /// Saves [content] to [path]. [loadedContent] is the exact text we last read;
  /// if the on-disk file no longer matches it, an [ExternalChangeException] is
  /// thrown and nothing is written.
  Future<void> save(
    String treeUri,
    String path,
    String content, {
    required String loadedContent,
    bool force = false,
  }) async {
    String? onDisk;
    if (await saf.exists(treeUri, path)) {
      onDisk = await saf.readFile(treeUri, path);
      if (!force && onDisk != loadedContent) {
        throw ExternalChangeException(onDisk);
      }
    }
    if (onDisk != null) {
      await _writeBackup(treeUri, path, onDisk);
    }
    await saf.writeFile(treeUri, path, content);
  }

  String _baseName(String path) {
    final i = path.lastIndexOf('/');
    final name = i < 0 ? path : path.substring(i + 1);
    return name.endsWith('.md') ? name.substring(0, name.length - 3) : name;
  }

  Future<void> _writeBackup(
      String treeUri, String path, String previousContent) async {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final backupPath = '$backupDir/${_baseName(path)}-$stamp.md';
    await saf.writeFile(treeUri, backupPath, previousContent);
    await _pruneBackups(treeUri);
  }

  Future<void> _pruneBackups(String treeUri) async {
    try {
      final files = await saf.listFiles(treeUri);
      final backups = files
          .where((f) =>
              !f.isDir &&
              f.path.startsWith('$backupDir/') &&
              f.name.endsWith('.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path)); // timestamped => sortable
      if (backups.length <= _maxBackups) return;
      for (final old in backups.take(backups.length - _maxBackups)) {
        await saf.deleteFile(treeUri, old.path);
      }
    } catch (_) {
      // Pruning is best-effort; never block a save because of it.
    }
  }
}
