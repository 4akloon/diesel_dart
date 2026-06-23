// source_gen 2.x is built on analyzer's classic element model (the API
// `generateForAnnotatedElement` hands us a classic `Element`). That model is
// deprecated in favour of `Element2`, but migrating requires a newer source_gen;
// the classic API is correct for this version.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:diesel/diesel.dart';
import 'package:source_gen/source_gen.dart';

/// Generates a `RowMapper<T>` + a `_$<T>FromRow` reader for each class annotated
/// with `@Queryable(SomeTable)`. The reader maps every constructor parameter to
/// `SomeTable.<column>` via `RowReader.get`; `@MapColumn('sql_name')` overrides
/// the column and `@ignore` skips a parameter (it must be optional).
class QueryableGenerator extends GeneratorForAnnotation<Queryable> {
  const QueryableGenerator();

  static const _mapColumn = TypeChecker.fromRuntime(MapColumn);
  static const _ignore = TypeChecker.fromRuntime(Ignore);

  @override
  String generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
          '@Queryable can only be applied to classes.',
          element: element);
    }

    final tableName = annotation.read('table').typeValue.element?.name;
    if (tableName == null) {
      throw InvalidGenerationSourceError(
          '@Queryable(table) must reference a table marker class.',
          element: element);
    }

    final constructor = element.unnamedConstructor;
    if (constructor == null) {
      throw InvalidGenerationSourceError(
          '${element.name} needs an unnamed constructor to be @Queryable.',
          element: element);
    }

    final className = element.name;
    final args = <String>[];
    for (final param in constructor.parameters) {
      final field = element.getField(param.name);

      if (field != null && _ignore.hasAnnotationOfExact(field)) {
        if (param.isRequiredPositional || param.isRequiredNamed) {
          throw InvalidGenerationSourceError(
              'Ignored field "${param.name}" must be optional so its default '
              'can be used.',
              element: param);
        }
        continue; // omit → constructor default applies
      }

      var accessor = param.name;
      if (field != null) {
        final override = _mapColumn
            .firstAnnotationOfExact(field)
            ?.getField('column')
            ?.toStringValue();
        if (override != null) accessor = _camelCase(override);
      }

      final get = 'r.get($tableName.$accessor)';
      args.add(param.isNamed ? '${param.name}: $get' : get);
    }

    final fromRow = '_\$${className}FromRow';
    final mapper = '${_lowerFirst(className)}Mapper';
    final body = args.map((a) => '      $a,').join('\n');
    return '''
$className $fromRow(RowReader r) => $className(
$body
    );

const $mapper = RowMapper<$className>($fromRow);
''';
  }
}

String _camelCase(String snake) {
  final parts = snake.split('_').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return snake;
  return parts.first +
      parts.skip(1).map((p) => '${p[0].toUpperCase()}${p.substring(1)}').join();
}

String _lowerFirst(String s) =>
    s.isEmpty ? s : '${s[0].toLowerCase()}${s.substring(1)}';
