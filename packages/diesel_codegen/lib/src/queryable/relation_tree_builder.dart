import 'relation_edge.dart';
import 'relation_edges_lookup.dart';
import 'tree_node.dart';

/// Unrolls join trees for relation queries with path-based table aliases.
final class RelationTreeBuilder {
  final RelationEdgesLookup edgesOf;

  const RelationTreeBuilder(this.edgesOf);

  /// Parent alias path for `author_manager` -> `author`; root edges have `null`.
  static String? parentAliasPath(String aliasPath) {
    final idx = aliasPath.lastIndexOf('_');
    if (idx < 0) return null;
    return aliasPath.substring(0, idx);
  }

  TreeNode node({
    required RelationEdge edge,
    required int budget,
    required String aliasPath,
  }) =>
      TreeNode(
        edge: edge,
        aliasPath: aliasPath,
        parentAliasPath: parentAliasPath(aliasPath),
        budget: budget,
      );

  /// Unrolls the join tree for [edge] down to [budget] levels.
  List<TreeNode> unroll({
    required RelationEdge edge,
    required int budget,
    required String aliasPath,
  }) {
    final nodes = <TreeNode>[
      node(edge: edge, budget: budget, aliasPath: aliasPath),
    ];
    if (budget <= 1) return nodes;

    for (final childEdge in edgesOf(edge.targetClass)) {
      nodes.addAll(unroll(
        edge: childEdge,
        budget: budget - 1,
        aliasPath: '${aliasPath}_${childEdge.fieldName}',
      ));
    }
    return nodes;
  }

  /// Unrolls every root [RelationEdge] at its own [RelationEdge.depth].
  List<TreeNode> unrollRoots(List<RelationEdge> rootEdges) {
    final nodes = <TreeNode>[];
    for (final edge in rootEdges) {
      nodes.addAll(unroll(
        edge: edge,
        budget: edge.depth,
        aliasPath: edge.fieldName,
      ));
    }
    return nodes;
  }
}
