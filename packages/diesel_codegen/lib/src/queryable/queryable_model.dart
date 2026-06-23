import 'class_info.dart';

/// Root inputs for one `@Queryable` class plus the resolved info for every
/// class reachable through its relations ([classInfos], keyed by class name).
/// The closure makes generation self-contained across files: the emitted
/// `.g.dart` defines every nested reader it needs locally.
final class QueryableModel {
  final ClassInfo root;
  final Map<String, ClassInfo> classInfos;

  const QueryableModel({required this.root, required this.classInfos});
}
