import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/settings_provider.dart';
import '../storage/saf.dart';

/// Read-only preview of a vault note, with a fallback to open it in Obsidian.
class NoteViewerScreen extends ConsumerStatefulWidget {
  const NoteViewerScreen({
    super.key,
    required this.treeUri,
    required this.file,
    required this.vaultName,
  });

  final String treeUri;
  final SafFile file;
  final String? vaultName;

  @override
  ConsumerState<NoteViewerScreen> createState() => _NoteViewerScreenState();
}

class _NoteViewerScreenState extends ConsumerState<NoteViewerScreen> {
  late Future<String> _content;

  bool get _isMarkdown => widget.file.name.toLowerCase().endsWith('.md');

  @override
  void initState() {
    super.initState();
    final saf = ref.read(safServiceProvider);
    _content =
        _isMarkdown ? saf.readFile(widget.treeUri, widget.file.path) : Future.value('');
  }

  Future<void> _openInObsidian() async {
    final vault = widget.vaultName;
    final path = widget.file.path;
    final fileParam = Uri.encodeComponent(path);
    final vaultParam = vault == null ? '' : 'vault=${Uri.encodeComponent(vault)}&';
    final uri = Uri.parse('obsidian://open?${vaultParam}file=$fileParam');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obsidian konnte nicht geöffnet werden.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'In Obsidian öffnen',
            onPressed: _openInObsidian,
          ),
        ],
      ),
      body: _isMarkdown ? _buildMarkdown() : _buildUnsupported(),
    );
  }

  Widget _buildMarkdown() {
    return FutureBuilder<String>(
      future: _content,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _error('Notiz konnte nicht geladen werden:\n${snap.error}');
        }
        final data = snap.data ?? '';
        return MarkdownWidget(
          data: data.isEmpty ? '_Leere Notiz._' : data,
          padding: const EdgeInsets.all(16),
        );
      },
    );
  }

  Widget _buildUnsupported() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Diese Datei (${widget.file.name}) kann in der App nicht '
              'angezeigt werden.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openInObsidian,
              icon: const Icon(Icons.open_in_new),
              label: const Text('In Obsidian öffnen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _error(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}
