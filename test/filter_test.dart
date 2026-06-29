import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_core/kanban_core.dart';
import 'package:todo_md_app/src/providers/filter_provider.dart';

const _board = '''---

kanban-plugin: board

---

## Doing

- [ ] **Buy milk**
  #Home @{2026-06-24}
- [ ] **Prepare lesson**
  #Work #Teaching
- [ ] **Call plumber**
  #Home


%% kanban:settings
```
{"kanban-plugin":"board"}
```
%%
''';

void main() {
  final board = KanbanBoard.parse(_board);
  final cards = board.lanes[0].cards;
  final milk = cards[0];
  final lesson = cards[1];
  final plumber = cards[2];

  test('empty filter matches everything', () {
    const f = BoardFilter();
    expect(f.isActive, isFalse);
    expect(cards.where(f.matches).length, 3);
  });

  test('text query matches title and body, case-insensitive', () {
    const f = BoardFilter(query: 'milk');
    expect(f.matches(milk), isTrue);
    expect(f.matches(lesson), isFalse);

    const f2 = BoardFilter(query: 'TEACHING');
    expect(f2.matches(lesson), isTrue);
  });

  test('tag filter uses OR across selected tags', () {
    const f = BoardFilter(tags: {'Home'});
    expect(cards.where(f.matches).toList(), [milk, plumber]);

    const f2 = BoardFilter(tags: {'Home', 'Work'});
    expect(cards.where(f2.matches).length, 3);
  });

  test('query and tags combine with AND', () {
    const f = BoardFilter(query: 'call', tags: {'Home'});
    expect(f.matches(plumber), isTrue);
    expect(f.matches(milk), isFalse); // matches tag but not query
  });
}
