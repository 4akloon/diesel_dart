import 'package:diesel/diesel.dart';

/// SQLite: double-quoted identifiers and positional `?` placeholders.
final class SqliteDialect implements SqlDialect {
  const SqliteDialect();

  @override
  String quoteIdentifier(String name) => '"${name.replaceAll('"', '""')}"';

  @override
  String placeholder(int index) => '?';

  @override
  Object? encodeParam(Object? value) {
    if (value is bool) return value ? 1 : 0;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return value;
  }
}
