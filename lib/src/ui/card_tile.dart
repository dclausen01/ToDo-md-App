import 'package:flutter/material.dart';
import 'package:kanban_core/kanban_core.dart';

import 'card_inline.dart';

/// A single Kanban card rendered for the board.
class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.card,
    required this.onToggle,
    required this.onTap,
    required this.onLinkTap,
    this.showCheckbox = true,
  });

  final KanbanCard card;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final void Function(CardLink link) onLinkTap;
  final bool showCheckbox;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checked = card.checked;
    final title = stripInlineMarkdown(card.title);
    final preview = _previewText();
    final subtasks = card.subtasks;
    final links = extractLinks(card.lines.join());
    final tags = card.tags;
    final date = card.date;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showCheckbox)
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: Checkbox(
                        value: checked,
                        onChanged: (_) => onToggle(),
                      ),
                    )
                  else
                    const SizedBox(width: 4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        title.isEmpty ? '(ohne Titel)' : title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          decoration:
                              checked ? TextDecoration.lineThrough : null,
                          color: checked
                              ? theme.disabledColor
                              : theme.textTheme.titleSmall?.color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (preview.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 38, top: 2),
                  child: Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ),
              if (subtasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 38, top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_box_outlined,
                          size: 15, color: theme.hintColor),
                      const SizedBox(width: 4),
                      Text(
                        '${subtasks.where((s) => s.checked).length}/${subtasks.length}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
              if (date != null || tags.isNotEmpty || links.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 38, top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (date != null) _DateChip(date: date),
                      for (final tag in tags) _TagChip(tag: tag),
                      for (final link in links)
                        _LinkChip(link: link, onTap: () => onLinkTap(link)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _previewText() {
    for (final line in card.noteLines) {
      final stripped = stripInlineMarkdown(line);
      // Skip lines that are purely metadata (tags/dates/links/separators).
      final meta = RegExp(r'^[\s#@*\-_🔗{}\d:]*$').hasMatch(stripped) ||
          stripped == '***' ||
          stripped == '---';
      if (stripped.isNotEmpty && !meta) return stripped;
    }
    return '';
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});
  final String date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event,
              size: 13, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 3),
          Text(date,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSecondaryContainer)),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('#$tag',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.link, required this.onTap});
  final CardLink link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (link.kind) {
      CardLinkKind.url => Icons.link,
      CardLinkKind.embed => Icons.attachment,
      CardLinkKind.wiki => Icons.description_outlined,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: theme.colorScheme.primary),
            const SizedBox(width: 3),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                link.display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
