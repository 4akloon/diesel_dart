/// DevTools inspector for the Diesel Dart ORM.
///
/// Register live connections with [DieselDevTools.register] to browse their
/// tables, page through rows, and run raw SQL from the DevTools "diesel" tab.
/// Dev-only: the underlying `ext.diesel.*` service extensions require the VM
/// service (debug / `--observe`) and are absent from release builds.
library;

export 'src/inspector_service.dart'
    show
        ColumnDto,
        ForeignKeyDto,
        InspectorException,
        InspectorService,
        SchemaDto,
        SqlResultDto,
        TableDto,
        TablePageDto;
export 'src/registry.dart' show DieselDevTools, RegisteredInstance;
