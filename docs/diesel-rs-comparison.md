# diesel_dart vs diesel-rs

How diesel_dart maps to [diesel-rs](https://github.com/diesel-rs/diesel), feature by feature, and where the
gaps are. This is the basis for the [roadmap](ROADMAP.md).

Status legend: ✅ parity · ◑ partial · ✗ gap.

Two languages, two idioms: diesel-rs uses Rust traits + derive macros + the `table!` macro; diesel_dart uses
Dart generics + phantom types + `build_runner`/`source_gen` codegen. The goal is **behavioral** parity and
**database** compatibility, not identical syntax.

---

## Schema definition

| Concept | diesel-rs | diesel_dart | Status | Notes |
|---|---|---|---|---|
| Table/column declaration | `table! { users { id -> Integer, .. } }` | generated `abstract final class Users { static const id = PrimaryKey<…>(…); … static const table = TableRef(…); }` | ◑ | Both generated from the DB by `print-schema`; different shape. |
| Foreign keys | `joinable!(posts -> users (user_id))` | `Ref<T, Tbl, Target>` column references the target `PrimaryKey` | ✅ | FK is first-class on the column; powers `onFk:` joins. |
| Cross-table query allow-list | `allow_tables_to_appear_in_same_query!` | runtime FROM/JOIN scope validation in the serializer | ◑ | diesel checks at compile time; we check at build/serialize time (`StateError`). |
| Column type override / docs in print-schema | `[print_schema]` patches, `#[sql_name]` | not yet | ✗ | See ROADMAP. |

## Query DSL

| Concept | diesel-rs | diesel_dart | Status |
|---|---|---|---|
| Filter | `users.filter(age.gt(18))` | `.where(...)` (replaces) or `.filter(...)` (ANDs, like diesel) | ✅ |
| Operators | `.eq/.ne/.gt/.ge/.lt/.le` | same, plus `>`,`<`,`>=`,`<=` sugar | ✅ |
| AND / OR | `.and()`/`.or()` | `.and()`/`.or()` and `&` / `\|` | ✅ |
| IN | `.eq_any(v)` | `.isIn(v)` / `.eqAny(v)` | ✅ |
| LIKE / BETWEEN / NULL | `.like`, `.between`, `.is_null` | `.like`, `.between`, `.isNull`/`.isNotNull` | ✅ |
| Ordering | `.order(name.asc())` | `.orderBy(...)` / `.order(...)` | ✅ |
| Limit / offset | `.limit/.offset` | `.limit/.offset` | ✅ |
| Projection | `.select((id, name))` | `.select([Users.id, Users.name])` | ✅ |
| Inner/left join | `.inner_join/.left_join` | `.innerJoin/.leftJoin` (`on:` / `onFk:`) | ✅ |
| Self-join / aliases | table aliasing | `Users.table.aliased('mgr')` + `alias.col(...)` | ✅ |
| `find(pk)` | `users.find(1)` | `findBy(Users.id, 1)` (type-safe; bare auto-PK `find` is a codegen follow-up) | ✅ |
| `first` / `optional` | `.first(conn)` / `.optional()` | `query.first(db)` / `query.optional(db)` | ✅ |
| distinct | `.distinct()` | `.distinct()` | ✅ |
| Aggregates / group by / having | `count`, `sum`, `.group_by`, `.having` | `countAll()`/`col.count()`/`sum()`/`avg()`/`min()`/`max()`, `.groupBy()`, `.having()` | ✅ (int + double cols) |
| Subqueries / EXISTS | supported | — | ✗ |
| Raw typed SQL | `sql::<T>("…")` | `raw<T>(sql, type, as:)` selection + `rawCondition(...)`; also `executeSql`/`queryRaw` | ✅ |

> **Behavioral note:** diesel_dart provides `.filter()` (ANDs repeated calls, like diesel-rs) alongside
> `.where()` (replaces the predicate — combine with `&` for a single call).

## Execution

| Concept | diesel-rs | diesel_dart | Status |
|---|---|---|---|
| Load rows | `.load::<T>(conn)` / `.get_results` | `db.fetch(...)`, or `query.load(db)` / `first(db)` / `optional(db)` | ✅ |
| Run write | `.execute(conn)` | `db.execute(stmt)` → affected rows | ✅ |
| RETURNING | `.get_result(conn)` after insert | `stmt.returning([...]).map(...)` + `db.executeReturning` | ✅ |
| Batch insert | `insert_into(t).values(vec)` | `insertInto(t).values([[...], [...]])` | ✅ |
| Upsert / ON CONFLICT | `.on_conflict(...)` | `insertInto(t).onConflict([...]).doNothing()` / `.doUpdate([...])` (with `excluded`) | ✅ |
| Transactions | `conn.transaction(\|\| …)` | `db.transaction((tx) async { … })` | ✅ |
| Nested tx (savepoints) | yes | yes | ✅ |
| Raw SQL | `sql_query` | `executeSql` / `queryRaw` | ✅ |
| Connection pooling | r2d2 / deadpool | — | ✗ (ROADMAP M6) |

## Derives

| diesel-rs derive | diesel_dart | Status | Notes |
|---|---|---|---|
| `Queryable` | `@Queryable(table)` → `RowMapper`, `$XFromRow` | ✅ | Reads by column name via `RowReader`. |
| `Selectable` | `@Queryable` subset class → select-narrowing `xQuery` getter | ✅ | A class with a subset of columns generates an `xQuery` that `SELECT`s just those columns. |
| `Insertable` | `@Insertable(table)` → `toInsert()` | ✅ | |
| `AsChangeset` | `@AsChangeset(table)` → `toUpdate()` | ✅ | SET-only; caller adds `.where`. |
| `Identifiable` | — | ✗ | ROADMAP M4. |
| `Associations` / `belongs_to` | `@Relation` nesting + `loadGroupedByFk(...)` for grouped child loads | ✅ | Read-side nesting plus one-query, N+1-avoiding grouped children. |
| field rename / skip | `@Column(col)` rename; read/write via `readOnly`/`writeOnly` | ✅ | `@ignore` was removed in favor of getters. |

## Types

| Concept | diesel-rs | diesel_dart | Status |
|---|---|---|---|
| Integer/text/real/bool/blob | `sql_types::*` | `SqlType.integer/text/real/boolean/blob` | ✅ (SQLite mappings) |
| Timestamp | `Timestamp`/`Timestamptz` | `SqlType.dateTime` (epoch ms in SQLite) | ◑ |
| Nullable | `Nullable<T>` | `SqlType.*OrNull` (`T?`) | ✅ |
| Custom / enum codecs | `#[derive(...)]` + `ToSql`/`FromSql` | custom `const SqlType<T>(sqlName, encode, decode)` | ✅ |
| Postgres numeric/json/uuid/array | native | — | ✗ (ROADMAP M5) |

## CLI & configuration

| Concept | diesel-rs (`diesel`) | diesel_dart (`diesel_dart`) | Status |
|---|---|---|---|
| Commands | `setup`, `migration generate/run/revert/redo/list`, `database reset`, `print-schema` | same set | ✅ |
| Config file | `diesel.toml` (`[print_schema]`, `[migrations_directory]`) | `diesel.yaml` (`database_url`, `migrations_dir`) | ✗ (intentional — YAML by design; `diesel.toml` not planned) |
| `DATABASE_URL` | `.env` | env var | ✅ |
| print-schema output | `schema.rs` (`table!`) | `schema.dart` (`abstract final class`) | ◑ (analogous) |
| Embedded migrations | `embed_migrations!` | — | ✗ |
| Shell completions | `diesel completions` | — | ✗ |

## Backends

| Backend | diesel-rs | diesel_dart | Status |
|---|---|---|---|
| SQLite | ✅ | ✅ | ✅ |
| Postgres | ✅ (primary) | stub (`ConnectionFactory` dispatches `postgres://`) | ✗ (ROADMAP M5) |
| MySQL | ✅ | — | ✗ (ROADMAP M6) |

## Database compatibility (sharing one DB with the Rust CLI)

| Item | diesel-rs | diesel_dart | Status |
|---|---|---|---|
| Tracker table name | `__diesel_schema_migrations` | `__diesel_schema_migrations` | ✅ |
| Tracker DDL | `version VARCHAR(50) PK NOT NULL`, `run_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP` | identical | ✅ |
| Migration version format | `%Y-%m-%d-%H%M%S` (e.g. `2024-01-15-123456`) | identical | ✅ |
| Migration layout | `migrations/<version>_<name>/{up,down}.sql` | same | ✅ |
| Reading diesel's dashed version | n/a | `discover()` splits on first `_` → reads it | ✅ |
| `run_on` value | `YYYY-MM-DD HH:MM:SS` | identical | ✅ |

**Bottom line:** on SQLite the two tools now produce an interchangeable migrations directory and
`__diesel_schema_migrations` table — DDL, version format, and `run_on` all match ([ROADMAP M1](ROADMAP.md)
done). The same database and `migrations/` directory can be driven by either CLI.
