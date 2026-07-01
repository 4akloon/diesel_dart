# Query DSL

The builder is a pure transformation into `(sql, params)`; a [`Connection`](#execution) runs it. Examples use
the `Users`/`Posts` schema from [`example/`](../example).

## Building a SELECT

Start with `from(source)`, refine, then finish with `.map(decoder)`:

```dart
final q = from(Users.table)            // Query<Users>
    .where(Users.age > 18)
    .orderBy(Users.name.asc())
    .limit(20)
    .offset(0)
    .map((r) => User(r.get(Users.id), r.get(Users.name), r.get(Users.age), r.get(Users.active)));
// q is a MappedQuery<User> (a SelectQuery<User>) — pass it to db.fetch.
```

- **`from(QuerySource)`** — a `TableRef` or a `TableAlias`. Single-table queries are `Query<Tbl>`, which keeps
  `where` compile-time scoped to that table.
- **Projection is automatic** (all columns of the involved tables). Narrow it with
  `.select([Users.name, Users.age])`.
- **`.map((RowReader r) => …)`** decides the result shape — a scalar, a record, a data class, nested objects.
  This single terminal replaces any `selectN`/`selectJoinN` family.
- **`.mapWith(rowMapper)`** is sugar for `.map(rowMapper.read)` using a generated/ reusable `RowMapper`.

## RowReader

Inside `.map`, read values **by column** (not by position) with `r.get(column)`:

```dart
.map((r) => '${r.get(Posts.title)} (${r.get(Posts.views)})')
```

`RowReader` keys by `table.name` (alias-aware), so column order and joins never matter. Reading a column that
isn't in the projection throws a `StateError`.

## Predicates

All return `Expression<bool, Tbl>`:

| Method | SQL |
|---|---|
| `col.eq(v)` / `col.ne(v)` | `= ?` / `<> ?` |
| `col.gt/ge/lt/le(v)` | `> ? / >= ? / < ? / <= ?` |
| `col > v`, `col < v`, `col >= v`, `col <= v` | operator sugar for the above |
| `col.isIn([...])` | `IN (?, ?, …)` |
| `col.between(lo, hi)` | `BETWEEN ? AND ?` |
| `col.isNull()` / `col.isNotNull()` | `IS NULL` / `IS NOT NULL` |
| `col.like('%a%')` | `LIKE ?` (text columns only) |
| `a.eqColumn(b)` | `a = b` (column-to-column; shared key type enforced) |

Combine predicates with `&` (AND) / `\|` (OR), or `.and()` / `.or()`:

```dart
from(Users.table).where((Users.age > 28) & Users.active.eq(1));
```

> **`where` vs `filter`:** chaining `.where(a).where(b)` **replaces** the predicate (last wins) — use a single
> `.where(...)` with `&`/`|`, or use the diesel-style `.filter(...)`, which **ANDs** repeated calls
> (`filter(a).filter(b)` ⇒ `WHERE a AND b`). See [diesel-style aliases](#diesel-style-aliases).

## Ordering, limit, offset

```dart
from(Users.table).orderBy(Users.age.desc()).limit(2).offset(0);
```

`col.asc()` / `col.desc()` produce `Ordering`s.

## Joins

```dart
// FK-driven: the ON is derived from the Ref (posts.author_id = users.id).
from(Posts.table)
    .leftJoin(Users.table, onFk: Posts.authorId)
    .map((r) => '${r.get(Posts.title)} <- ${r.get(Users.name)}');

// Explicit ON with eqColumn (required for self-joins).
final mgr = Users.table.aliased('mgr');
from(Users.table)
    .innerJoin(mgr, on: Users.managerId.eqColumn(mgr.col(Users.id)))
    .map((r) => '${r.get(Users.name)} -> ${r.get(mgr.col(Users.name))}');
```

- `innerJoin` / `leftJoin` take either `on:` (an `Expression<bool>`) or `onFk:` (a `Ref` column).
- Joins **chain** freely; the projection auto-expands with the joined table's columns.
- **Self-joins / multiple FKs to one table** use aliases: `Users.table.aliased('mgr')`, then address columns
  via `mgr.col(Users.id)`. The serializer emits `"users" AS "mgr"` and `RowReader` keys by the alias, so
  `mgr.id` ≠ `users.id`.
- Generated relation queries (`@Relation`) do all of this for you — see [derives.md](derives.md).

### Scope safety (two tiers)

- **Single-table** queries are fully compile-time scoped: `from(Users.table).where(Posts.id.eq(1))` does not
  compile.
- **Joined** queries relax to `Query<Object?>`; the serializer then validates at build time that every
  referenced table/alias is in the FROM/JOIN clause, throwing `StateError` otherwise.

## Writes

```dart
await db.execute(insertInto(Users.table)
    .value(Users.name.set('Bob'))
    .value(Users.age.set(30)));

await db.execute(update(Users.table)
    .value(Users.active.set(1))
    .where(Users.id.eq(3)));

await db.execute(deleteFrom(Posts.table).where(Posts.views.lt(10)));
```

Values go through `column.set(value)`, whose type is pinned by the column — `Users.age.set('x')` is a compile
error. `@Insertable` / `@AsChangeset` generate `toInsert()` / `toUpdate()` so you can write whole objects
(see [derives.md](derives.md)).

### Batch insert

Insert several rows in one statement with `.values([...])` — a list of rows; columns are taken from the first
row (don't mix with the single-row `.value(...)`):

```dart
await db.execute(insertInto(Users.table).values([
  [Users.name.set('A'), Users.age.set(20), Users.active.set(true)],
  [Users.name.set('B'), Users.age.set(21), Users.active.set(false)],
]));
```

It composes with RETURNING (below) to get one row back per inserted row.

### RETURNING

Get columns back from a write with `.returning([...]).map(...)` run via `db.executeReturning(...)` — handy for
database-generated ids:

```dart
final ids = await db.executeReturning(
  insertInto(Users.table)
      .value(Users.name.set('Bob'))     // id omitted → autoincrement
      .returning([Users.id])
      .map((r) => r.get(Users.id)),
);
final newId = ids.single;
```

Works for UPDATE/DELETE too. RETURNING columns are referenced unqualified (as SQLite requires); values are read
back positionally through the same `RowReader`.

### Upsert (ON CONFLICT)

`insertInto(...).onConflict([cols])` then `.doNothing()` or `.doUpdate([...])`:

```dart
// Ignore duplicates.
await db.execute(insertInto(Users.table)
    .value(Users.id.set(1)).value(Users.name.set('Bob'))
    .onConflict([Users.id]).doNothing());

// Replace on conflict: setToExcluded() takes the value from the row that failed
// to insert; set(v) uses a literal.
await db.execute(insertInto(Users.table)
    .value(Users.id.set(1)).value(Users.name.set('Bob'))
    .onConflict([Users.id])
    .doUpdate([Users.name.setToExcluded(), Users.age.set(0)]));
```

### Raw SQL fragments (escape hatch)

For expressions the builder doesn't model, `raw<T>(sql, type, as:)` is a typed, readable selection, and
`rawCondition(sql)` is a boolean fragment for `having` (or a joined `where`). Use `?` placeholders + `params`:

```dart
final nextAge = raw<int>('age + 1', SqlType.integer, as: 'next_age');
final rows = await from(Users.table)
    .select([Users.id, nextAge])
    .map((r) => (r.get(Users.id), r.get(nextAge)))
    .load(db);
```

You write the SQL (qualify columns yourself); it's non-portable by nature. For full escape hatches, see
`Connection.executeSql` / `queryRaw`.

## Execution

```dart
final db = SqliteConnection.open('app.db');     // or SqliteConnection.memory()

await db.fetch(selectQuery);                     // Future<List<R>>
await db.execute(writeStatement);               // Future<int> (affected rows)
await db.executeSql('VACUUM');                   // raw DDL/SQL
await db.queryRaw('SELECT count(*) AS n FROM users');  // List<Map<String,Object?>>
await db.transaction((tx) async { /* … */ });   // BEGIN/COMMIT, nested = SAVEPOINT
await db.close();
```

The API is async-first; SQLite returns completed futures, and an async backend (Postgres) implements the same
`Connection` interface unchanged.

## Aggregates & grouping

Aggregate helpers are *selections* — pass them to `.select([...])` and read them back with the same handle:

```dart
// COUNT(*) over the whole table.
final total = countAll();
final n = await from(Users.table).select([total]).map((r) => r.get(total)).first(db);

// Column aggregates (currently on int columns): count / sum / avg / min / max.
final sumAge = Users.age.sum();   // int?
final avgAge = Users.age.avg();   // double?
final (s, a) = await from(Users.table)
    .select([sumAge, avgAge])
    .map((r) => (r.get(sumAge), r.get(avgAge)))
    .first(db);
```

`GROUP BY` + `HAVING` (HAVING is written over an aggregate comparison):

```dart
final perAuthor = Posts.views.sum();
final rows = await from(Posts.table)
    .select([Posts.authorId, perAuthor])
    .groupBy([Posts.authorId])
    .having(perAuthor.gt(100))
    .map((r) => (r.get(Posts.authorId), r.get(perAuthor)))
    .load(db);
```

`SELECT DISTINCT` via `.distinct()`:

```dart
final kinds = await from(Users.table)
    .select([Users.active])
    .distinct()
    .map((r) => r.get(Users.active))
    .load(db);
```

> Aggregate result types: `count`/`countAll` → `int`; `sum`/`min`/`max` → `int?`; `avg` → `double?`
> (SQLite returns NULL over an empty set). Non-int numeric columns are on the roadmap.

## diesel-style aliases

If you're coming from diesel-rs, several methods read the same way (the Dart-idiomatic names still work too):

| diesel-rs | diesel_dart |
|---|---|
| `users.filter(p)` | `from(Users.table).filter(p)` — ANDs repeated calls |
| `.order(col.asc())` | `.order(Users.col.asc())` — alias for `orderBy` |
| `col.eq_any([...])` | `Users.col.eqAny([...])` — alias for `isIn` |
| `update(t).set(col.eq(v))` | `update(Users.table).set(Users.col.set(v))` |
| `query.load(conn)` | `query.load(db)` |
| `query.first(conn)` | `query.first(db)` — throws if no rows |
| `query.first(conn).optional()` | `query.optional(db)` — `null` if no rows |
| `users.find(1)` | `from(Users.table).findBy(Users.id, 1)` — value type pinned by the column |

```dart
final adults = await from(Users.table)
    .filter(Users.age.ge(18))
    .order(Users.name.asc())
    .map(userMapper.read)
    .load(db);

final bob = await from(Users.table)
    .filter(Users.id.eqAny([1]))
    .map(userMapper.read)
    .optional(db);
```

diesel's bare `find(1)` auto-detects the primary key; `findBy(Users.id, 1)` is the type-safe equivalent (the
value is checked against the column's type). An auto-PK bare `find` is a codegen follow-up — see the
[roadmap](ROADMAP.md).
