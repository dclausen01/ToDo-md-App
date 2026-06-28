import 'package:flutter_test/flutter_test.dart';
import 'package:todo_md_app/src/storage/board_repository.dart';
import 'package:todo_md_app/src/storage/saf.dart';

/// In-memory fake of [SafService]; can simulate a provider that refuses to
/// create the hidden backup folder.
class _FakeSaf extends SafService {
  _FakeSaf({this.failBackups = false});

  final bool failBackups;
  final Map<String, String> files = {};

  @override
  Future<bool> exists(String treeUri, String path) async =>
      files.containsKey(path);

  @override
  Future<String> readFile(String treeUri, String path) async =>
      files[path] ?? (throw Exception('not_found: $path'));

  @override
  Future<void> writeFile(String treeUri, String path, String content) async {
    if (failBackups && path.startsWith('${BoardRepository.backupDir}/')) {
      throw Exception('provider refused hidden folder');
    }
    files[path] = content;
  }

  @override
  Future<void> deleteFile(String treeUri, String path) async =>
      files.remove(path);

  @override
  Future<List<SafFile>> listFiles(String treeUri) async => files.keys
      .map((k) => SafFile(path: k, name: k, isDir: false))
      .toList();
}

void main() {
  group('BoardRepository.save', () {
    test('writes the board even when the backup step fails', () async {
      final saf = _FakeSaf(failBackups: true)..files['ToDo.md'] = 'old';
      final repo = BoardRepository(saf);

      await repo.save('tree', 'ToDo.md', 'new', loadedContent: 'old');

      // The real file must be saved regardless of the backup failure.
      expect(saf.files['ToDo.md'], 'new');
      expect(
        saf.files.keys.any((k) => k.startsWith('${BoardRepository.backupDir}/')),
        isFalse,
      );
    });

    test('creates a backup of the previous content when possible', () async {
      final saf = _FakeSaf()..files['ToDo.md'] = 'old';
      final repo = BoardRepository(saf);

      await repo.save('tree', 'ToDo.md', 'new', loadedContent: 'old');

      expect(saf.files['ToDo.md'], 'new');
      final backups = saf.files.entries
          .where((e) => e.key.startsWith('${BoardRepository.backupDir}/'))
          .toList();
      expect(backups.length, 1);
      expect(backups.single.value, 'old');
    });

    test('throws on external change and does not overwrite', () async {
      final saf = _FakeSaf()..files['ToDo.md'] = 'theirs';
      final repo = BoardRepository(saf);

      await expectLater(
        repo.save('tree', 'ToDo.md', 'mine', loadedContent: 'base'),
        throwsA(isA<ExternalChangeException>()),
      );
      expect(saf.files['ToDo.md'], 'theirs');
    });

    test('force overwrites despite external change', () async {
      final saf = _FakeSaf()..files['ToDo.md'] = 'theirs';
      final repo = BoardRepository(saf);

      await repo.save('tree', 'ToDo.md', 'mine',
          loadedContent: 'base', force: true);

      expect(saf.files['ToDo.md'], 'mine');
    });
  });
}
