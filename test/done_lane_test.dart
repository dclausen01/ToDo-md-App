import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_core/kanban_core.dart';
import 'package:todo_md_app/src/ui/quick_add.dart';

const _board = '''---

kanban-plugin: board

---

## to do <--

- [ ] **A**

## --> done

- [ ] **B**


%% kanban:settings
```
{"kanban-plugin":"board"}
```
%%
''';

void main() {
  final board = KanbanBoard.parse(_board);

  test('auto-detects a lane whose title contains "done"', () {
    final lane = resolveDoneLane(board, null);
    expect(lane?.title, '--> done');
  });

  test('explicit configured title wins', () {
    final lane = resolveDoneLane(board, 'to do <--');
    expect(lane?.title, 'to do <--');
  });

  test('falls back to auto-detect when configured title is gone', () {
    final lane = resolveDoneLane(board, 'Nonexistent');
    expect(lane?.title, '--> done');
  });

  test('returns null when nothing matches', () {
    final plain = KanbanBoard.parse(
        '---\n\nkanban-plugin: board\n\n---\n\n## Inbox\n\n- [ ] x\n');
    expect(resolveDoneLane(plain, null), isNull);
  });
}
