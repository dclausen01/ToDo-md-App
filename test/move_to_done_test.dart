import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_core/kanban_core.dart';
import 'package:todo_md_app/src/providers/board_ops.dart';

const _board = '''---

kanban-plugin: board

---

## Doing

- [ ] **Task A**
  #Work
- [ ] **Task B**

## --> done

- [ ] **Old done thing**


%% kanban:settings
```
{"kanban-plugin":"board"}
```
%%
''';

void main() {
  test('MoveToDoneOp checks the card and moves it to the top of done', () {
    final board = KanbanBoard.parse(_board);
    final taskA = board.lanes[0].cards[0];
    final done = board.lanes[1];
    expect(taskA.checked, isFalse);

    final op = MoveToDoneOp.of(board, taskA, done);
    expect(op.apply(board), isTrue);

    final reparsed = KanbanBoard.parse(board.serialize());
    // Gone from Doing.
    expect(reparsed.lanes[0].cards.map((c) => c.title),
        isNot(contains('**Task A**')));
    // Now first in done, and checked.
    final first = reparsed.lanes[1].cards.first;
    expect(first.title, '**Task A**');
    expect(first.checked, isTrue);
  });

  test('auto-merges onto a freshly re-read board', () {
    final mine = KanbanBoard.parse(_board);
    final taskA = mine.lanes[0].cards[0];
    final done = mine.lanes[1];
    final op = MoveToDoneOp.of(mine, taskA, done);

    // Obsidian changed an unrelated card meanwhile.
    final theirs = KanbanBoard.parse(_board.replaceAll('**Task B**', '**Task B!**'));
    expect(op.apply(theirs), isTrue);
    expect(theirs.serialize(), contains('- [x] **Task A**'));
    expect(theirs.serialize(), contains('**Task B!**'));
  });
}
