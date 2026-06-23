import 'package:diesel/diesel.dart';
import 'package:diesel_example/models.dart';
import 'package:diesel_example/schema.dart';
import 'package:diesel_sqlite/diesel_sqlite.dart';

/// Run AFTER applying the migrations with the CLI:
///   dart run diesel_cli:diesel_dart migration run
///   dart run bin/example.dart
Future<void> main() async {
  final db = SqliteConnection.open('example.db');

  // Re-seed so the example is repeatable (posts first — FK to users).
  await db.execute(deleteFrom(Posts.table));
  await db.execute(deleteFrom(Users.table));
  await db.transaction((tx) async {
    await tx.execute(insertInto(Users.table).value(Users.id.set(1)).value(Users.name.set('Bob')).value(Users.age.set(30)).value(Users.active.set(1)));
    await tx.execute(insertInto(Users.table).value(Users.id.set(2)).value(Users.name.set('Carol')).value(Users.age.set(42)).value(Users.active.set(1)));
    await tx.execute(insertInto(Posts.table).value(Posts.id.set(1)).value(Posts.authorId.set(1)).value(Posts.title.set('Hello')).value(Posts.views.set(150)));
    await tx.execute(insertInto(Posts.table).value(Posts.id.set(2)).value(Posts.authorId.set(2)).value(Posts.title.set('World')).value(Posts.views.set(90)));
  });

  // Typed join: each post with its author, most-viewed first.
  final posts = await db.fetch(
    from(Posts.table)
        .innerJoin(Users.table, onFk: Posts.authorId)
        .orderBy(Posts.views.desc())
        .map((r) => postMapper.read(r).withAuthor(userMapper.read(r))),
  );

  print('Posts with authors:');
  for (final post in posts) {
    print('  $post');
  }

  await db.close();
}
