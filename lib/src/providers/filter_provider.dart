import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kanban_core/kanban_core.dart';

/// Active board filter: a free-text query and a set of tags. A card is shown
/// when it matches the query (substring over its whole text) AND, if any tags
/// are selected, carries at least one of them (OR within tags).
class BoardFilter {
  const BoardFilter({this.query = '', this.tags = const {}});

  final String query;
  final Set<String> tags;

  bool get isActive => query.trim().isNotEmpty || tags.isNotEmpty;

  bool matches(KanbanCard card) {
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty && !card.lines.join().toLowerCase().contains(q)) {
      return false;
    }
    if (tags.isNotEmpty) {
      final cardTags = card.tags.toSet();
      if (!tags.any(cardTags.contains)) return false;
    }
    return true;
  }

  BoardFilter copyWith({String? query, Set<String>? tags}) =>
      BoardFilter(query: query ?? this.query, tags: tags ?? this.tags);
}

class BoardFilterController extends Notifier<BoardFilter> {
  @override
  BoardFilter build() => const BoardFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void toggleTag(String tag) {
    final next = Set<String>.of(state.tags);
    if (!next.add(tag)) next.remove(tag);
    state = state.copyWith(tags: next);
  }

  void clearTags() => state = state.copyWith(tags: const {});

  void clear() => state = const BoardFilter();
}

final boardFilterProvider =
    NotifierProvider<BoardFilterController, BoardFilter>(
        BoardFilterController.new);
