import 'package:flutter/material.dart';
import 'package:kanban_core/kanban_core.dart';

import 'card_inline.dart';

class QuickAddResult {
  QuickAddResult({
    required this.title,
    required this.lane,
    this.date,
    this.tags = const [],
  });

  final String title;
  final KanbanLane lane;
  final String? date;
  final List<String> tags;
}

/// Bottom sheet for quickly adding a card: title, target lane, optional date
/// and tags.
class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({
    super.key,
    required this.lanes,
    required this.initialLane,
  });

  final List<KanbanLane> lanes;
  final KanbanLane initialLane;

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _titleCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  late KanbanLane _lane;
  String? _date;
  final List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _lane = widget.initialLane;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _date =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  void _addTag() {
    final raw = _tagCtrl.text.trim().replaceAll('#', '');
    if (raw.isEmpty) return;
    setState(() {
      if (!_tags.contains(raw)) _tags.add(raw);
      _tagCtrl.clear();
    });
  }

  void _submit() {
    Navigator.pop(
      context,
      QuickAddResult(
        title: _titleCtrl.text,
        lane: _lane,
        date: _date,
        tags: List.of(_tags),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Neue Aufgabe',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Titel',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<KanbanLane>(
            initialValue: _lane,
            decoration: const InputDecoration(
              labelText: 'Liste',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final lane in widget.lanes)
                DropdownMenuItem(
                  value: lane,
                  child: Text(stripInlineMarkdown(lane.title),
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (lane) => setState(() => _lane = lane ?? _lane),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagCtrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addTag(),
                  decoration: const InputDecoration(
                    labelText: 'Tag hinzufügen',
                    prefixText: '#',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(onPressed: _addTag, icon: const Icon(Icons.add)),
            ],
          ),
          if (_tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final tag in _tags)
                    InputChip(
                      label: Text('#$tag'),
                      onDeleted: () => setState(() => _tags.remove(tag)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event),
                label: Text(_date ?? 'Datum'),
              ),
              if (_date != null)
                IconButton(
                  onPressed: () => setState(() => _date = null),
                  icon: const Icon(Icons.clear),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _submit,
                child: const Text('Hinzufügen'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
