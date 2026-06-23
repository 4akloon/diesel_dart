import 'column_arg.dart';
import 'relation_edge.dart';

/// Everything the code generator needs to know about a single `@Queryable`
/// class, resolved from its element. Collected for the whole relation closure
/// reachable from a generated class so each `.g.dart` is self-contained — it
/// never references generated symbols from another library.
final class ClassInfo {
  final String className;
  final String tableMarker;
  final List<ColumnArg> columnArgs;

  /// The class's own `@Relation` edges (its outgoing relations).
  final List<RelationEdge> ownEdges;

  const ClassInfo({
    required this.className,
    required this.tableMarker,
    required this.columnArgs,
    this.ownEdges = const [],
  });
}
