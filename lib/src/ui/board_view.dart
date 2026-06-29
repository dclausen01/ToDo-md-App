import 'package:flutter/material.dart';
import 'package:kanban_core/kanban_core.dart';

import '../providers/filter_provider.dart';
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
    required this.onMoveToTop,
    required this.onMoveToBottom,
    required this.onDeleteCard,
    required this.onMoveToDone,
    required this.onAddToLane,
    this.doneLane,
    this.filter = const BoardFilter(),
  });

  final KanbanBoard board;
  final void Function(KanbanCard card) onToggleCard;
  final void Function(KanbanCard card) onOpenCard;
  final void Function(KanbanCard card, CardLink link) onLinkTap;

  /// Move [card] into [target] at card-position [index] (append if negative).
  final void Function(KanbanCard card, KanbanLane target, int index)
      onMoveCard;
  final void Function(KanbanCard card) onMoveToTop;
  final void Function(KanbanCard card) onMoveToBottom;
  final void Function(KanbanCard card) onDeleteCard;
  final void Function(KanbanCard card) onMoveToDone;

  /// The resolved "done" lane, or null if the board has none.
  final KanbanLane? doneLane;
  final void Function(KanbanLane lane) onAddToLane;
  final BoardFilter filter;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: board.lanes.length,
      itemBuilder: (context, i) => _LaneColumn(
        lane: board.lanes[i],
        filter: filter,
        doneLane: doneLane,
        onToggleCard: onToggleCard,
        onOpenCard: onOpenCard,
        onLinkTap: onLinkTap,
        onMoveCard: onMoveCard,
        onMoveToTop: onMoveToTop,
        onMoveToBottom: onMoveToBottom,
        onDeleteCard: onDeleteCard,
        onMoveToDone: onMoveToDone,
        onAddToLane: onAddToLane,
      ),
    );
  }
}

class _LaneColumn extends StatelessWidget {
  const _LaneColumn({
    required this.lane,
    required this.filter,
    required this.doneLane,
    required this.onToggleCard,
    required this.onOpenCard,
    required this.onLinkTap,
    required this.onMoveCard,
    required this.onMoveToTop,
    required this.onMoveToBottom,
    required this.onDeleteCard,
    required this.onMoveToDone,
    required this.onAddToLane,
  });

  final KanbanLane lane;
  final BoardFilter filter;
  final KanbanLane? doneLane;
  final void Function(KanbanCard card) onToggleCard;
  final void Function(KanbanCard card) onOpenCard;
  final void Function(KanbanCard card, CardLink link) onLinkTap;
  final void Function(KanbanCard card, KanbanLane target, int index) onMoveCard;
  final void Function(KanbanCard card) onMoveToTop;
  final void Function(KanbanCard card) onMoveToBottom;
  final void Function(KanbanCard card) onDeleteCard;
  final void Function(KanbanCard card) onMoveToDone;
  final void Function(KanbanLane lane) onAddToLane;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allCards = lane.cards;
    final cards =
        filter.isActive ? allCards.where(filter.matches).toList() : allCards;

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
                Text(
                    filter.isActive
                        ? '${cards.length}/${allCards.length}'
                        : '${allCards.length}',
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
                      doneLane: doneLane,
                      onToggleCard: onToggleCard,
                      onOpenCard: onOpenCard,
                      onLinkTap: onLinkTap,
                      onMoveCard: onMoveCard,
                      onMoveToTop: onMoveToTop,
                      onMoveToBottom: onMoveToBottom,
                      onDeleteCard: onDeleteCard,
                      onMoveToDone: onMoveToDone,
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
    required this.doneLane,
    required this.onToggleCard,
    required this.onOpenCard,
    required this.onLinkTap,
    required this.onMoveCard,
    required this.onMoveToTop,
    required this.onMoveToBottom,
    required this.onDeleteCard,
    required this.onMoveToDone,
  });

  final KanbanCard card;
  final KanbanLane lane;
  final KanbanLane? doneLane;
  final void Function(KanbanCard card) onToggleCard;
  final void Function(KanbanCard card) onOpenCard;
  final void Function(KanbanCard card, CardLink link) onLinkTap;
  final void Function(KanbanCard card, KanbanLane target, int index) onMoveCard;
  final void Function(KanbanCard card) onMoveToTop;
  final void Function(KanbanCard card) onMoveToBottom;
  final void Function(KanbanCard card) onDeleteCard;
  final void Function(KanbanCard card) onMoveToDone;

  @override
  Widget build(BuildContext context) {
    // Offer "move to done" only when there is a done lane and this card isn't
    // already in it.
    final showDone = doneLane != null && !identical(lane, doneLane);
    final tile = CardTile(
      card: card,
      onToggle: () => onToggleCard(card),
      onTap: () => onOpenCard(card),
      onLinkTap: (link) => onLinkTap(card, link),
      onMoveToTop: () => onMoveToTop(card),
      onMoveToBottom: () => onMoveToBottom(card),
      onDelete: () => onDeleteCard(card),
      onMoveToDone: showDone ? () => onMoveToDone(card) : null,
      doneLabel: showDone ? stripInlineMarkdown(doneLane!.title) : null,
    );

    return DragTarget<_CardDrag>(
      onWillAcceptWithDetails: (d) => !identical(d.data.card, card),
      // Use the card's real position in the full lane so drops land correctly
      // even when the view is filtered.
      onAcceptWithDetails: (d) =>
          onMoveCard(d.data.card, lane, lane.cards.indexOf(card)),
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
