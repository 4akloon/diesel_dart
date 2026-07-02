/// DevTools inspector for the Diesel Dart ORM.
///
/// Register live connections with [DieselDevTools.register] to browse their
/// tables, page through rows, and run raw SQL from the DevTools "diesel" tab.
/// Dev-only: the underlying `ext.diesel.*` service extensions require the VM
/// service (debug / `--observe`) and are absent from release builds.
library;

export 'src/column_filter.dart' show ColumnFilter;
export 'src/diesel_dev_tools.dart' show DieselDevTools;
export 'src/dto/column_dto.dart' show ColumnDto;
export 'src/dto/foreign_key_dto.dart' show ForeignKeyDto;
export 'src/dto/schema_dto.dart' show SchemaDto;
export 'src/dto/sql_result_dto.dart' show SqlResultDto;
export 'src/dto/table_dto.dart' show TableDto;
export 'src/dto/table_page_dto.dart' show TablePageDto;
export 'src/inspector_exception.dart' show InspectorException;
export 'src/inspector_service.dart' show InspectorService;
export 'src/registered_instance.dart' show RegisteredInstance;
