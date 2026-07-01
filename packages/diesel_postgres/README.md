# diesel_postgres

The **Postgres backend** for [diesel_dart](../../README.md), on
[`package:postgres`](https://pub.dev/packages/postgres) (v3).

## Status

- ✅ `PostgresDialect` — numbered `$N` placeholders (1-based) and double-quoted identifiers.
- ✅ `PostgresConnection` — the full `Connection` interface (`fetch`, `execute`, `executeReturning`,
  `executeSql`, `queryRaw`, `transaction` with savepoints, `introspect`, `close`). The same typed query DSL runs
  on SQLite and Postgres unchanged. Verified end-to-end against Postgres 16.
- ✅ Introspection via `information_schema` (tables, columns, nullability, primary keys, foreign keys) for
  `print-schema`.
- ✅ CLI `postgres://` wiring (`ConnectionFactory`) and cross-backend codecs, so `int`/`text`/`real`/`bool`/
  `DateTime` columns all work (the `diesel_dart` CLI runs migrations + `print-schema` against Postgres).
- ⬜ Advanced PG types (`uuid`, `json`/`jsonb`, `numeric`, arrays).

## Usage

```dart
final db = await PostgresConnection.open(
  host: 'localhost', port: 5432, database: 'app',
  username: 'postgres', password: 'postgres', ssl: false);

final rows = await from(Users.table).where(Users.age > 18).map(userMapper.read).load(db);
await db.close();
```

## Running the tests

The connection tests need a Postgres server; the suite **skips gracefully** if none is reachable:

```sh
docker run -d --name diesel_pg \
  -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=diesel_test -p 5433:5432 postgres:16
cd packages/diesel_postgres && dart test
```

Override the endpoint with `DIESEL_PG_HOST` / `DIESEL_PG_PORT` (defaults `localhost:5433`).
