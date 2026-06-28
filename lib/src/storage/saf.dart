import 'package:flutter/services.dart';

/// A file entry inside the picked vault tree.
class SafFile {
  const SafFile({required this.path, required this.name, required this.isDir});

  /// Path relative to the vault root, using `/` separators.
  final String path;
  final String name;
  final bool isDir;
}

/// Dart wrapper around the Android Storage Access Framework, implemented by a
/// platform [MethodChannel] in `MainActivity.kt`.
///
/// The app asks the user once to grant access to their Obsidian vault folder
/// (`ACTION_OPEN_DOCUMENT_TREE`). Android returns a tree URI for which we take a
/// *persistable* permission, so reads/writes keep working across app restarts.
class SafService {
  const SafService();

  static const MethodChannel _channel =
      MethodChannel('de.clausen.todo_md_app/saf');

  /// Prompts the user to pick their vault folder. Returns the persisted tree
  /// URI, or null if the user cancelled.
  Future<String?> pickVault() async {
    return _channel.invokeMethod<String>('pickVault');
  }

  /// Whether we still hold a persisted permission for [treeUri].
  Future<bool> hasAccess(String treeUri) async {
    final ok = await _channel
        .invokeMethod<bool>('hasAccess', {'tree': treeUri});
    return ok ?? false;
  }

  /// The display name of the vault folder (used as the obsidian:// vault name).
  Future<String?> vaultName(String treeUri) {
    return _channel.invokeMethod<String>('vaultName', {'tree': treeUri});
  }

  /// Reads a UTF-8 file at [relativePath] within the vault. Throws a
  /// [PlatformException] with code `not_found` if it does not exist.
  Future<String> readFile(String treeUri, String relativePath) async {
    final content = await _channel.invokeMethod<String>(
        'readFile', {'tree': treeUri, 'path': relativePath});
    return content ?? '';
  }

  /// Writes [content] (UTF-8) to [relativePath], creating the file and any
  /// missing parent folders.
  Future<void> writeFile(
      String treeUri, String relativePath, String content) async {
    await _channel.invokeMethod<void>('writeFile',
        {'tree': treeUri, 'path': relativePath, 'content': content});
  }

  /// Whether [relativePath] exists within the vault.
  Future<bool> exists(String treeUri, String relativePath) async {
    final ok = await _channel.invokeMethod<bool>(
        'exists', {'tree': treeUri, 'path': relativePath});
    return ok ?? false;
  }

  /// Deletes [relativePath] if it exists.
  Future<void> deleteFile(String treeUri, String relativePath) async {
    await _channel
        .invokeMethod<void>('deleteFile', {'tree': treeUri, 'path': relativePath});
  }

  /// Lists every file/folder in the vault tree (recursive). Used by the link
  /// resolver and by backup pruning.
  Future<List<SafFile>> listFiles(String treeUri) async {
    final raw = await _channel
        .invokeMethod<List<Object?>>('listFiles', {'tree': treeUri});
    if (raw == null) return const [];
    return raw.map((e) {
      final m = (e as Map).cast<Object?, Object?>();
      return SafFile(
        path: m['path'] as String,
        name: m['name'] as String,
        isDir: (m['isDir'] as bool?) ?? false,
      );
    }).toList(growable: false);
  }
}
