import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:diesel/diesel.dart';
import 'package:source_gen/source_gen.dart';

import 'class_info.dart';
import 'column_arg.dart';
import 'naming.dart';
import 'relation_edge.dart';

// Match annotations by name within the `diesel` package. This resolves the
// types regardless of whether they are referenced via the `diesel.dart` barrel
// or their defining library (`fromUrl` only matches the defining library).
const queryableChecker = TypeChecker.typeNamed(Queryable, inPackage: 'diesel');
const mapColumnChecker = TypeChecker.typeNamed(MapColumn, inPackage: 'diesel');
const relationChecker = TypeChecker.typeNamed(Relation, inPackage: 'diesel');
const ignoreChecker = TypeChecker.typeNamed(Ignore, inPackage: 'diesel');

/// Parses `@Relation` / `@MapColumn` metadata from analyzer elements.
final class EdgeAnalyzer {
  const EdgeAnalyzer();

  RelationEdge parseRelationEdge(
      FieldElement field, FormalParameterElement param) {
    if (param.type.nullabilitySuffix != NullabilitySuffix.question) {
      throw InvalidGenerationSourceError(
          '@Relation field "${param.name}" must be nullable.',
          element: field);
    }

    final paramType = param.type;
    if (paramType is! InterfaceType) {
      throw InvalidGenerationSourceError(
          '@Relation field "${param.name}" must reference a @Queryable class.',
          element: field);
    }
    final targetClass = paramType.element;
    if (!queryableChecker.hasAnnotationOfExact(targetClass)) {
      throw InvalidGenerationSourceError(
          '@Relation target ${targetClass.name} must be @Queryable.',
          element: field);
    }

    final relAnn = relationChecker.firstAnnotationOfExact(field)!;
    final depth = relAnn.getField('depth')?.toIntValue() ?? 1;
    final colObj = relAnn.getField('column');
    if (colObj == null) {
      throw InvalidGenerationSourceError(
          '@Relation(column) must reference a schema FK (e.g. Posts.authorId).',
          element: field);
    }

    final colType = colObj.type;
    if (colType is! InterfaceType || colType.typeArguments.length < 3) {
      throw InvalidGenerationSourceError(
          '@Relation(column) must reference a schema FK (e.g. Posts.authorId).',
          element: field);
    }

    final parentMarker = colType.typeArguments[1].element?.name;
    final targetMarker = colType.typeArguments[2].element?.name;
    final sqlName = colObj.getField('name')?.toStringValue();
    final pkObj = colObj.getField('references');
    final pkSqlName = pkObj?.getField('name')?.toStringValue();

    if (parentMarker == null ||
        targetMarker == null ||
        sqlName == null ||
        pkSqlName == null) {
      throw InvalidGenerationSourceError(
          '@Relation(column) must reference a schema FK (e.g. Posts.authorId).',
          element: field);
    }

    return RelationEdge(
      fieldName: param.name!,
      depth: depth,
      parentMarker: parentMarker,
      fkAccessor: camelCase(sqlName),
      targetMarker: targetMarker,
      targetClass: targetClass.name!,
      pkAccessor: camelCase(pkSqlName),
    );
  }

  ColumnArg parseColumnArg({
    required FormalParameterElement param,
    required FieldElement? field,
    required String tableMarker,
  }) {
    final colObj = field == null
        ? null
        : mapColumnChecker.firstAnnotationOfExact(field)?.getField('column');
    if (colObj != null) {
      final colType = colObj.type;
      if (colType is! InterfaceType || colType.typeArguments.length < 2) {
        throw InvalidGenerationSourceError(
            '@MapColumn(column) must reference a schema column '
            '(e.g. Posts.authorId).',
            element: field);
      }
      final marker = colType.typeArguments[1].element?.name;
      final sqlName = colObj.getField('name')?.toStringValue();
      if (marker == null || sqlName == null) {
        throw InvalidGenerationSourceError(
            '@MapColumn(column) must reference a schema column '
            '(e.g. Posts.authorId).',
            element: field);
      }
      return ColumnArg(
        paramName: param.name!,
        isNamed: param.isNamed,
        columnExpr: '$marker.${camelCase(sqlName)}',
      );
    }

    return ColumnArg(
      paramName: param.name!,
      isNamed: param.isNamed,
      columnExpr: '$tableMarker.${param.name}',
    );
  }

