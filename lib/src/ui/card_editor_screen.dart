import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_core/kanban_core.dart';

import '../providers/board_ops.dart';
import '../providers/board_provider.dart';
import 'card_inline.dart';
import 'save_helpers.dart';

/// Hybrid card editor: structured fields (done, title, date, tags, subtasks,
/// lane) on one tab, and a verbatim raw-markdown editor on the other. Edits are
/// made to a working copy and only committed (with backup + conflict handling)
/// when the user saves.
class CardEditorScreen extends ConsumerStatefulWidget {
  const CardEditorScreen({
    super.key,
    required this.card,
    required this.currentLane,
  });

  final KanbanCard card;
  final KanbanLane currentLane;

  @override
  ConsumerState<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends ConsumerState<CardEditorScreen>
    with SingleTickerProviderStateMixin {
  late final KanbanCard _work;
  late final TabController _tab;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _rawCtrl;
  final _newSubtaskCtrl = TextEditingController();
  late KanbanLane _lane;

  @override
  void initState() {
    super.initState();
    _work = KanbanCard(List<String>.of(widget.card.lines))
      ..eol = widget.card.eol
      ..indentUnit = widget.card.indentUnit;
    _lane = widget.currentLane;
    _titleCtrl = TextEditingController(text: _work.title);
    _rawCtrl = TextEditingController(text: _work.serialize());
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(_onTabChanged);
  }

  int _lastTab = 0;
  void _onTabChanged() {
    if (_tab.indexIsChanging) return;
    if (_lastTab == 1 && _tab.index == 0) {
      // Leaving raw -> adopt raw text into the working copy.
      _work.replaceRaw(_rawCtrl.text);
      _titleCtrl.text = _work.title;
      setState(() {});
    } else if (_lastTab == 0 && _tab.index == 1) {
      // Entering raw -> reflect current field edits.
      _rawCtrl.text = _work.serialize();
    }
    _lastTab = _tab.index;
  }

  @override
  void dispose() {
    _tab.dispose();
    _titleCtrl.dispose();
    _rawCtrl.dispose();
    _newSubtaskCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_tab.index == 1) {
      _work.replaceRaw(_rawCtrl.text);
    } else {
      _work.title = _titleCtrl.text;
    }
    final newText = _work.serialize();
    final laneChanged = !identical(_lane, widget.currentLane);
    final board = ref.read(boardProvider).valueOrNull?.board;
    if (board == null) return;
    final op = ReplaceCardOp(
      anchor: CardAnchor.of(board, widget.card),
      newRawText: newText,
      targetLaneTitle: laneChanged ? _lane.title : null,
    );
    final ok = await runBoardEdit(ref, context, op);
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Karte löschen?'),
        content: const Text('Die Karte wird aus dem Board entfernt.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Löschen')),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    final board = ref.read(boardProvider).valueOrNull?.board;
    if (board == null) return;
    final ok =
        await runBoardEdit(ref, context, DeleteCardOp.of(board, widget.card));
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karte bearbeiten'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Felder'),
            Tab(text: 'Rohtext'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Löschen',
            onPressed: _delete,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Speichern',
            onPressed: _save,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildFields(),
          _buildRaw(),
        ],
      ),
    );
  }

  Widget _buildFields() {
    final subtasks = _work.subtasks;
    final tags = _work.tags;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Erledigt'),
          value: _work.checked,
          onChanged: (v) => setState(() => _work.checked = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleCtrl,
          maxLines: null,
          decoration: const InputDecoration(
            labelText: 'Titel',
            helperText: 'Markdown erlaubt (z. B. **fett**, [[Link]])',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _work.title = v,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<KanbanLane>(
          initialValue: _lane,
          decoration: const InputDecoration(
            labelText: 'Liste',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final lane in _lanes())
              DropdownMenuItem(
                value: lane,
                child: Text(stripInlineMarkdown(lane.title),
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (lane) => setState(() => _lane = lane ?? _lane),
        ),
        const SizedBox(height: 16),
        _dateRow(),
        const SizedBox(height: 16),
        Text('Tags', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final tag in tags)
              InputChip(
                label: Text('#$tag'),
                onDeleted: () => setState(() => _work.removeTag(tag)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Tag'),
              onPressed: _addTagDialog,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Unteraufgaben', style: Theme.of(context).textTheme.titleSmall),
        for (final s in subtasks)
          Row(
            children: [
              Checkbox(
                value: s.checked,
                onChanged: (_) =>
                    setState(() => _work.toggleSubtask(s.lineIndex)),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _editSubtaskDialog(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      s.text,
                      style: TextStyle(
                        decoration:
                            s.checked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () =>
                    setState(() => _work.removeSubtask(s.lineIndex)),
              ),
            ],
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newSubtaskCtrl,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addSubtask(),
                decoration: const InputDecoration(
                  hintText: 'Neue Unteraufgabe',
                  isDense: true,
                ),
              ),
            ),
            IconButton(onPressed: _addSubtask, icon: const Icon(Icons.add)),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Tipp: Beschreibung, Links und alles Weitere kannst du im Tab '
          '„Rohtext" direkt bearbeiten. Unbekannte Inhalte bleiben dabei '
          'unverändert erhalten.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  List<KanbanLane> _lanes() {
    final session = ref.read(boardProvider).valueOrNull;
    return session?.board.lanes ?? [widget.currentLane];
  }

  Widget _dateRow() {
    final date = _work.date;
    return Row(
      children: [
        Text('Datum', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.event),
          label: Text(date ?? 'Kein Datum'),
          onPressed: _pickDate,
        ),
        if (date != null)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() => _work.setDate(null)),
          ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final current = _work.date;
    final initial =
        current != null ? DateTime.tryParse(current) ?? DateTime.now() : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 6),
    );
    if (picked != null) {
      final iso =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() => _work.setDate(iso));
    }
  }

  void _addSubtask() {
    final text = _newSubtaskCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _work.addSubtask(text);
      _newSubtaskCtrl.clear();
    });
  }

  Future<void> _addTagDialog() async {
    final ctrl = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tag hinzufügen'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(prefixText: '#'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('OK')),
        ],
      ),
    );
    if (tag != null && tag.trim().isNotEmpty) {
      setState(() => _work.addTag(tag.trim()));
    }
  }

  Future<void> _editSubtaskDialog(KanbanSubtask s) async {
    final ctrl = TextEditingController(text: s.text);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unteraufgabe bearbeiten'),
        content: TextField(controller: ctrl, autofocus: true, maxLines: null),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('OK')),
        ],
      ),
    );
    if (text != null) {
      setState(() => _work.setSubtaskText(s.lineIndex, text));
    }
  }

  Widget _buildRaw() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _rawCtrl,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
    );
  }
}
