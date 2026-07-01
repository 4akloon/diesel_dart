import 'package:diesel/diesel.dart';
import 'package:diesel_sqlite/diesel_sqlite.dart';
import 'package:test/test.dart';

import 'test_schema.dart';

// A custom column type: an enum stored by name via a const SqlType with top-level
// codec tear-offs (const-compatible, so it works in `static const` columns).
enum Role { admin, user, guest }

Object? _encodeRole(Role r) => r.name;
Role _decodeRole(Object? v) => Role.values.byName(v as String);
const roleType = SqlType<Role>('TEXT', _encodeRole, _decodeRole);

abstract final class Accounts {
  static const id = PrimaryKey<int, Accounts>('accounts', 'id', SqlType.integer);
  static const role = ValueColumn<Role, Accounts>('accounts', 'role', roleType);
  static const table = TableRef<Accounts>('accounts', [id, role]);
}

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

  test('findBy fetches by primary key', () async {
    await seed(); // Bob = 1
    final bob = await from(Users.table)
        .findBy(Users.id, 1)
        .mapWith(userQueryable)
        .first(db);
    expect(bob.name, 'Bob');
  });

  test('diesel-style terminals: load / first / optional', () async {
    await seed(); // Bob=30, Alice=17, Carol=42

    // filter/order aliases + load terminal.
    final all = await from(Users.table)
        .filter(Users.age.ge(18))
        .order(Users.age.desc())
        .map((r) => r.get(Users.name))
        .load(db);
    expect(all, ['Carol', 'Bob']);

    final top = await from(Users.table)
        .order(Users.age.desc())
        .map((r) => r.get(Users.name))
        .first(db);
    expect(top, 'Carol');

    final none = await from(Users.table)
        .where(Users.age.gt(100))
        .map((r) => r.get(Users.name))
        .optional(db);
    expect(none, isNull);

    await expectLater(
      from(Users.table)
          .where(Users.age.gt(100))
          .map((r) => r.get(Users.id))
          .first(db),
      throwsStateError,
    );
  });

  test('aggregates, distinct, group by', () async {
    await seed(); // Bob 30 active, Alice 17 inactive, Carol 42 active

    final count = countAll();
    final total =
        await from(Users.table).select([count]).map((r) => r.get(count)).first(db);
    expect(total, 3);

    final sumAge = Users.age.sum();
    final avgAge = Users.age.avg();
    final (sum, avg) = await from(Users.table)
        .select([sumAge, avgAge])
        .map((r) => (r.get(sumAge), r.get(avgAge)))
        .first(db);
    expect(sum, 89); // 30 + 17 + 42
    expect(avg, closeTo(29.666, 0.01));

    final distinctActive = await from(Users.table)
        .select([Users.active])
        .distinct()
        .orderBy(Users.active.asc())
        .map((r) => r.get(Users.active))
        .load(db);
    expect(distinctActive, [false, true]); // 0/1 decode to bool

    final perGroup = Users.id.count();
    final groups = await from(Users.table)
        .select([Users.active, perGroup])
        .groupBy([Users.active])
        .orderBy(Users.active.asc())
        .map((r) => (r.get(Users.active), r.get(perGroup)))
        .load(db);
    expect(groups, [(false, 1), (true, 2)]);
  });

  test('batch insert writes multiple rows (+ RETURNING)', () async {
    final n = await db.execute(
      insertInto(Users.table).values([
        [Users.id.set(1), Users.name.set('A'), Users.age.set(20), Users.active.set(true)],
        [Users.id.set(2), Users.name.set('B'), Users.age.set(21), Users.active.set(false)],
      ]),
    );
    expect(n, 2);

    // Batch + RETURNING with ids omitted → autoincrement continues from 2.
    final ids = await db.executeReturning(
      insertInto(Users.table).values([
        [Users.name.set('C'), Users.age.set(22), Users.active.set(true)],
        [Users.name.set('D'), Users.age.set(23), Users.active.set(true)],
      ]).returning([Users.id]).map((r) => r.get(Users.id)),
    );
    expect(ids, [3, 4]);

    final names = await from(Users.table)
        .order(Users.id.asc())
        .map((r) => r.get(Users.name))
        .load(db);
    expect(names, ['A', 'B', 'C', 'D']);
  });

  test('upsert: ON CONFLICT DO NOTHING / DO UPDATE', () async {
    await db.execute(insertInto(Users.table)
        .value(Users.id.set(1))
        .value(Users.name.set('Bob'))
        .value(Users.age.set(30))
        .value(Users.active.set(true)));

    // DO NOTHING: the conflicting insert is ignored.
    await db.execute(insertInto(Users.table)
        .value(Users.id.set(1))
        .value(Users.name.set('NOPE'))
        .value(Users.age.set(0))
        .value(Users.active.set(false))
        .onConflict([Users.id]).doNothing());
    expect(
      await from(Users.table)
          .where(Users.id.eq(1))
          .map((r) => r.get(Users.name))
          .first(db),
      'Bob',
    );

    // DO UPDATE: name from excluded (proposed) value, age from a literal.
    await db.execute(insertInto(Users.table)
        .value(Users.id.set(1))
        .value(Users.name.set('Bobby'))
        .value(Users.age.set(31))
        .value(Users.active.set(true))
        .onConflict([Users.id]).doUpdate(
            [Users.name.setToExcluded(), Users.age.set(40)]));
    final (name, age) = await from(Users.table)
        .where(Users.id.eq(1))
        .map((r) => (r.get(Users.name), r.get(Users.age)))
        .first(db);
    expect(name, 'Bobby'); // excluded.name
    expect(age, 40); // literal
  });

  test('raw() typed SQL selection', () async {
    await seed(); // Bob = 30
    final nextAge = raw<int>('age + 1', SqlType.integer, as: 'next_age');
    final rows = await from(Users.table)
        .select([Users.name, nextAge])
        .where(Users.id.eq(1))
        .map((r) => (r.get(Users.name), r.get(nextAge)))
        .load(db);
    expect(rows, [('Bob', 31)]);
  });

  test('loadGroupedByFk groups children by parent (belongs_to)', () async {
    await seed(); // Bob=1, Alice=2, Carol=3
    await db.execute(insertInto(Posts.table).value(Posts.id.set(1)).value(Posts.authorId.set(1)).value(Posts.title.set('a')).value(Posts.views.set(1)));
    await db.execute(insertInto(Posts.table).value(Posts.id.set(2)).value(Posts.authorId.set(1)).value(Posts.title.set('b')).value(Posts.views.set(2)));
    await db.execute(insertInto(Posts.table).value(Posts.id.set(3)).value(Posts.authorId.set(3)).value(Posts.title.set('c')).value(Posts.views.set(3)));

    final byAuthor =
        await loadGroupedByFk(db, Posts.table, Posts.authorId, [1, 2, 3], readPost);
    expect(byAuthor[1]!.map((p) => p.title), ['a', 'b']);
    expect(byAuthor[2], isEmpty); // Alice has no posts, but the key is present
    expect(byAuthor[3]!.map((p) => p.title), ['c']);
  });

  test('custom SqlType codec (enum) round-trips', () async {
    await db.executeSql(
        'CREATE TABLE accounts (id INTEGER PRIMARY KEY, role TEXT NOT NULL)');
    await db.execute(insertInto(Accounts.table)
        .value(Accounts.id.set(1))
        .value(Accounts.role.set(Role.admin)));
    await db.execute(insertInto(Accounts.table)
        .value(Accounts.id.set(2))
        .value(Accounts.role.set(Role.guest)));

    final roles = await from(Accounts.table)
        .order(Accounts.id.asc())
        .map((r) => r.get(Accounts.role))
        .load(db);
    expect(roles, [Role.admin, Role.guest]);

    // The custom type also encodes values inside predicates.
    final admins = await from(Accounts.table)
        .where(Accounts.role.eq(Role.admin))
        .map((r) => r.get(Accounts.id))
        .load(db);
    expect(admins, [1]);
  });

  test('INSERT/UPDATE ... RETURNING', () async {
    // users.id is INTEGER PRIMARY KEY, so omitting it autoincrements the rowid;
    // RETURNING surfaces the generated id (the earlier last-insert-id gap).
    final inserted = await db.executeReturning(
      insertInto(Users.table)
          .value(Users.name.set('Zoe'))
          .value(Users.age.set(20))
          .value(Users.active.set(true))
          .returning([Users.id]).map((r) => r.get(Users.id)),
    );
    expect(inserted, [1]);

    final updated = await db.executeReturning(
      update(Users.table)
          .value(Users.age.set(21))
          .where(Users.id.eq(1))
          .returning([Users.id, Users.age]).map(
              (r) => (r.get(Users.id), r.get(Users.age))),
    );
    expect(updated, [(1, 21)]);
  });
}
