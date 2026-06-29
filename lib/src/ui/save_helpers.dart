import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/board_ops.dart';
import '../providers/board_provider.dart';
import '../storage/board_repository.dart';

/// Applies [op] to the board and persists it. External changes (e.g. Obsidian
/// re-writing the file) are auto-merged inside [BoardController.applyOp]; only a
/// genuine same-card conflict reaches the reload/overwrite prompt here. Returns
/// true if the edit ended up saved.
Future<bool> runBoardEdit(
  WidgetRef ref,
  BuildContext context,
  BoardOp op,
) async {
  final controller = ref.read(boardProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await controller.applyOp(op);
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
      SnackBar(
        content: Text('Speichern fehlgeschlagen: $e'),
        duration: const Duration(seconds: 10),
      ),
    );
    return false;
  }
}
