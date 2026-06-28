import 'package:flutter/material.dart';
import 'package:kanban_core/kanban_core.dart';

import 'card_inline.dart';
import 'card_tile.dart';

class _CardDrag {
  const _CardDrag(this.card, this.lane);
  final KanbanCard card;
  final KanbanLane lane;
}

/// Horizontal Kanban board: one scrollable column per lane, cards drag between
/// lanes via long-press.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.board,
    required this.onToggleCard,
    required this.onOpenCard,
    required this.onLinkTap,
    required this.onMoveCard,
    required this.onAddToLane,
  });

  final KanbanBoard board;
  final void Function(KanbanCard card) onToggleCard;
  final void Function(KanbanCard card) onOpenCard;
  final void Function(KanbanCard card, CardLink link) onLinkTap;

  /// Move [card] into [target] at card-position [index] (append if negative).
  final void Function(KanbanCard card, KanbanLane target, int index)
      onMoveCard;
  final void Function(KanbanLane lane) onAddToLane;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: board.lanes.length,
      itemBuilder: (context, i) => _LaneColumn(
        lane: board.lanes[i],
        onToggleCard: onToggleCard,
        onOpenCard: onOpenCard,
        onLinkTap: onLinkTap,
        onMoveCard: onMoveCard,
        onAddToLane: onAddToLane,
      ),
    );
  }
}

class _LaneColumn extends StatelessWidget {
  const _LaneColumn({
    required this.lane,
    required this.onToggleCard,
    required this.onOpenCard,
    required this.onLinkTap,
    required this.onMoveCard,
    required this.onAddToLane,
  });

  final KanbanLane lane;
  final void Function(KanbanCard card) onToggleCard;
  final void Function(KanbanCard card) onOpenCard;
  final void Function(KanbanCard card, CardLink link) onLinkTap;
  final void Function(KanbanCard card, KanbanLane target, int index) onMoveCard;
  final void Function(KanbanLane lane) onAddToLane;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = lane.cards;

    return Container(
      width: 300,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    stripInlineMarkdown(lane.title),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${cards.length}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.hintColor)),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'Karte hinzufügen',
                  onPressed: () => onAddToLane(lane),
                ),
              ],
            ),
          ),
          Expanded(
            child: DragTarget<_CardDrag>(
              onWillAcceptWithDetails: (d) => true,
              onAcceptWithDetails: (d) => onMoveCard(d.data.card, lane, -1),
              builder: (context, candidate, rejected) {
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: cards.length + 1,
                  itemBuilder: (context, index) {
                    if (index == cards.length) {
                      // Trailing drop zone (append to this lane).
                      return _DropGap(
                        active: candidate.isNotEmpty,
                        onAccept: (drag) => onMoveCard(drag.card, lane, -1),
                      );
                    }
                    final card = cards[index];
                    return _DraggableCard(
                      card: card,
                      lane: lane,
                      index: index,
                      onToggleCard: onToggleCard,
                      onOpenCard: onOpenCard,
                      onLinkTap: onLinkTap,
                      onMoveCard: onMoveCard,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggableCard extends StatelessWidget {
  const _DraggableCard({
    required this.card,
    required this.lane,
    required this.index,
    required this.onToggleCard,
    required this.onOpenCard,
    required this.onLinkTap,
    required this.onMoveCard,
  });

  final KanbanCard card;
  final KanbanLane lane;
  final int index;
  final void Function(KanbanCard card) onToggleCard;
  final void Function(KanbanCard card) onOpenCard;
  final void Function(KanbanCard card, CardLink link) onLinkTap;
  final void Function(KanbanCard card, KanbanLane target, int index) onMoveCard;

  @override
  Widget build(BuildContext context) {
    final tile = CardTile(
      card: card,
      onToggle: () => onToggleCard(card),
      onTap: () => onOpenCard(card),
      onLinkTap: (link) => onLinkTap(card, link),
    );

    return DragTarget<_CardDrag>(
      onWillAcceptWithDetails: (d) => !identical(d.data.card, card),
      onAcceptWithDetails: (d) => onMoveCard(d.data.card, lane, index),
      builder: (context, candidate, rejected) {
        return Column(
          children: [
            if (candidate.isNotEmpty)
              const _DropIndicator(),
            LongPressDraggable<_CardDrag>(
              data: _CardDrag(card, lane),
              feedback: Material(
                color: Colors.transparent,
                child: Opacity(
                  opacity: 0.9,
                  child: SizedBox(width: 280, child: tile),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.35, child: tile),
              child: tile,
            ),
          ],
        );
      },
    );
  }
}

class _DropGap extends StatelessWidget {
  const _DropGap({required this.active, required this.onAccept});
  final bool active;
  final void Function(_CardDrag drag) onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_CardDrag>(
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidate, rejected) => Container(
        height: candidate.isNotEmpty ? 60 : 40,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: candidate.isNotEmpty
            ? BoxDecoration(
                border: Border.all(
                    color: Theme.of(context).colorScheme.primary, width: 2),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
      ),
    );
  }
}

class _DropIndicator extends StatelessWidget {
  const _DropIndicator();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
