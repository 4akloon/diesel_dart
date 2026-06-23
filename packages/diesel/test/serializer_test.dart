import 'package:diesel/diesel.dart';
import 'package:test/test.dart';

import 'test_schema.dart';

/// Local dialect so the core package's serializer tests don't depend on any
/// backend: double-quoted identifiers and `?` placeholders (same as SQLite).
final class _TestDialect implements SqlDialect {
  const _TestDialect();

  @override
  String quoteIdentifier(String name) => '"$name"';

  @override
  String placeholder(int index) => '?';
}

CompiledQuery compileSelect(SelectQuery<dynamic> s) =>
    QueryBuilder(const _TestDialect()).buildSelect(s);

CompiledQuery compileWrite(WriteStatement s) =>
    QueryBuilder(const _TestDialect()).buildWrite(s);

// The decoder is irrelevant to SQL generation, so SQL tests use a trivial one.
int _ignore(RowReader _) => 0;

void main() {
  group('SELECT serialization', () {
    test('projection + where + order + limit', () {
      final (sql, params) = compileSelect(
        from(Users.table)
            .select([Users.name, Users.age])
            .where(Users.age.ge(18))
            .orderBy(Users.age.desc())
            .limit(10)
            .map(_ignore),
      );
      expect(
        sql,
        'SELECT "users"."name", "users"."age" FROM "users" '
        'WHERE ("users"."age" >= ?) ORDER BY "users"."age" DESC LIMIT ?',
      );
      expect(params, [18, 10]);
    });

    test('combined predicates with and/or and operator sugar', () {
      final (sql, params) = compileSelect(
        from(Users.table)
            .select([Users.id])
            .where(Users.age.gt(21).and(Users.name.like('A%')))
            .map(_ignore),
      );
      expect(
        sql,
        'SELECT "users"."id" FROM "users" '
        'WHERE (("users"."age" > ?) AND ("users"."name" LIKE ?))',
      );
      expect(params, [21, 'A%']);
    });

    test('IN, BETWEEN, IS NULL, bool encoding', () {
      final (sql, params) = compileSelect(
        from(Users.table).select([Users.id]).where(Users.id
            .isIn([1, 2, 3])
            .and(Users.age.between(18, 65))
            .and(Users.active.eq(true))).map(_ignore),
      );
      expect(
        sql,
        'SELECT "users"."id" FROM "users" WHERE '
        '(("users"."id" IN (?, ?, ?) AND "users"."age" BETWEEN ? AND ?) '
        'AND ("users"."active" = ?))',
      );
      expect(params, [1, 2, 3, 18, 65, 1]); // true -> 1
    });

    test('auto-projection maps all columns of the table', () {
      final (sql, params) = compileSelect(
        from(Users.table).where(Users.age.ge(18)).map(readUser),
      );
      expect(
        sql,
        'SELECT "users"."id", "users"."name", "users"."age", "users"."active" '
        'FROM "users" WHERE ("users"."age" >= ?)',
      );
      expect(params, [18]);
    });
  });

  group('write serialization', () {
    test('INSERT', () {
      final (sql, params) = compileWrite(
        insertInto(Users.table).value(Users.id.set(1)).value(Users.name.set('Bob')),
      );
      expect(sql, 'INSERT INTO "users" ("id", "name") VALUES (?, ?)');
      expect(params, [1, 'Bob']);
    });

    test('UPDATE with where', () {
      final (sql, params) = compileWrite(
        update(Users.table).value(Users.age.set(31)).where(Users.name.eq('Bob')),
      );
      expect(sql, 'UPDATE "users" SET "age" = ? WHERE ("users"."name" = ?)');
      expect(params, [31, 'Bob']);
    });

    test('DELETE with where', () {
      final (sql, params) =
          compileWrite(deleteFrom(Users.table).where(Users.age.lt(18)));
      expect(sql, 'DELETE FROM "users" WHERE ("users"."age" < ?)');
      expect(params, [18]);
    });

    test('INSERT binds a null for a nullable column', () {
      final (sql, params) = compileWrite(
        insertInto(Profiles.table).value(Profiles.id.set(1)).value(Profiles.bio.set(null)),
      );
      expect(sql, 'INSERT INTO "profiles" ("id", "bio") VALUES (?, ?)');
      expect(params, [1, null]);
    });
  });

  group('JOIN serialization', () {
    test('INNER JOIN with explicit ON and cross-table where', () {
      final (sql, params) = compileSelect(
        from(Users.table)
            .innerJoin(Posts.table, on: Users.id.eqColumn(Posts.authorId))
            .select([Users.name, Posts.title])
            .where(Posts.views.gt(100))
            .map(_ignore),
      );
      expect(
        sql,
        'SELECT "users"."name", "posts"."title" FROM "users" '
        'INNER JOIN "posts" ON ("users"."id" = "posts"."author_id") '
        'WHERE ("posts"."views" > ?)',
      );
      expect(params, [100]);
    });

    test('FK-driven join (onFk) derives the ON condition', () {
      final (sql, _) = compileSelect(
        from(Posts.table)
            .innerJoin(Users.table, onFk: Posts.authorId)
            .select([Posts.title, Users.name])
            .map(_ignore),
      );
      expect(
        sql,
        'SELECT "posts"."title", "users"."name" FROM "posts" '
        'INNER JOIN "users" ON ("posts"."author_id" = "users"."id")',
      );
    });

    test('LEFT JOIN', () {
      final (sql, _) = compileSelect(
        from(Users.table)
            .leftJoin(Posts.table, on: Users.id.eqColumn(Posts.authorId))
            .select([Users.name])
            .map(_ignore),
      );
      expect(
        sql,
        'SELECT "users"."name" FROM "users" '
        'LEFT JOIN "posts" ON ("users"."id" = "posts"."author_id")',
      );
    });

    test('chained joins across three tables (two FK joins)', () {
      final (sql, _) = compileSelect(
        from(Comments.table)
            .innerJoin(Posts.table, onFk: Comments.postId)
            .innerJoin(Users.table, onFk: Posts.authorId)
            .select([Comments.body, Posts.title, Users.name])
            .map(_ignore),
      );
      expect(
        sql,
        'SELECT "comments"."body", "posts"."title", "users"."name" '
        'FROM "comments" '
        'INNER JOIN "posts" ON ("comments"."post_id" = "posts"."id") '
        'INNER JOIN "users" ON ("posts"."author_id" = "users"."id")',
      );
    });

    test('self-join aliases the same table twice', () {
      final sender = Users.table.aliased('sender');
      final recipient = Users.table.aliased('recipient');
      final (sql, _) = compileSelect(
        from(Messages.table)
            .innerJoin(sender, on: Messages.senderId.eqColumn(sender.col(Users.id)))
            .innerJoin(recipient,
                on: Messages.recipientId.eqColumn(recipient.col(Users.id)))
            .select([Messages.body, sender.col(Users.name), recipient.col(Users.name)])
            .map(_ignore),
      );
      expect(
        sql,
        'SELECT "messages"."body", "sender"."name", "recipient"."name" '
        'FROM "messages" '
        'INNER JOIN "users" AS "sender" ON ("messages"."sender_id" = "sender"."id") '
        'INNER JOIN "users" AS "recipient" ON ("messages"."recipient_id" = "recipient"."id")',
      );
    });

    test('rejects a column from a table not in the FROM/JOIN clause', () {
      expect(
        () => compileSelect(
          from(Users.table)
              .innerJoin(Posts.table, on: Users.id.eqColumn(Posts.authorId))
              .select([Users.id])
              .where(Comments.id.eq(1))
              .map(_ignore),
        ),
        throwsStateError,
      );
    });

    test('auto-projection across a join maps both tables', () {
      final (sql, _) = compileSelect(
        from(Posts.table)
            .innerJoin(Users.table, onFk: Posts.authorId)
            .map((r) => readPost(r).withAuthor(readUser(r))),
      );
      expect(
        sql,
        'SELECT "posts"."id", "posts"."author_id", "posts"."title", "posts"."views", '
        '"users"."id", "users"."name", "users"."age", "users"."active" '
        'FROM "posts" INNER JOIN "users" ON ("posts"."author_id" = "users"."id")',
      );
    });
  });
}
