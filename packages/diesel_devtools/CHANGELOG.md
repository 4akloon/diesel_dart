## 0.0.1

- Initial runtime layer for the diesel DevTools inspector: a `DieselDevTools` connection registry and an
  `InspectorService` core exposed over the VM service as `ext.diesel.listInstances` / `getSchema` /
  `getTableData` / `runSql`. Backend-agnostic (SQLite + Postgres). UI extension to follow.
