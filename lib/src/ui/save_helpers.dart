import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_core/kanban_core.dart';

import '../providers/board_provider.dart';
import '../storage/board_repository.dart';

/// Applies [action] to the board and persists it, handling the case where the
/// file changed on disk (e.g. edited in Obsidian) by asking the user whether to
/// overwrite or reload. Returns true if the edit ended up saved.
Future<bool> runBoardEdit(
  WidgetRef ref,
  BuildContext context,
  void Function(KanbanBoard board) action,
) async {
  final controller = ref.read(boardProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await controller.mutate(action);
    return true;
  } on ExternalChangeException {
    if (!context.mounted) return false;
    final overwrite = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Datei wurde extern geändert'),
        content: const Text(
          'Die ToDo-Datei wurde seit dem Laden verändert (z. B. in Obsidian). '
          'Möchtest du deine Änderung trotzdem speichern (überschreiben) oder '
          'die Datei neu laden und deine Änderung verwerfen?\n\n'
          'Vor dem Überschreiben wird ein Backup der Datei auf der Festplatte '
          'angelegt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Neu laden'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Überschreiben'),
          ),
        ],
      ),
    );
    if (overwrite == true) {
      await controller.forceSave();
      return true;
    } else {
      await controller.reload();
      return false;
    }
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
    );
    return false;
  }
}
