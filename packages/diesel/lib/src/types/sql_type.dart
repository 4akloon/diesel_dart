/// Mapping between a Dart type `T` and its on-the-wire SQL representation.
///
/// [encode] turns a Dart value into a driver-ready parameter; [decode] turns a
/// raw value returned by the driver back into `T`. Both are top-level function
/// tear-offs so the built-in [SqlType] instances can be `const` — which is what
/// lets columns be `static const` and therefore usable inside annotations later.
library;

class SqlType<T> {
  /// SQLite storage class / column type keyword (`INTEGER`, `TEXT`, ...).
  final String sqlName;
  final Object? Function(T value) encode;
  final T Function(Object? raw) decode;

  const SqlType(this.sqlName, this.encode, this.decode);

  static const SqlType<int> integer = SqlType('INTEGER', _encInt, _decInt);
  static const SqlType<String> text = SqlType('TEXT', _encString, _decString);
  static const SqlType<double> real = SqlType('REAL', _encDouble, _decDouble);
  static const SqlType<bool> boolean = SqlType('INTEGER', _encBool, _decBool);
  static const SqlType<List<int>> blob = SqlType('BLOB', _encBlob, _decBlob);

  /// Stored as epoch milliseconds (sortable and timezone-free).
  static const SqlType<DateTime> dateTime =
      SqlType('INTEGER', _encDateTime, _decDateTime);

  // Nullable variants — use these for columns that allow NULL. Their decoders
  // map a NULL row value to `null` (the non-null ones throw on NULL, which
  // correctly surfaces an unexpected NULL in a non-null column).
  static const SqlType<int?> integerOrNull =
      SqlType('INTEGER', _encNullable, _decIntOrNull);
  static const SqlType<String?> textOrNull =
      SqlType('TEXT', _encNullable, _decStringOrNull);
  static const SqlType<double?> realOrNull =
      SqlType('REAL', _encNullable, _decDoubleOrNull);
  static const SqlType<bool?> booleanOrNull =
      SqlType('INTEGER', _encBoolOrNull, _decBoolOrNull);
  static const SqlType<List<int>?> blobOrNull =
      SqlType('BLOB', _encNullable, _decBlobOrNull);
  static const SqlType<DateTime?> dateTimeOrNull =
      SqlType('INTEGER', _encDateTimeOrNull, _decDateTimeOrNull);
}

Object? _encInt(int v) => v;
int _decInt(Object? r) => (r as num).toInt();

Object? _encString(String v) => v;
String _decString(Object? r) => r as String;

Object? _encDouble(double v) => v;
double _decDouble(Object? r) => (r as num).toDouble();

// Encoders produce a canonical Dart value; each dialect's `encodeParam` maps it
// to the driver form (SQLite: bool->int, DateTime->epoch-ms; Postgres: native).
// Decoders are lenient so they read back either representation.
Object? _encBool(bool v) => v;
bool _decBool(Object? r) => r is bool ? r : (r as num) != 0;

Object? _encBlob(List<int> v) => v;
List<int> _decBlob(Object? r) => r as List<int>;

Object? _encDateTime(DateTime v) => v;
DateTime _decDateTime(Object? r) =>
    r is DateTime ? r : DateTime.fromMillisecondsSinceEpoch((r as num).toInt());

// Nullable helpers. `_encNullable` accepts `Object?`, so it serves every type
// whose stored form is the value itself (int/String/double/blob).
Object? _encNullable(Object? v) => v;

int? _decIntOrNull(Object? r) => r == null ? null : (r as num).toInt();
String? _decStringOrNull(Object? r) => r as String?;
double? _decDoubleOrNull(Object? r) => r == null ? null : (r as num).toDouble();

Object? _encBoolOrNull(bool? v) => v;
bool? _decBoolOrNull(Object? r) =>
    r == null ? null : (r is bool ? r : (r as num) != 0);

List<int>? _decBlobOrNull(Object? r) => r as List<int>?;

Object? _encDateTimeOrNull(DateTime? v) => v;
DateTime? _decDateTimeOrNull(Object? r) => r == null
    ? null
    : (r is DateTime ? r : DateTime.fromMillisecondsSinceEpoch((r as num).toInt()));
