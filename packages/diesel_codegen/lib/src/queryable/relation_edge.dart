/// A `@Relation` edge extracted from a constructor parameter.
final class RelationEdge {
  final String fieldName;
  final int depth;
  final String parentMarker;
  final String fkAccessor;
  final bool fkNullable;
  final String targetMarker;
  final String targetClass;
  final String pkAccessor;

  const RelationEdge({
    required this.fieldName,
    required this.depth,
    required this.parentMarker,
    required this.fkAccessor,
    this.fkNullable = false,
    required this.targetMarker,
    required this.targetClass,
    required this.pkAccessor,
  });
}
