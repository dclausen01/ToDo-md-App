import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/board_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/vault_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final board = ref.watch(boardProvider).valueOrNull;
    final laneTitles =
        board?.board.lanes.map((l) => l.title).toList() ?? const <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Vault'),
            subtitle: Text(settings?.vaultName ?? settings?.vaultTreeUri ?? '—'),
            trailing: TextButton(
              onPressed: () => _changeVault(context, ref),
              child: const Text('Ändern'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Board-Datei'),
            subtitle: Text(settings?.boardPath ?? 'ToDo.md'),
            trailing: TextButton(
              onPressed: () => _editBoardPath(context, ref, settings?.boardPath),
              child: const Text('Ändern'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: const Text('Standard-Liste für neue Aufgaben'),
            subtitle: Text(settings?.defaultLaneTitle ?? 'Erste Liste'),
            trailing: laneTitles.isEmpty
                ? null
                : DropdownButton<String>(
                    value: laneTitles.contains(settings?.defaultLaneTitle)
                        ? settings?.defaultLaneTitle
                        : null,
                    hint: const Text('Erste'),
                    onChanged: (value) =>
                        ref.read(settingsProvider.notifier).setDefaultLane(value),
                    items: [
                      for (final t in laneTitles)
                        DropdownMenuItem(
                          value: t,
                          child: Text(t, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Sicherung'),
            subtitle: Text(
              'Vor jedem Speichern wird automatisch ein Backup der Datei im '
              'Ordner .todo-md-app-backups im Vault angelegt (die letzten 12 '
              'Versionen).',
            ),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }

  Future<void> _changeVault(BuildContext context, WidgetRef ref) async {
    final saf = ref.read(safServiceProvider);
    final uri = await saf.pickVault();
    if (uri == null) return;
    final name = await saf.vaultName(uri);
    await ref.read(settingsProvider.notifier).setVault(treeUri: uri, name: name);
    ref.invalidate(vaultFilesProvider);
    ref.invalidate(boardProvider);
  }

  Future<void> _editBoardPath(
      BuildContext context, WidgetRef ref, String? current) async {
    final ctrl = TextEditingController(text: current ?? 'ToDo.md');
    final path = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Board-Datei (Pfad im Vault)'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'ToDo.md'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Speichern')),
        ],
      ),
    );
    if (path != null && path.trim().isNotEmpty) {
      await ref.read(settingsProvider.notifier).setBoardPath(path.trim());
      ref.invalidate(boardProvider);
    }
  }
}
