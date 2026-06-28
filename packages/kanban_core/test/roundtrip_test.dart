import 'dart:io';

import 'package:kanban_core/kanban_core.dart';
import 'package:test/test.dart';

String _fixture() =>
    File('test/fixtures/sample_board.md').readAsStringSync();

void main() {
  group('round-trip', () {
    test('parse then serialize reproduces the source byte-for-byte', () {
      final source = _fixture();
      final board = KanbanBoard.parse(source);
      expect(board.serialize(), equals(source));
    });

    test('CRLF source round-trips and keeps CRLF', () {
      final source = _fixture().replaceAll('\n', '\r\n');
      final board = KanbanBoard.parse(source);
      expect(board.eol, '\r\n');
      expect(board.serialize(), equals(source));
    });

    test('empty document round-trips', () {
      final board = KanbanBoard.parse('');
      expect(board.serialize(), '');
    });
  });

  group('structure', () {
    late KanbanBoard board;
    setUp(() => board = KanbanBoard.parse(_fixture()));

    test('detects a Kanban board', () {
      expect(board.isKanban, isTrue);
    });

    test('frontmatter and settings are preserved in header/footer', () {
      expect(board.header, contains('kanban-plugin: board'));
      expect(board.header, contains('sticker: 1f4b9'));
      expect(board.footer, startsWith('%% kanban:settings'));
      expect(board.footer, contains('"list-collapse":[false,null,false]'));
    });

    test('lane titles keep raw markdown / special characters', () {
      expect(board.lanes.map((l) => l.title).toList(),
          ['**Doing**', 'to do <--', '--> done']);
    });

    test('cards are detected per lane', () {
      expect(board.lanes[0].cards.length, 4);
      expect(board.lanes[1].cards.length, 4);
      expect(board.lanes[2].cards.length, 4);
    });

    test('a concatenated/messy body line is not split into a new card', () {
      final messy = board.lanes[2].cards[2];
      expect(messy.title, '**Messy concatenated line**');
      // The "#Work- [ ] not a real card here" line stays inside the card body.
      expect(messy.serialize(), contains('not a real card here'));
    });
  });

  group('card field parsing', () {
    late KanbanBoard board;
    setUp(() => board = KanbanBoard.parse(_fixture()));

    test('checked state', () {
      expect(board.lanes[0].cards[0].checked, isFalse);
      expect(board.lanes[2].cards[3].checked, isTrue);
    });

    test('title without bold and link-only title', () {
      expect(board.lanes[0].cards[1].title, 'Plain card without bold');
      expect(board.lanes[1].cards[1].title, '[[Link only card title]]');
    });

    test('block id', () {
      expect(board.lanes[1].cards[0].title, '**Card with block id**');
      expect(board.lanes[1].cards[0].blockId, 'a1b2c3');
    });

    test('tags, date and times', () {
      final urlCard = board.lanes[1].cards[2];
      expect(urlCard.tags, contains('Work'));
      expect(urlCard.date, '2026-07-01');
      expect(urlCard.times, ['09:15']);

      final completed = board.lanes[2].cards[3];
      expect(completed.times, ['10:00']);
    });

    test('tag regex does not capture the url fragment #y', () {
      final urlCard = board.lanes[1].cards[2];
      expect(urlCard.tags, isNot(contains('y')));
    });

    test('subtasks', () {
      final card = board.lanes[0].cards[2];
      final subs = card.subtasks;
      expect(subs.length, 2);
      expect(subs[0].checked, isTrue);
      expect(subs[0].text, 'First subtask done');
      expect(subs[1].checked, isFalse);
    });
  });
}
