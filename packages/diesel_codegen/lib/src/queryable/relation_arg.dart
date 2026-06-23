/// A nested relation argument inlined into a unified reader.
final class RelationArg {
  final String fieldName;
  final String childCall;

  const RelationArg({required this.fieldName, required this.childCall});
}
