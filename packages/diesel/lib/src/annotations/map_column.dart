import '../schema/table.dart';

/// Overrides which column a field maps to
/// (`@MapColumn(Posts.authorId)`). Without it, the field name is used — matching
/// the generated schema's camelCase column accessor.
class MapColumn {
  final Column column;
  const MapColumn(this.column);
}
