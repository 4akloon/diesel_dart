import 'package:diesel/diesel.dart';
import 'package:diesel_sqlite/diesel_sqlite.dart';
import 'package:test/test.dart';

import 'test_schema.dart';

void main() {
  late SqliteConnection db;

  setUp(() async {
    db = SqliteConnection.memory();
    await db.executeSql('CREATE TABLE users ('
        'id INTEGER PRIMARY KEY, name TEXT NOT NULL, '
        'age INTEGER NOT NULL, active INTEGER NOT NULL)');
    await db.executeSql('CREATE TABLE posts ('
        'id INTEGER PRIMARY KEY, author_id INTEGER NOT NULL, '
        'title TEXT NOT NULL, views INTEGER NOT NULL)');
    await db.executeSql('CREATE TABLE comments ('
        'id INTEGER PRIMARY KEY, post_id INTEGER NOT NULL, body TEXT NOT NULL)');
    await db.executeSql('CREATE TABLE messages ('
        'id INTEGER PRIMARY KEY, sender_id INTEGER NOT NULL, '
        'recipient_id INTEGER NOT NULL, body TEXT NOT NULL)');
  });

  tearDown(() => db.close());

  Future<void> seed() async {
    await db.execute(insertInto(Users.table).value(Users.id.set(1)).value(Users.name.set('Bob')).value(Users.age.set(30)).value(Users.active.set(true)));
    await db.execute(insertInto(Users.table).value(Users.id.set(2)).value(Users.name.set('Alice')).value(Users.age.set(17)).value(Users.active.set(false)));
    await db.execute(insertInto(Users.table).value(Users.id.set(3)).value(Users.name.set('Carol')).value(Users.age.set(42)).value(Users.active.set(true)));
  }

  test('round-trip: insert then typed select (record via map)', () async {
    await seed();
    final rows = await db.fetch(
      from(Users.table)
          .select([Users.name, Users.age])
          .where(Users.age.ge(18))
          .orderBy(Users.age.desc())
          .map((r) => (r.get(Users.name), r.get(Users.age))),
    );
    expect(rows, [('Carol', 42), ('Bob', 30)]);
    final (firstName, firstAge) = rows.first; // statically (String, int)
    expect(firstName, isA<String>());
    expect(firstAge, isA<int>());
  });

  test('bool decoding round-trips', () async {
    await seed();
    final actives = await db.fetch(
      from(Users.table)
          .where(Users.active.eq(true))
          .orderBy(Users.name.asc())
          .map((r) => r.get(Users.name)),
    );
    expect(actives, ['Bob', 'Carol']);
  });

  test('update returns affected rows and persists', () async {
    await seed();
    final n = await db.execute(update(Users.table).value(Users.age.set(31)).where(Users.name.eq('Bob')));
    expect(n, 1);
    expect(
      await db.fetch(from(Users.table).where(Users.name.eq('Bob')).map((r) => r.get(Users.age))),
      [31],
    );
  });

  test('delete returns affected rows', () async {
    await seed();
    final n = await db.execute(deleteFrom(Users.table).where(Users.age.lt(18)));
    expect(n, 1);
    expect((await db.fetch(from(Users.table).map((r) => r.get(Users.id)))).length, 2);
  });

  test('selectModel returns data class instances (mapWith)', () async {
    await seed();
    final users = await db.fetch(
      from(Users.table).where(Users.age.ge(18)).orderBy(Users.name.asc()).mapWith(userQueryable),
    );
    expect(users.map((u) => u.name), ['Bob', 'Carol']);
    expect(users.first, isA<User>());
    expect(users.first.active, isTrue);
  });

  test('join nests the author User inside Post', () async {
    await seed();
    await db.execute(insertInto(Posts.table).value(Posts.id.set(1)).value(Posts.authorId.set(1)).value(Posts.title.set('Hello')).value(Posts.views.set(150)));
    await db.execute(insertInto(Posts.table).value(Posts.id.set(2)).value(Posts.authorId.set(3)).value(Posts.title.set('World')).value(Posts.views.set(50)));

    final List<Post> posts = await db.fetch(
      from(Posts.table)
          .innerJoin(Users.table, onFk: Posts.authorId)
          .where(Posts.views.gt(100))
          .map((r) => readPost(r).withAuthor(readUser(r))),
    );

    expect(posts.length, 1);
    final post = posts.single;
    expect(post.title, 'Hello');
    final author = post.author; // the User lives inside Post
    expect(author, isA<User>());
    expect(author?.name, 'Bob');
  });

  test('chained joins (two joins) nest Comment -> Post -> User', () async {
    await seed();
    await db.execute(insertInto(Posts.table).value(Posts.id.set(1)).value(Posts.authorId.set(1)).value(Posts.title.set('Hello')).value(Posts.views.set(150)));
    await db.execute(insertInto(Posts.table).value(Posts.id.set(2)).value(Posts.authorId.set(3)).value(Posts.title.set('World')).value(Posts.views.set(50)));
    await db.execute(insertInto(Comments.table).value(Comments.id.set(1)).value(Comments.postId.set(1)).value(Comments.body.set('Nice')));
    await db.execute(insertInto(Comments.table).value(Comments.id.set(2)).value(Comments.postId.set(2)).value(Comments.body.set('Meh')));

    final List<Comment> comments = await db.fetch(
      from(Comments.table)
          .innerJoin(Posts.table, onFk: Comments.postId) // comments -> posts
          .innerJoin(Users.table, onFk: Posts.authorId) // posts -> users
          .orderBy(Comments.id.asc())
          .map((r) => readComment(r).withPost(readPost(r).withAuthor(readUser(r)))),
    );

    expect(comments.length, 2);
    expect(comments[0].body, 'Nice');
    expect(comments[0].post?.title, 'Hello');
    expect(comments[0].post?.author?.name, 'Bob');
    expect(comments[1].post?.title, 'World');
    expect(comments[1].post?.author?.name, 'Carol');
  });

  test('self-join: two FKs to the same table via aliases', () async {
    await seed(); // Bob=1, Alice=2, Carol=3
    await db.execute(insertInto(Messages.table).value(Messages.id.set(1)).value(Messages.senderId.set(1)).value(Messages.recipientId.set(3)).value(Messages.body.set('Hi Carol')));

    final sender = Users.table.aliased('sender');
    final recipient = Users.table.aliased('recipient');

    final List<Message> messages = await db.fetch(
      from(Messages.table)
          .innerJoin(sender, on: Messages.senderId.eqColumn(sender.col(Users.id)))
          .innerJoin(recipient, on: Messages.recipientId.eqColumn(recipient.col(Users.id)))
          .map((r) => Message(
                r.get(Messages.id),
                r.get(Messages.body),
                sender: readUserFrom(sender, r),
                recipient: readUserFrom(recipient, r),
              )),
    );

    expect(messages.length, 1);
    final m = messages.single;
    expect(m.body, 'Hi Carol');
    expect(m.sender.name, 'Bob'); // resolved from the "sender" alias
    expect(m.recipient.name, 'Carol'); // resolved from the "recipient" alias
  });

  test('nullable column round-trips null and non-null', () async {
    await db.executeSql('CREATE TABLE profiles (id INTEGER PRIMARY KEY, bio TEXT)');
    await db.execute(insertInto(Profiles.table).value(Profiles.id.set(1)).value(Profiles.bio.set('hello')));
    await db.execute(insertInto(Profiles.table).value(Profiles.id.set(2)).value(Profiles.bio.set(null)));

    final List<String?> bios = await db.fetch(
      from(Profiles.table).orderBy(Profiles.id.asc()).map((r) => r.get(Profiles.bio)),
    );
    expect(bios, ['hello', null]);

    final withBio = await db.fetch(
      from(Profiles.table).where(Profiles.bio.isNotNull()).map((r) => r.get(Profiles.id)),
    );
    expect(withBio, [1]);

    final withoutBio = await db.fetch(
      from(Profiles.table).where(Profiles.bio.isNull()).map((r) => r.get(Profiles.id)),
    );
    expect(withoutBio, [2]);
  });

  test('transaction rolls back on error', () async {
    await seed();
    await expectLater(
      db.transaction((tx) async {
        await tx.execute(insertInto(Users.table).value(Users.id.set(99)).value(Users.name.set('Temp')).value(Users.age.set(1)).value(Users.active.set(false)));
        throw StateError('boom');
      }),
      throwsStateError,
    );
    expect(
      await db.fetch(from(Users.table).where(Users.id.eq(99)).map((r) => r.get(Users.id))),
      isEmpty,
    );
  });

  test('nested transaction (savepoint) rolls back inner only', () async {
    await seed();
    await db.transaction((tx) async {
      await tx.execute(insertInto(Users.table).value(Users.id.set(10)).value(Users.name.set('Outer')).value(Users.age.set(50)).value(Users.active.set(true)));
      try {
        await tx.transaction((inner) async {
          await inner.execute(insertInto(Users.table).value(Users.id.set(11)).value(Users.name.set('Inner')).value(Users.age.set(60)).value(Users.active.set(true)));
          throw StateError('inner boom');
        });
      } on StateError {
        // swallow: outer continues
      }
    });
    expect(
      await db.fetch(from(Users.table).where(Users.id.eq(10)).map((r) => r.get(Users.name))),
      ['Outer'],
    );
    expect(
      await db.fetch(from(Users.table).where(Users.id.eq(11)).map((r) => r.get(Users.id))),
      isEmpty,
    );
  });
}
