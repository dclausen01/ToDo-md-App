/// Round-trip-safe parsing, serialization and editing of Obsidian Kanban-plugin
/// markdown boards. Pure Dart — usable from Flutter or command-line tools.
library;

export 'src/board.dart';
export 'src/card.dart';
export 'src/lane.dart' show KanbanLane, LaneNode, GapNode, CardNode;
export 'src/operations.dart';
