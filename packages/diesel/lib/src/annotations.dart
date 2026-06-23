/// Annotations consumed by `diesel_codegen` to derive row mappers for data
/// classes. They carry no runtime behaviour — only metadata for the generator.
library;

/// Marks a data class for row-mapper generation against table marker [table]
/// (e.g. `@Queryable(Users)`). The generator emits a `RowMapper<ThisClass>` plus
/// a `fromRow` reader that calls `RowReader.get` for each mapped field.
class Queryable {
  final Type table;
  const Queryable(this.table);
}

/// Overrides which column a field maps to, by SQL column name
/// (`@MapColumn('author_id')`). Without it, the field name is used — matching
/// the generated schema's camelCase column accessor.
class MapColumn {
  final String column;
  const MapColumn(this.column);
}

/// Excludes a field from generation (e.g. a relation that is not a column).
/// The field must be optional in the constructor so its default can be used.
class Ignore {
  const Ignore();
}

/// Shorthand for [Ignore]: `@ignore final User? author;`.
const ignore = Ignore();
