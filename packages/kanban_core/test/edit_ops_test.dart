import 'dart:io';

import 'package:kanban_core/kanban_core.dart';
import 'package:test/test.dart';

String _fixture() =>
    File('test/fixtures/sample_board.md').readAsStringSync();

/// Asserts that [edited] differs from [original] only inside the single line
/// region that contains [marker], i.e. an edit stayed local and did not disturb
/// the rest of the document.
void expectLocalChange(String original, String edited, String marker) {
  final o = original.split('\n');
  final e = edited.split('\n');
  expect(e.length, o.length,
      reason: 'line count changed unexpectedly');
  final changed = <int>[];
  for (var i = 0; i < o.length; i++) {
    if (o[i] != e[i]) changed.add(i);
  }
  expect(changed.length, 1, reason: 'expected exactly one changed line');
  expect(e[changed.single], contains(marker));
}

void main() {
  group('toggle operations', () {
    test('toggling a card checkbox changes only that line', () {
      final source = _fixture();
      final board = KanbanBoard.parse(source);
      final card = board.lanes[0].cards[0];
      expect(card.checked, isFalse);
      card.toggleChecked();
      expect(card.checked, isTrue);
      final out = board.serialize();
      expect(out, contains('- [x] **Bold card with tag and date**'));
      expectLocalChange(source, out, '- [x] **Bold card with tag and date**');
    });

    test('toggling a subtask changes only that line', () {
      final source = _fixture();
      final board = KanbanBoard.parse(source);
      final card = board.lanes[0].cards[2];
      final open = card.subtasks[1];
      expect(open.checked, isFalse);
      card.toggleSubtask(open.lineIndex);
      final out = board.serialize();
      expect(out, contains('- [x] Second subtask open'));
      expectLocalChange(source, out, '- [x] Second subtask open');
    });
  });

  group('title / tag / date edits', () {
    test('editing the title preserves the block id and body', () {
      final board = KanbanBoard.parse(_fixture());
      final card = board.lanes[1].cards[0];
      card.title = '**Renamed card**';
      final out = card.serialize();
      expect(out, contains('- [ ] **Renamed card** ^a1b2c3'));
      expect(out, contains('![[Big Project Note]]'));
    });

    test('adding a tag appends to an existing tag line', () {
      final board = KanbanBoard.parse(_fixture());
      final card = board.lanes[0].cards[0];
      card.addTag('Urgent');
      expect(card.tags, containsAll(['Work', 'Urgent']));
      expect(card.serialize(), contains('#Work @{2026-06-24} #Urgent'));
    });

    test('removing a tag drops only that token', () {
      final board = KanbanBoard.parse(_fixture());
      final card = board.lanes[1].cards[2];
      card.removeTag('Work');
      expect(card.tags, isNot(contains('Work')));
      expect(card.serialize(), contains('@{2026-07-01}'));
    });

    test('setDate replaces an existing date in place', () {
      final board = KanbanBoard.parse(_fixture());
      final card = board.lanes[0].cards[0];
      card.setDate('2026-12-31');
      expect(card.date, '2026-12-31');
      expect(card.serialize(), contains('#Work @{2026-12-31}'));
    });

    test('setDate(null) clears the date', () {
      final board = KanbanBoard.parse(_fixture());
      final card = board.lanes[0].cards[0];
      card.setDate(null);
      expect(card.date, isNull);
      expect(card.serialize(), contains('#Work'));
      expect(card.serialize(), isNot(contains('@{')));
    });
  });

  group('move / add / delete', () {
    test('moving a card removes it from source and appends to target', () {
      final board = KanbanBoard.parse(_fixture());
      final card = board.lanes[0].cards[0];
      final target = board.lanes[1];
      final beforeSource = board.lanes[0].cards.length;
      final beforeTarget = target.cards.length;

      expect(board.moveCard(card, target), isTrue);

      expect(board.lanes[0].cards.length, beforeSource - 1);
      expect(target.cards.length, beforeTarget + 1);
      expect(target.cards.last, same(card));
      // Other lanes/footer remain intact.
      expect(board.footer, startsWith('%% kanban:settings'));
    });

    test('moved card keeps its full body', () {
      final board = KanbanBoard.parse(_fixture());
      final card = board.lanes[0].cards[3]; // card with internal links
      board.moveCard(card, board.lanes[2]);
      final out = board.serialize();
      expect(out, contains('![[Embedded Note]]'));
      // Round-trip is still valid markdown with all lanes present.
      final reparsed = KanbanBoard.parse(out);
      expect(reparsed.lanes.length, 3);
    });

    test('adding a card uses board EOL/indent conventions', () {
      final board = KanbanBoard.parse(_fixture());
      final lane = board.lanes[1];
      final before = lane.cards.length;
      final card = board.addCard(
        lane,
        title: 'Quick new task',
        tags: ['Inbox'],
        date: '2026-06-28',
      );
      expect(lane.cards.length, before + 1);
      expect(card.title, 'Quick new task');
      expect(card.tags, contains('Inbox'));
      expect(card.date, '2026-06-28');
      final out = board.serialize();
      expect(out, contains('- [ ] Quick new task'));
      expect(out, contains('#Inbox @{2026-06-28}'));
      // The new card must not break parsing.
      expect(KanbanBoard.parse(out).lanes[1].cards.length, before + 1);
    });

    test('deleting a card removes it but keeps the rest parseable', () {
      final board = KanbanBoard.parse(_fixture());
      final card = board.lanes[2].cards[0]; // one of the duplicates
      expect(board.deleteCard(card), isTrue);
      final reparsed = KanbanBoard.parse(board.serialize());
      expect(reparsed.lanes[2].cards.length, 3);
    });
  });
}
