/// A `@Relation` edge extracted from a constructor parameter.
final class RelationEdge {
  final String fieldName;
  final int depth;
  final String parentMarker;
  final String fkAccessor;
  final String targetMarker;
  final String targetClass;
  final String pkAccessor;

  const RelationEdge({
    required this.fieldName,
    required this.depth,
    required this.parentMarker,
    required this.fkAccessor,
    required this.targetMarker,
    required this.targetClass,
    required this.pkAccessor,
  });
}
