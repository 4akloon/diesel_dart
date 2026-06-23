import 'package:diesel_codegen/src/queryable/relation_edge.dart';
import 'package:diesel_codegen/src/queryable/relation_tree_builder.dart';
import 'package:test/test.dart';

void main() {
  const postAuthor = RelationEdge(
    fieldName: 'author',
    depth: 1,
    parentMarker: 'Posts',
    fkAccessor: 'authorId',
    targetMarker: 'Users',
    targetClass: 'User',
    pkAccessor: 'id',
  );

  const userManager = RelationEdge(
    fieldName: 'manager',
    depth: 1,
    parentMarker: 'Users',
    fkAccessor: 'managerId',
    fkNullable: true,
    targetMarker: 'Users',
    targetClass: 'User',
    pkAccessor: 'id',
  );

  group('RelationTreeBuilder.parentAliasPath', () {
    test('returns null for root alias', () {
      expect(RelationTreeBuilder.parentAliasPath('author'), isNull);
    });

    test('returns parent segment', () {
      expect(RelationTreeBuilder.parentAliasPath('author_manager'), 'author');
      expect(
        RelationTreeBuilder.parentAliasPath('author_manager_reports'),
        'author_manager',
      );
    });
  });

  group('RelationTreeBuilder.unroll', () {
    test('depth 1 yields a single node', () {
      final builder = RelationTreeBuilder((_) => const []);
      final nodes = builder.unroll(
        edge: postAuthor,
        budget: 1,
        aliasPath: 'author',
      );
      expect(nodes, hasLength(1));
      expect(nodes.first.aliasPath, 'author');
      expect(nodes.first.parentAliasPath, isNull);
    });

    test('depth 2 expands target relations', () {
      final builder = RelationTreeBuilder(
        (cls) => cls == 'User' ? [userManager] : const [],
      );
      final nodes = builder.unroll(
        edge: const RelationEdge(
          fieldName: 'author',
          depth: 2,
          parentMarker: 'Posts',
          fkAccessor: 'authorId',
          targetMarker: 'Users',
          targetClass: 'User',
          pkAccessor: 'id',
        ),
        budget: 2,
        aliasPath: 'author',
      );
      expect(nodes, hasLength(2));
      expect(nodes.map((n) => n.aliasPath), ['author', 'author_manager']);
      expect(nodes.last.parentAliasPath, 'author');
    });
  });
}
