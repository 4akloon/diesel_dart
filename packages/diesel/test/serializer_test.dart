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

  // Mirrors SQLite: bool -> int, DateTime -> epoch-ms.
  @override
  Object? encodeParam(Object? value) {
    if (value is bool) return value ? 1 : 0;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return value;
  }
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

    test('INSERT ... ON CONFLICT DO NOTHING', () {
      final (sql, params) = compileWrite(
        insertInto(Users.table)
            .value(Users.id.set(1))
            .value(Users.name.set('Bob'))
            .onConflict([Users.id]).doNothing(),
      );
      expect(
        sql,
        'INSERT INTO "users" ("id", "name") VALUES (?, ?) '
        'ON CONFLICT ("id") DO NOTHING',
      );
      expect(params, [1, 'Bob']);
    });

    test('INSERT ... ON CONFLICT DO UPDATE (excluded + literal)', () {
      final (sql, params) = compileWrite(
        insertInto(Users.table)
            .value(Users.id.set(1))
            .value(Users.name.set('Bob'))
            .value(Users.age.set(30))
            .onConflict([Users.id])
            .doUpdate([Users.name.setToExcluded(), Users.age.set(99)]),
      );
      expect(
        sql,
        'INSERT INTO "users" ("id", "name", "age") VALUES (?, ?, ?) '
        'ON CONFLICT ("id") DO UPDATE SET "name" = excluded."name", "age" = ?',
      );
      expect(params, [1, 'Bob', 30, 99]);
    });

    test('batch INSERT emits one VALUES tuple per row', () {
      final (sql, params) = compileWrite(
        insertInto(Users.table).values([
          [Users.id.set(1), Users.name.set('Bob')],
          [Users.id.set(2), Users.name.set('Alice')],
        ]),
      );
      expect(sql, 'INSERT INTO "users" ("id", "name") VALUES (?, ?), (?, ?)');
      expect(params, [1, 'Bob', 2, 'Alice']);
    });

    test('INSERT ... RETURNING uses unqualified column names', () {
      final rq = insertInto(Users.table)
          .value(Users.name.set('Bob'))
          .returning([Users.id, Users.name]).map((r) => r.get(Users.id));
      final (sql, params) = QueryBuilder(const _TestDialect())
          .buildWrite(rq.statement, returning: rq.returning);
      expect(
        sql,
        'INSERT INTO "users" ("name") VALUES (?) RETURNING "id", "name"',
      );
      expect(params, ['Bob']);
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

  group('diesel-style aliases', () {
    test('filter / order / eqAny match where / orderBy / isIn', () {
      final (aSql, aParams) = compileSelect(
        from(Users.table)
            .select([Users.id])
            .filter(Users.id.eqAny([1, 2]))
            .order(Users.age.desc())
            .map(_ignore),
      );
      final (cSql, cParams) = compileSelect(
        from(Users.table)
            .select([Users.id])
            .where(Users.id.isIn([1, 2]))
            .orderBy(Users.age.desc())
            .map(_ignore),
      );
      expect(aSql, cSql);
      expect(aParams, cParams);
    });

    test('repeated filter() ANDs, unlike where() (diesel semantics)', () {
      final (sql, params) = compileSelect(
        from(Users.table)
            .select([Users.id])
            .filter(Users.age.gt(18))
            .filter(Users.active.eq(true))
            .map(_ignore),
      );
      expect(
        sql,
        'SELECT "users"."id" FROM "users" '
        'WHERE (("users"."age" > ?) AND ("users"."active" = ?))',
      );
      expect(params, [18, 1]);
    });

    test('findBy filters by a key column', () {
      final (sql, params) = compileSelect(
        from(Users.table).findBy(Users.id, 5).select([Users.name]).map(_ignore),
      );
      expect(sql,
          'SELECT "users"."name" FROM "users" WHERE ("users"."id" = ?)');
      expect(params, [5]);
    });

    test('findBy ANDs with an existing filter', () {
      final (sql, params) = compileSelect(
        from(Users.table)
            .filter(Users.active.eq(true))
            .findBy(Users.id, 5)
            .select([Users.name])
            .map(_ignore),
      );
      expect(
        sql,
        'SELECT "users"."name" FROM "users" '
        'WHERE (("users"."active" = ?) AND ("users"."id" = ?))',
      );
      expect(params, [1, 5]);
    });

    test('update set() matches value()', () {
      final (aSql, aParams) = compileWrite(
        update(Users.table).set(Users.age.set(31)).where(Users.id.eq(1)),
      );
      final (cSql, cParams) = compileWrite(
        update(Users.table).value(Users.age.set(31)).where(Users.id.eq(1)),
      );
      expect(aSql, cSql);
      expect(aParams, cParams);
    });
  });

  group('aggregates, distinct, group by', () {
    test('SELECT DISTINCT', () {
      final (sql, _) = compileSelect(
        from(Users.table).select([Users.active]).distinct().map(_ignore),
      );
      expect(sql, 'SELECT DISTINCT "users"."active" FROM "users"');
    });

    test('COUNT(*) is aliased', () {
      final (sql, _) =
          compileSelect(from(Users.table).select([countAll()]).map(_ignore));
      expect(sql, 'SELECT COUNT(*) AS "count" FROM "users"');
    });

    test('column aggregates count/sum/avg', () {
      final (sql, _) = compileSelect(
        from(Users.table)
            .select([Users.age.count(), Users.age.sum(), Users.age.avg()])
            .map(_ignore),
      );
      expect(
        sql,
        'SELECT COUNT("users"."age") AS "count_age", '
        'SUM("users"."age") AS "sum_age", '
        'AVG("users"."age") AS "avg_age" FROM "users"',
      );
    });

    test('double-column aggregates use REAL', () {
      const rating = ValueColumn<double, Posts>('posts', 'rating', SqlType.real);
      final (sql, _) = compileSelect(
        from(Posts.table).select([rating.avg(), rating.max()]).map(_ignore),
      );
      expect(
        sql,
        'SELECT AVG("posts"."rating") AS "avg_rating", '
        'MAX("posts"."rating") AS "max_rating" FROM "posts"',
      );
    });

    test('raw() selection emits verbatim SQL, params ordered before WHERE', () {
      final next =
          raw<int>('"users"."age" + ?', SqlType.integer, as: 'next_age', params: [1]);
      final (sql, params) = compileSelect(
        from(Users.table)
            .select([Users.id, next])
            .where(Users.id.eq(5))
            .map(_ignore),
      );
      expect(
        sql,
        'SELECT "users"."id", "users"."age" + ? AS "next_age" '
        'FROM "users" WHERE ("users"."id" = ?)',
      );
      expect(params, [1, 5]); // raw (projection) param precedes the WHERE param
    });

    test('GROUP BY + HAVING over an aggregate', () {
      final (sql, params) = compileSelect(
        from(Posts.table)
            .select([Posts.authorId, Posts.views.sum()])
            .groupBy([Posts.authorId])
            .having(Posts.views.sum().gt(100))
            .map(_ignore),
      );
      expect(
        sql,
        'SELECT "posts"."author_id", SUM("posts"."views") AS "sum_views" '
        'FROM "posts" GROUP BY "posts"."author_id" '
        'HAVING (SUM("posts"."views") > ?)',
      );
      expect(params, [100]);
    });
  });
}
