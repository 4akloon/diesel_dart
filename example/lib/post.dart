import 'package:diesel/diesel.dart';

import 'schema.dart';
import 'user.dart';

part 'post.g.dart';

/// Lives in a different file than [User] on purpose: `diesel_codegen` resolves
/// the cross-file `@Relation` and emits a self-contained `post.g.dart`.
@Queryable(Posts.table)
class Post {
  final int id;
  final String title;
  final int views;

  /// A relation, not a column. `depth: 2` unrolls the join two levels deep:
  /// the post's `author`, and *that* author's `manager` — each under its own
  /// path-based alias (`author`, `author_manager`). Cyclic-safe by construction.
  @Relation(Posts.authorId, depth: 2)
  final User? author;

  /// Fully named constructor — `diesel_codegen` maps columns by name, so mixing
  /// named (and positional) parameters works either way.
  const Post({
    required this.id,
    required this.title,
    required this.views,
    this.author,
  });

  @override
  String toString() {
    final by = author == null ? 'unknown' : author!.name;
    final boss = author?.manager == null ? '' : ' (mgr: ${author!.manager!.name})';
    return 'Post("$title", $views views, by $by$boss)';
  }
}