  /// The table marker (e.g. `Users`) from a class's `@Queryable(table)`.
  String? tableMarkerOf(ClassElement element) {
    final ann = queryableChecker.firstAnnotationOfExact(element);
    if (ann == null) return null;
    final tableType = ConstantReader(ann).read('table').objectValue.type;
    if (tableType is! InterfaceType) return null;
    return tableType.typeArguments.first.element?.name;
  }

  /// Resolves a `@Queryable` class element into the data the generator needs.
  /// Works for any element regardless of which library it lives in.
  ClassInfo describe(ClassElement element) {
    final tableMarker = tableMarkerOf(element);
    if (tableMarker == null) {
      throw InvalidGenerationSourceError(
          '@Queryable(table) must reference a TableRef (e.g. Posts.table).',
          element: element);
    }
    final constructor = element.unnamedConstructor;
    if (constructor == null) {
      throw InvalidGenerationSourceError(
          '${element.name} needs an unnamed constructor to be @Queryable.',
          element: element);
    }

    final columnArgs = <ColumnArg>[];
    final ownEdges = <RelationEdge>[];
    for (final param in constructor.formalParameters) {
      final name = param.name;
      final field = name == null ? null : element.getField(name);

      if (field != null && relationChecker.hasAnnotationOfExact(field)) {
        _requireNamedOptional(param, field);
        ownEdges.add(parseRelationEdge(field, param));
        continue;
      }
      if (field != null && ignoreChecker.hasAnnotationOfExact(field)) {
        _requireOptional(param, field, 'Ignored');
        continue;
      }
      columnArgs.add(parseColumnArg(
        param: param,
        field: field,
        tableMarker: tableMarker,
      ));
    }

    return ClassInfo(
      className: element.name!,
      tableMarker: tableMarker,
      columnArgs: columnArgs,
      ownEdges: ownEdges,
    );
  }

  /// Every `@Queryable` class reachable from [root] through `@Relation` edges
  /// (including [root] itself), keyed by class name. Cycles terminate naturally.
  Map<String, ClassInfo> reachableFrom(ClassElement root) {
    final infos = <String, ClassInfo>{};

    void visit(ClassElement element) {
      final name = element.name;
      if (name == null || infos.containsKey(name)) return;
      infos[name] = describe(element);

      final ctor = element.unnamedConstructor;
      if (ctor == null) return;
      for (final param in ctor.formalParameters) {
        final pname = param.name;
        final field = pname == null ? null : element.getField(pname);
        if (field == null || !relationChecker.hasAnnotationOfExact(field)) {
          continue;
        }
        final paramType = param.type;
        if (paramType is! InterfaceType) continue;
        final target = paramType.element;
        if (target is ClassElement &&
            queryableChecker.hasAnnotationOfExact(target)) {
          visit(target);
        }
      }
    }

    visit(root);
    return infos;
  }

  void _requireOptional(
      FormalParameterElement param, FieldElement field, String kind) {
    if (param.isRequiredPositional || param.isRequiredNamed) {
      throw InvalidGenerationSourceError(
          '$kind field "${param.name}" must be optional so its default '
          'can be used.',
          element: field);
    }
  }

  // The base reader omits relation fields and the tree reader sets them by
  // name, so a relation must be an *optional named* parameter.
  void _requireNamedOptional(FormalParameterElement param, FieldElement field) {
    if (!param.isNamed) {
      throw InvalidGenerationSourceError(
          'Relation field "${param.name}" must be a named constructor '
          'parameter (e.g. `{this.author}`).',
          element: field);
    }
    _requireOptional(param, field, 'Relation');
  }
}
