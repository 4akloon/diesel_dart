# CLAUDE.md

Guidance for Claude Code (and humans) working in this repository.

## What this is

**diesel_dart** is a type-safe ORM for Dart, inspired by [diesel-rs](https://github.com/diesel-rs/diesel).
It is a Dart **pub workspace** (monorepo) with a dialect-agnostic core and pluggable backends. Current
backend: SQLite. Status: early/experimental, unpublished (all packages `0.0.1`, path/workspace deps).

## Core principle

**Build vs execute separation.** The query builder is a pure transformation of a typed AST into
`(String sql, List<Object?> params)` (`QueryBuilder` + `SqlDialect`), with zero driver dependency. A
`Connection` implementation serializes and runs the result against a real driver. This keeps serialization
trivially unit-testable and makes new backends drop-in.

## Workspace layout

| Path | Package | Role |
|---|---|---|
| `packages/diesel` | `diesel` | Dialect-agnostic core: types, schema, expressions, query/write builders, serializer, `Connection`/`SqlDialect` interfaces, annotations. No driver dep. |
| `packages/diesel_sqlite` | `diesel_sqlite` | SQLite backend: `SqliteConnection` + `SqliteDialect` (on `package:sqlite3`). |
| `packages/diesel_postgres` | `diesel_postgres` | Postgres backend: `PostgresConnection` + `PostgresDialect` (on `package:postgres`), with `information_schema` introspection. |
| `packages/diesel_cli` | `diesel_cli` | `diesel_dart` executable: migrations + `print-schema`. |
| `packages/diesel_codegen` | `diesel_codegen` | `build_runner`/`source_gen` derives for the annotations. |
| `packages/diesel_devtools` | `diesel_devtools` | DevTools inspector: `Connection` registry + `InspectorService` over `ext.diesel.*` VM service extensions (browse tables, view rows, run SQL). Runtime is pure Dart; the Flutter UI lives in `devtools_extension/`. |
| `example/` | `diesel_example` | End-to-end demo (migrations → schema → models → queries). |

Dart SDK constraint: `>=3.5.0 <4.0.0`.

## Commands

- **Analyze:** `dart analyze packages/diesel packages/diesel_sqlite packages/diesel_cli packages/diesel_codegen example`
- **Test a package:** `cd packages/<pkg> && dart test`
- **CLI** (run from a directory containing `diesel.yaml`, e.g. `example/`): `dart run diesel_cli:diesel_dart <command>`
  - `setup` · `migration generate <name>` · `migration run` · `migration revert` · `migration redo` ·
    `migration list` · `database reset` · `print-schema [-o <file>]`
- **Codegen** (in `example/`): `dart run build_runner build`

## Key invariants & conventions (don't break these)

- **async-first `Connection`** — every method returns `Future`; `FutureOr` only on the `transaction`
  callback. SQLite runs synchronously and returns completed futures; this is what lets a future async backend
  (Postgres) implement the same interface unchanged. (`packages/diesel/lib/src/connection.dart`)
- **Columns are `static const`** on an `abstract final class` table marker — the same `const TableColumn`
  object is used by the query builder AND inside annotations (annotation args must be const).
- **The core column type is `TableColumn<T, Tbl>`** (sealed: `ValueColumn` / `PrimaryKey` / `Ref`). The name
  **`Column` is the field annotation**, not the column type — don't confuse them
  (`schema/table.dart` vs `annotations/column.dart`).
- **Two-tier join safety:** single-table `from(t)` is `Query<Tbl>` (compile-time-scoped `where`); after a
  join it relaxes to `Query<Object?>` and `QueryBuilder._validateScope` validates at build time that every
  referenced table is in the FROM/JOIN clause (`StateError` otherwise).
- **`RowReader` reads by selection key** — columns by `table.name` (alias-aware), aggregates by alias — not
  by position (order-independent, join-safe). The projection is a `List<Selection>` (columns *or* `Aggregate`s);
  the serializer consumes AST-level `Projection`s so it stays schema-free.
- **Codegen pipeline:** `EdgeAnalyzer` (analyzer → model) → pure string emitters
  (`ReaderEmitter` / `InsertEmitter` / `ChangesetEmitter` / relation emitters) → `SharedPartBuilder` with
  **three** generators (`QueryableGenerator`, `InsertableGenerator`, `AsChangesetGenerator`) registered in
  `builder.dart`. Emitters are pure and unit-tested; generators are thin analyzer bridges.
- **GOTCHA: chained `.where().where()` REPLACES the predicate (last wins), it does not AND.** Combine with
  `&` (`q.where(a.eq(1) & b.isNotNull())`), or use `.filter()` — the diesel-style method that ANDs repeated
  calls. (`Query.where` does `_copy(whereNode: ...)`; `filter` ANDs onto the existing `whereNode`.)
- **Avoid `!`** — prefer `if (x case final y?)` / pattern matching for null handling (project style).

## Where things live (core, `packages/diesel/lib/src/`)

- Types & codecs: `types/sql_type.dart`
- Schema (`TableColumn`/`PrimaryKey`/`Ref`/`TableRef`/`QuerySource`/`TableAlias`): `schema/table.dart`
- Expressions + `&`/`|` combinators: `expression/expression.dart`
- Query builder + `RowReader` + `RowMapper`: `query/query.dart`, `query/row_reader.dart`
- Writes (`insertInto`/`update`/`deleteFrom` + `TableColumn.set`): `query/write.dart`
- AST nodes: `ast/sql_node.dart`
- Serializer + scope validation: `serialize/query_builder.dart`; dialect seam: `serialize/sql_dialect.dart`
- `Connection`: `connection.dart`; introspection model: `schema/introspection.dart`
- Annotations: `annotations/{queryable,insertable,as_changeset,column,relation}.dart`

## How to extend

- **New backend:** implement `Connection` + `SqlDialect` + `introspect()` in a new `diesel_<db>` package,
  then wire it into `ConnectionFactory.open` by URL scheme. No command/core changes needed.
- **New annotation/derive:** add the annotation in `packages/diesel/lib/src/annotations/`, a `TypeChecker` +
  parsing in `edge_analyzer.dart`, a pure emitter, a `GeneratorForAnnotation` (see `write_generator.dart`),
  and register it in `builder.dart`'s `SharedPartBuilder`.
- **New CLI command:** add a `Command` under `diesel_cli/lib/src/commands/` (extend `DbCommand` for
  DB-connected commands) and register it in `CliRunner.build()`.

## Test map

- Serializer (SQL/params, scope validation, joins): `packages/diesel/test/serializer_test.dart`
- SQLite round-trips, joins, transactions, nullable: `packages/diesel_sqlite/test/integration_test.dart`
- Migrations + print-schema/introspection: `packages/diesel_cli/test/{migrations_test,print_schema_test}.dart`
- Codegen emitters + generate + relation tree: `packages/diesel_codegen/test/*`
- End-to-end: `example/` (`dart run build_runner build`, then `dart run bin/example.dart`)

## diesel-rs alignment

This project deliberately mirrors diesel-rs concepts. The alignment roadmap **M1–M5 is complete**: SQLite
migration compatibility with the Rust `diesel` CLI, diesel-style API aliases, SQLite query parity, derive parity,
and a full Postgres backend — SQLite and Postgres run the same DSL/schema/migrations unchanged. See
[`docs/diesel-rs-comparison.md`](docs/diesel-rs-comparison.md) for the parity matrix and
[`docs/ROADMAP.md`](docs/ROADMAP.md) for remaining/optional work.
