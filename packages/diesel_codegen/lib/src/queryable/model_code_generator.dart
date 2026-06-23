import 'naming.dart';
import 'query_getter_emitter.dart';
import 'queryable_model.dart';
import 'reader_emitter.dart';
import 'relation_call_emitter.dart';
import 'relation_edge.dart';
import 'relation_tree_builder.dart';

/// Generates reader/mapper/query code from a resolved [QueryableModel].
///
/// Each class emits exactly one public `$ClassFromRow` reader (plus its mapper
/// and, when it has relations, a query getter). Relation targets are read via
/// their own public readers — imported from wherever they are defined — so
/// nothing is regenerated per consumer. That is what keeps split-file models
/// free of duplicated reader functions.
final class ModelCodeGenerator {
  final ReaderEmitter readerEmitter;
  final QueryGetterEmitter queryGetterEmitter;
  final RelationCallEmitter relationCalls;

  const ModelCodeGenerator({
    this.readerEmitter = const ReaderEmitter(),
    this.queryGetterEmitter = const QueryGetterEmitter(),
    this.relationCalls = const RelationCallEmitter(),
  });

  List<String> generate(QueryableModel model) {
    final root = model.root;
    final infos = model.classInfos;
    final className = root.className;
    final readerName = '\$${className}FromRow';

    bool hasRelations(String cls) =>
        (infos[cls]?.ownEdges ?? const <RelationEdge>[]).isNotEmpty;

    final units = <String>[];

    // The class's own public, reusable reader + mapper. Relations recurse into
    // the targets' public readers (resolved across libraries via import).
    units.add(readerEmitter.emit(
      className: className,
      readerName: readerName,
      tableMarker: root.tableMarker,
      columnArgs: root.columnArgs,
      relationArgs: relationCalls.forReader(root.ownEdges, hasRelations),
    ));
    units.add(
        'const ${lowerFirst(className)}Mapper = RowMapper<$className>($readerName);');

    // A self-mapping join query getter for this class's relations.
    if (root.ownEdges.isNotEmpty) {
      final queryName = '${lowerFirst(className)}Query';
      List<RelationEdge> edgesOf(String cls) =>
          infos[cls]?.ownEdges ?? const <RelationEdge>[];
      final treeNodes = RelationTreeBuilder(edgesOf).unrollRoots(root.ownEdges);
      // One runtime budget seeds the whole tree; the deepest root relation wins.
      final seedBudget = root.ownEdges
          .map((e) => e.depth)
          .reduce((a, b) => a > b ? a : b);

      units.add(queryGetterEmitter.emit(
        className: className,
        queryName: queryName,
        tableMarker: root.tableMarker,
        readerName: readerName,
        seedBudget: seedBudget,
        treeNodes: treeNodes,
      ));
    }

    return units;
  }
}

/// Convenience for callers that want a single chunk (e.g. tests).
extension ModelCodeGeneratorJoin on ModelCodeGenerator {
  String generateSource(QueryableModel model) => generate(model).join('\n\n');
}
