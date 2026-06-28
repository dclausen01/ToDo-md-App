import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_core/kanban_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/board_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/vault_provider.dart';
import 'board_view.dart';
import 'card_editor_screen.dart';
import 'card_inline.dart';
import 'note_viewer_screen.dart';
import 'quick_add_sheet.dart';
import 'save_helpers.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    return settingsAsync.when(
      loading: () => const _Loading(),
      error: (e, _) => _ErrorScaffold(message: 'Einstellungen: $e'),
      data: (settings) {
        if (!settings.isConfigured) {
          return const _OnboardingScreen();
        }
        return const _BoardScreen();
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      );
}

class _OnboardingScreen extends ConsumerWidget {
  const _OnboardingScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('ToDo.md')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_open, size: 64),
              const SizedBox(height: 16),
              Text('Vault auswählen',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Wähle den Ordner deines Obsidian-Vaults. Die App liest und '
                'bearbeitet dann die Datei ToDo.md direkt darin.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.folder),
                label: const Text('Vault-Ordner wählen'),
                onPressed: () => _pickVault(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickVault(BuildContext context, WidgetRef ref) async {
    final saf = ref.read(safServiceProvider);
    final uri = await saf.pickVault();
    if (uri == null) return;
    final name = await saf.vaultName(uri);
    await ref.read(settingsProvider.notifier).setVault(treeUri: uri, name: name);
  }
}

class _BoardScreen extends ConsumerWidget {
  const _BoardScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(boardProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings?.boardPath ?? 'ToDo.md'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Neu laden',
            onPressed: () => ref.read(boardProvider.notifier).reload(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Einstellungen',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: boardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _BoardError(message: '$e'),
        data: (session) {
          if (session == null) {
            return const Center(child: Text('Kein Board geladen.'));
          }
          return BoardView(
            board: session.board,
            onToggleCard: (card) =>
                runBoardEdit(ref, context, (_) => card.toggleChecked()),
            onOpenCard: (card) => _openCard(context, ref, session, card),
            onLinkTap: (card, link) => _handleLink(context, ref, link),
            onMoveCard: (card, target, index) => runBoardEdit(
                ref, context, (b) => b.moveCard(card, target, index: index)),
            onAddToLane: (lane) => _quickAdd(context, ref, session, lane),
          );
        },
      ),
      floatingActionButton: boardAsync.valueOrNull == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  _quickAdd(context, ref, boardAsync.value!, null),
              icon: const Icon(Icons.add),
              label: const Text('Aufgabe'),
            ),
    );
  }

  KanbanLane _defaultLane(BoardSession session, AppSettings? settings) {
    final title = settings?.defaultLaneTitle;
    if (title != null) {
      for (final lane in session.board.lanes) {
        if (lane.title == title) return lane;
      }
    }
    return session.board.lanes.first;
  }

  Future<void> _quickAdd(BuildContext context, WidgetRef ref,
      BoardSession session, KanbanLane? lane) async {
    if (session.board.lanes.isEmpty) return;
    final settings = ref.read(settingsProvider).valueOrNull;
    final target = lane ?? _defaultLane(session, settings);
    final result = await showModalBottomSheet<QuickAddResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickAddSheet(
        lanes: session.board.lanes,
        initialLane: target,
      ),
    );
    if (result == null || result.title.trim().isEmpty) return;
    if (!context.mounted) return;
    await runBoardEdit(
      ref,
      context,
      (b) => b.addCard(
        result.lane,
        title: result.title.trim(),
        tags: result.tags,
        date: result.date,
      ),
    );
  }

  Future<void> _openCard(BuildContext context, WidgetRef ref,
      BoardSession session, KanbanCard card) async {
    final lane = session.board.laneOf(card);
    if (lane == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardEditorScreen(card: card, currentLane: lane),
      ),
    );
  }

  Future<void> _handleLink(
      BuildContext context, WidgetRef ref, CardLink link) async {
    if (link.kind == CardLinkKind.url) {
      final uri = Uri.tryParse(link.target);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    // Wiki / embed: resolve within the vault.
    final settings = ref.read(settingsProvider).valueOrNull;
    final resolver = ref.read(linkResolverProvider);
    final file = resolver.resolve(link.target);
    if (file == null) {
      if (!context.mounted) return;
      _offerObsidianFallback(context, settings, link.target);
      return;
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteViewerScreen(
          treeUri: settings!.vaultTreeUri!,
          file: file,
          vaultName: settings.vaultName,
        ),
      ),
    );
  }

  void _offerObsidianFallback(
      BuildContext context, AppSettings? settings, String target) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notiz „$target" nicht im Vault gefunden.'),
        action: SnackBarAction(
          label: 'In Obsidian',
          onPressed: () {
            final vault = settings?.vaultName;
            final vaultParam =
                vault == null ? '' : 'vault=${Uri.encodeComponent(vault)}&';
            final uri = Uri.parse(
                'obsidian://open?${vaultParam}file=${Uri.encodeComponent(target)}');
            launchUrl(uri, mode: LaunchMode.externalApplication);
          },
        ),
      ),
    );
  }
}

class _BoardError extends ConsumerWidget {
  const _BoardError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text('Board konnte nicht geladen werden:\n$message',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                FilledButton(
                  onPressed: () => ref.read(boardProvider.notifier).reload(),
                  child: const Text('Erneut versuchen'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen()),
                  ),
                  child: const Text('Einstellungen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
