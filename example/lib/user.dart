import 'package:diesel/diesel.dart';

import 'schema.dart';

part 'user.g.dart';

/// Note: `active` is `int` because SQLite has no native boolean.
@Queryable(Users.table)
class User {
  final int id;
  final String name;
  final int age;
  final int active;

  /// Self-referential relation: a user may report to another user. The FK
  /// (`Users.managerId`) is nullable, so the relation field must be nullable
  /// too. The generated `userQuery` INNER JOINs `users` to itself
  /// under a path-based alias, so only users that *have* a manager come back.
  @Relation(Users.managerId)
  final User? manager;

  const User(this.id, this.name, this.age, this.active, {this.manager});

  @override
  String toString() {
    final boss = manager == null ? '' : ', reports to ${manager!.name}';
    return 'User(#$id $name, age $age$boss)';
  }
}
