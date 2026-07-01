# diesel_devtools

A [DevTools extension](https://docs.flutter.dev/tools/devtools/extensions) inspector for the
[Diesel Dart](../../README.md) ORM — Isar-inspector style. From the **diesel** tab in DevTools you can:

- pick the active database instance (when several are open),
- browse the table list and each table's columns / primary keys / foreign keys,
- page through a table's rows,
- run raw SQL (reads **and** writes).

It is **dev-only**: connections are exposed only after an explicit `register` call, and the underlying
`ext.diesel.*` VM service extensions exist only while the VM service is running (debug / `--observe`).
Nothing ships in a release build that never calls `register`.

## Usage

Add the dependency (dev-only is fine):

```yaml
dev_dependencies:
  diesel_devtools: ^0.0.1
```

Register each connection you want to inspect:

```dart
import 'package:diesel_devtools/diesel_devtools.dart';

final conn = SqliteConnection.open('app.db'); // or PostgresConnection…
DieselDevTools.register(conn, name: 'main');
```

Run your app with the VM service enabled (Flutter debug mode does this automatically; for a CLI use
`dart run --observe …`), open DevTools, and select the **diesel** tab.

Backend-agnostic: because it targets the `Connection` interface, the same inspector works for SQLite and
Postgres with no extra code.

## Architecture

- **Runtime (this package, pure Dart):** a registry of live `Connection`s plus an `InspectorService`
  core, surfaced over the VM service as `ext.diesel.listInstances` / `getSchema` / `getTableData` /
  `runSql`. `InspectorService` is a plain, unit-tested class — the service-extension handlers are thin
  adapters that parse string params and JSON-encode results.
- **UI (`devtools_extension/`, Flutter):** a Flutter web app compiled into `extension/devtools/build/`
  that DevTools loads and which calls those service extensions.

## Try it without DevTools

```bash
dart run --observe packages/diesel_devtools/tool/inspector_demo.dart
```

Seeds an in-memory database, prints what the inspector core sees, and stays alive so you can attach
DevTools to the printed VM service URI.
