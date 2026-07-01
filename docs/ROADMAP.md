# Roadmap

diesel_dart's alignment with [diesel-rs](https://github.com/diesel-rs/diesel) — database compatibility and
mirror behavior. Feature-by-feature detail is in [`diesel-rs-comparison.md`](diesel-rs-comparison.md).

## Done (M1–M5)

- **M1 — DB compatibility:** migrations interoperate with the Rust `diesel` CLI on SQLite (`%Y-%m-%d-%H%M%S`
  versions, matching `__diesel_schema_migrations` DDL, `run_on` format).
- **M2 — Mirror-behavior aliases:** `filter` (ANDs), `order`, `eqAny`, `update().set()`, and terminals
  `load` / `first` / `optional`.
- **M3 — SQLite query parity:** aggregates + `group_by`/`having`, `distinct`, `RETURNING`, batch insert, upsert
  (`ON CONFLICT`), raw typed `sql`.
- **M4 — Derive parity:** `findBy`, Selectable subset getters, custom `SqlType` codecs, `belongs_to`
  (`loadGroupedByFk`), and generated bare `findX(pk)`.
- **M5 — Postgres backend (`diesel_postgres`):** `PostgresConnection` + `PostgresDialect` (`$N`) + introspection,
  cross-backend `bool`/`DateTime` codecs, and CLI `postgres://` wiring — verified end-to-end against Postgres 16.
  SQLite and Postgres run the same DSL, schema, and migrations unchanged.

## Later (optional)

- MySQL backend (`diesel_mysql`).
- Connection pooling; query logging / instrumentation.
- Advanced Postgres types (`uuid`, `json`/`jsonb`, `numeric`, arrays).
- A true Postgres `database reset` (drop schema); reading `diesel.toml` is intentionally out of scope.
- Schema-first: a Dart schema as the source of truth with auto-diff migrations (experimental).
