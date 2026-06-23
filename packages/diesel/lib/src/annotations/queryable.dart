import '../schema/table.dart';

/// Marks a data class for row-mapper generation against [table]
/// (e.g. `@Queryable(Posts.table)`). The generator emits a `RowMapper<ThisClass>`
/// plus a `fromRow` reader that calls `RowReader.get` for each mapped field.
class Queryable {
  final TableRef table;
  const Queryable(this.table);
}
