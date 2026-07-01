# Type mapping

`SqlType<T>` defines how a Dart value is `encode`d into a driver parameter and `decode`d back. The built-in
instances are `const` (which is what lets columns be `static const` and usable in annotations).

## Built-in types (SQLite backend)

| `SqlType` | Dart `T` | SQLite storage | Notes |
|---|---|---|---|
| `SqlType.integer` | `int` | `INTEGER` | |
| `SqlType.text` | `String` | `TEXT` | |
| `SqlType.real` | `double` | `REAL` | |
| `SqlType.boolean` | `bool` | `INTEGER` | `true`→`1`, `false`→`0`; any non-zero decodes to `true`. |
| `SqlType.blob` | `List<int>` | `BLOB` | |
| `SqlType.dateTime` | `DateTime` | `INTEGER` | Stored as epoch milliseconds (sortable, timezone-free). |

## Cross-backend values

Encoders produce a **canonical** Dart value (`bool` stays `bool`, `DateTime` stays `DateTime`); each backend's
`SqlDialect.encodeParam` adapts it to the driver form — SQLite maps `bool`→`int` and `DateTime`→epoch-ms, while
Postgres binds them natively. Decoders are lenient (accept either representation). So the same schema and query
DSL run unchanged on SQLite and Postgres.

## Nullable variants

For columns that allow `NULL`, use the `*OrNull` variants — the column type becomes `T?`:

`SqlType.integerOrNull`, `textOrNull`, `realOrNull`, `booleanOrNull`, `blobOrNull`, `dateTimeOrNull`.

Their decoders map a `NULL` row value to `null`. The **non-null** decoders intentionally throw on `NULL`,
which surfaces an unexpected `NULL` in a column you declared non-nullable. This is purely additive — the
`RowReader` and serializer are unchanged.

For null **predicates**, use `col.isNull()` / `col.isNotNull()` (an `eq(null)` would emit `= NULL`, which is
never true in SQL).

## SQLite caveats

SQLite has no native boolean or timestamp type. As a result:

- A `bool` column is declared `INTEGER`; introspection (`print-schema`) can't distinguish it from a plain
  integer, so a generated boolean-ish column comes back as `int` (`active` in the example). You can still use
  `SqlType.boolean` when you hand-write or adjust the schema.
- `DateTime` is stored as `INTEGER` epoch milliseconds by `SqlType.dateTime`.

The canonical introspection model (`ColumnType { integer, text, real, boolean, blob, dateTime }`) maps these
uniformly, so a future Postgres backend — which *does* have native `bool`/`timestamp` — will yield `bool` /
`DateTime` directly.

## Custom type codecs

`SqlType<T>` **is** the codec extension point (the analog of diesel-rs `ToSql`/`FromSql`) — its constructor takes
`encode`/`decode`. Keep it `const` by using top-level tear-off codecs, so it works in `static const` columns.
For example, an enum stored by name:

```dart
enum Role { admin, user, guest }

Object? _encodeRole(Role r) => r.name;
Role _decodeRole(Object? v) => Role.values.byName(v as String);
const roleType = SqlType<Role>('TEXT', _encodeRole, _decodeRole);

// in the schema:
static const role = ValueColumn<Role, Accounts>('accounts', 'role', roleType);
```

The custom type flows through reads (`r.get(Accounts.role)` → `Role`), writes (`Accounts.role.set(Role.admin)`),
and predicates (`Accounts.role.eq(Role.admin)`). `print-schema` still emits built-in types, so swap in a custom
`SqlType` by editing the generated schema; auto-mapping DB types to custom codecs is a possible future enhancement.
