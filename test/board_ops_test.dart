import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_core/kanban_core.dart';
import 'package:todo_md_app/src/providers/board_ops.dart';

const _base = '''---

kanban-plugin: board

---

## Doing

- [ ] **Card A**
  #Work
- [ ] **Card B**
  #Home


## Done

- [ ] **Card C** ^c1d2e3


%% kanban:settings
```
{"kanban-plugin":"board"}
```
%%
''';

void main() {
  group('auto-merge (op replay onto a freshly re-read board)', () {
    test('toggle merges with an unrelated external change', () {
      final mine = KanbanBoard.parse(_base);
      final cardA = mine.lanes[0].cards[0];
      final op = ToggleCardOp.of(mine, cardA);

      // Obsidian re-wrote the file, changing a *different* card.
      final theirs = KanbanBoard.parse(_base.replaceAll('#Home', '#Family'));
      expect(op.apply(theirs), isTrue);

      final merged = theirs.serialize();
      expect(merged, contains('- [x] **Card A**')); // my toggle
      expect(merged, contains('#Family')); // their change preserved
    });

    test('move merges with an unrelated external change', () {
      final mine = KanbanBoard.parse(_base);
      final cardA = mine.lanes[0].cards[0];
      final done = mine.lanes[1];
      final op = MoveCardOp.of(mine, cardA, done, -1);

      final theirs =
          KanbanBoard.parse(_base.replaceAll('**Card B**', '**Card B!**'));
      expect(op.apply(theirs), isTrue);

      final reparsed = KanbanBoard.parse(theirs.serialize());
      expect(reparsed.lanes[0].cards.map((c) => c.title),
          isNot(contains('**Card A**'))); // left Doing
      expect(reparsed.lanes[1].cards.map((c) => c.title),
          contains('**Card A**')); // arrived in Done
      expect(theirs.serialize(), contains('**Card B!**')); // their change kept
    });

    test('block-id anchor still locates a card whose text changed', () {
      final mine = KanbanBoard.parse(_base);
      final cardC = mine.lanes[1].cards[0];
      expect(cardC.blockId, 'c1d2e3');
      final op = ToggleCardOp.of(mine, cardC);

      // Obsidian changed Card C's text but kept its block id.
      final theirs = KanbanBoard.parse(
          _base.replaceAll('**Card C**', '**Card C renamed**'));
      expect(op.apply(theirs), isTrue);
      expect(theirs.serialize(), contains('- [x] **Card C renamed**'));
    });

    test('returns false (genuine conflict) when the same card changed', () {
      final mine = KanbanBoard.parse(_base);
      final cardA = mine.lanes[0].cards[0];
      final op = ToggleCardOp.of(mine, cardA);

      // Obsidian changed exactly the card I edited (no block id to anchor on).
      final theirs = KanbanBoard.parse(
          _base.replaceAll('**Card A**', '**Card A changed**'));
      expect(op.apply(theirs), isFalse);
    });

    test('add merges by appending to the named lane', () {
      final op = AddCardOp(laneTitle: 'Doing', title: 'New task', tags: ['Inbox']);
      final theirs = KanbanBoard.parse(_base.replaceAll('#Home', '#Family'));
      expect(op.apply(theirs), isTrue);

      final reparsed = KanbanBoard.parse(theirs.serialize());
      expect(reparsed.lanes[0].cards.map((c) => c.title),
          contains('New task'));
      expect(theirs.serialize(), contains('#Family'));
    });
  });
}
