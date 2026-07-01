import '../connection.dart';
import '../schema/table.dart';
import 'query.dart';
import 'row_reader.dart';

/// Loads the children whose foreign key [fk] is one of [parentKeys], grouped by
/// that key — the diesel `belonging_to(parents).grouped_by(parents)` pattern in
/// a single query (avoids N+1). Every key in [parentKeys] is present in the
/// result, mapping to an empty list when it has no children.
///
/// ```dart
/// final postsByAuthor = await loadGroupedByFk(
///   db, Posts.table, Posts.authorId, users.map((u) => u.id).toList(), readPost);
/// ```
///
/// Lives here (not in the core builder) because it needs a [Connection]; it's
/// re-exported from `package:diesel/diesel.dart`.
Future<Map<K, List<C>>> loadGroupedByFk<Tbl, K, C>(
  Connection db,
  QuerySource<Tbl> childSource,
  TableColumn<K, Tbl> fk,
  List<K> parentKeys,
  C Function(RowReader reader) readChild,
) async {
  final groups = <K, List<C>>{for (final key in parentKeys) key: <C>[]};
  if (parentKeys.isEmpty) return groups;

  final rows = await db.fetch(
    from(childSource)
        .where(fk.isIn(parentKeys))
        .map((r) => (r.get(fk), readChild(r))),
  );
  for (final (key, child) in rows) {
    (groups[key] ??= <C>[]).add(child);
  }
  return groups;
}
