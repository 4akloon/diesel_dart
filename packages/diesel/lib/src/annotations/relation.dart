import '../schema/table.dart';

/// Marks a relation field filled by joining the table referenced by FK [column]
/// and nesting the related object via its own generated reader, e.g.
/// `@Relation(Posts.authorId) final User? author;`. The field MUST be a nullable,
/// optional (named) parameter whose type is another `@Queryable` class.
///
/// [depth] bounds recursion for cyclic/self references: the relation is nested
/// `depth` levels deep; relations below the last level are left null. Default 1.
class Relation {
  final Ref column;
  final int depth;
  const Relation(this.column, {this.depth = 1});
}
