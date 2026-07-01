# Roadmap

Direction for aligning diesel_dart with [diesel-rs](https://github.com/diesel-rs/diesel): **database
compatibility** (share one database/migrations directory with the Rust `diesel` CLI) and **mirror behavior**
(read like diesel). Priorities reflect agreed decisions: **SQLite-first** (Postgres deferred), and mirror
behavior delivered as **non-breaking diesel-style aliases** rather than a rename.

Status legend: ✅ done · ◑ partial · ⬜ planned.

See [`diesel-rs-comparison.md`](diesel-rs-comparison.md) for the feature-by-feature gap analysis this roadmap
is derived from.

---

## ✅ Done (M0 and earlier)

- **Core query builder** — typed `from/where/orderBy/limit/offset/select`, predicates + `&`/`|`, writes
  (`insertInto`/`update`/`deleteFrom`), serializer + dialect seam.
- **Joins & relations** — `innerJoin`/`leftJoin` (`on:`/`onFk:`), self-joins via aliases, two-tier scope safety.
- **Async-first `Connection`** + SQLite backend (`diesel_sqlite`), transactions with SAVEPOINTs.
- **Migrations CLI** (`diesel_dart`) — generate/run/revert/redo/list, `database reset`, `setup`.
- **`print-schema`** — dialect-agnostic introspection → typed Dart schema.
- **Derives** — `@Queryable` (+ `@Relation`), `@Insertable`, `@AsChangeset`, `@Column(readOnly/writeOnly)`.
- **M0 — Documentation** (this milestone): CLAUDE.md, READMEs, `docs/`, comparison, this roadmap.

---

## ✅ M1 — diesel-rs database compatibility (SQLite, shared DB) — done

The Rust `diesel` CLI and `diesel_dart` now produce an interchangeable migrations directory and tracker
table on SQLite — the same database and `migrations/` directory can be driven by either tool:

- Scaffolder emits diesel's `%Y-%m-%d-%H%M%S` version (e.g. `2024-01-15-123456`).
  (`migration_scaffolder.dart`; `discover()` splits on the first `_`, so it already reads the dashed prefix.)
- `__diesel_schema_migrations` DDL matches diesel: `version VARCHAR(50) PRIMARY KEY NOT NULL`,
  `run_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP`. (`migration_runner.dart`)
- `run_on` is written in diesel's `YYYY-MM-DD HH:MM:SS` form. (`migration_runner.dart`)
- The example's migrations were renamed to the dashed format.

> Config stays on `diesel.yaml` by design — `diesel.toml` support is intentionally **not** planned.

## ✅ M2 — Mirror-behavior API aliases (non-breaking) — done

diesel-named methods alongside the Dart-idiomatic ones, so code reads like diesel-rs:

- `filter` — ANDs repeated calls (like diesel; distinct from `where`, which replaces).
- `order` (alias for `orderBy`), `eqAny` (alias for `isIn`), `update().set()` (alias for `value`).
- Execution terminals `query.load(db)` / `first(db)` / `optional(db)`, as an extension that keeps the core
  query builder free of any `Connection` dependency.
- Name mapping documented in [`diesel-rs-comparison.md`](diesel-rs-comparison.md) and [`query-dsl.md`](query-dsl.md).

Deferred: `find(pk)` (moved to M4 — needs a type-safe primary key). (Insert `values([...])` was later delivered
as M3 batch insert.)

## ✅ M3 — SQLite query parity — done

- Aggregates (`countAll()`, `col.count()/sum()/avg()/min()/max()`), `groupBy` / `having`, and `distinct`. Built on
  a generalized projection (`Selection` = a column or an `Aggregate`), with new AST nodes (`FunctionNode`,
  `Projection`) so the serializer stays schema-free; `RowReader.get` now accepts any `Selection`. Aggregates cover
  int and double columns.
- `RETURNING` on writes: `stmt.returning([cols]).map(...)` + `Connection.executeReturning` (returns decoded rows;
  unlocks reading autoincrement ids after insert). UPDATE/DELETE RETURNING work too.
- Batch insert: `insertInto(t).values([[...], [...]])` (multiple rows in one statement); composes with RETURNING.
- Upsert: `insertInto(t).onConflict([cols]).doNothing()` / `.doUpdate([col.setToExcluded()/col.set(v)])`
  (`ON CONFLICT … DO NOTHING / DO UPDATE SET`, with `excluded.col` support).
- Raw typed SQL escape hatch: `raw<T>(sql, type, as:)` (typed, readable selection) and `rawCondition(sql)`
  (boolean fragment for `having`/joined `where`), with `?` placeholders. Also `executeSql`/`queryRaw` for full raw.

## ◑ M4 — Derive parity (in progress)

Done:
- `find(pk)` — `findBy(key, value)` on `Query`/`MappedQuery` (type-safe filter by a key column; value type pinned
  by the column, ANDs with any existing predicate). A bare `find(value)` that auto-detects the PK from the schema
  is a codegen follow-up (see Identifiable below).

Remaining:
- `Selectable`-style subset/embedded structs (project a column subset into a class).
- `Identifiable` (primary-key identity) — including a generated bare `find(value)` — and richer Associations
  (`belongs_to`, grouped child loads) beyond today's read-only `@Relation` nesting.
- Custom type-codec registry (enums, value objects) layered on `SqlType`.

## ⬜ M5 — Postgres backend (`diesel_postgres`)

- Async driver, `$N` placeholders, `information_schema`/`pg_catalog` introspection.
- PG types (`timestamptz`, `uuid`, `json`/`jsonb`, `numeric`, arrays).
- Real cross-tool Postgres compatibility (diesel's primary database). `ConnectionFactory` already dispatches
  on the `postgres://` URL scheme.

## ⬜ M6 — Later

- MySQL backend.
- Connection pooling.
- Instrumentation / query logging.
- Schema-first (auto-diff migrations from a Dart schema) — the experimental "Stage 4" direction.
