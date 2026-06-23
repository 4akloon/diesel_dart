import 'package:diesel_codegen/src/queryable/column_arg.dart';
import 'package:diesel_codegen/src/queryable/query_getter_emitter.dart';
import 'package:diesel_codegen/src/queryable/reader_emitter.dart';
import 'package:diesel_codegen/src/queryable/relation_arg.dart';
import 'package:diesel_codegen/src/queryable/relation_call_emitter.dart';
import 'package:diesel_codegen/src/queryable/relation_edge.dart';
import 'package:diesel_codegen/src/queryable/tree_node.dart';
import 'package:test/test.dart';

void main() {
  const readerEmitter = ReaderEmitter();
  const queryGetterEmitter = QueryGetterEmitter();
  const relationCalls = RelationCallEmitter();

  const userColumns = [
    ColumnArg(paramName: 'id', isNamed: false, columnExpr: 'Users.id'),
    ColumnArg(paramName: 'name', isNamed: false, columnExpr: 'Users.name'),
  ];

  const postColumns = [
    ColumnArg(paramName: 'id', isNamed: false, columnExpr: 'Posts.id'),
    ColumnArg(paramName: 'title', isNamed: false, columnExpr: 'Posts.title'),
    ColumnArg(paramName: 'views', isNamed: false, columnExpr: 'Posts.views'),
  ];

  const authorEdge = RelationEdge(
    fieldName: 'author',
    depth: 1,
    parentMarker: 'Posts',
    fkAccessor: 'authorId',
    targetMarker: 'Users',
    targetClass: 'User',
    pkAccessor: 'id',
  );

  group('ReaderEmitter', () {
    test('emits a simple leaf reader (only src)', () {
      final code = readerEmitter.emit(
        className: 'User',
        readerName: r'$UserFromRow',
        tableMarker: 'Users',
        columnArgs: userColumns,
        relationArgs: const [],
      );
      expect(
          code,
          contains(
              r'$UserFromRow(RowReader r, [QuerySource<Users> src = Users.table])'));
      expect(code, contains('r.get(src.col(Users.id))'));
      expect(code, isNot(contains('budget')));
    });

    test('adds prefix/budget params and inlines relation calls', () {
      final code = readerEmitter.emit(
        className: 'Post',
        readerName: r'$PostFromRow',
        tableMarker: 'Posts',
        columnArgs: postColumns,
        relationArgs: const [
          RelationArg(fieldName: 'author', childCall: 'AUTHOR_CALL'),
        ],
      );
      expect(
          code,
          contains(
              r"$PostFromRow(RowReader r, [QuerySource<Posts> src = Posts.table, String prefix = '', int budget = 0])"));
      expect(code, contains('author: AUTHOR_CALL'));
    });
  });

  group('RelationCallEmitter.forReader', () {
    test('threads alias/prefix/budget when target has relations', () {
      final args = relationCalls.forReader([authorEdge], (_) => true);
      expect(
        args.single.childCall,
        r"(prefix.isEmpty ? (budget > 1 ? 1 : budget) : budget) <= 0 ? null : $UserFromRow(r, Users.table.aliased('${prefix}author'), '${prefix}author_', (prefix.isEmpty ? (budget > 1 ? 1 : budget) : budget) - 1)",
      );
    });

    test('stops at a leaf target (no prefix/budget)', () {
      final args = relationCalls.forReader([authorEdge], (_) => false);
      expect(
        args.single.childCall,
        r"(prefix.isEmpty ? (budget > 1 ? 1 : budget) : budget) <= 0 ? null : $UserFromRow(r, Users.table.aliased('${prefix}author'))",
      );
    });
  });

  group('QueryGetterEmitter', () {
    test('emits a joined query that maps via the seeded reader', () {
      final code = queryGetterEmitter.emit(
        className: 'Post',
        queryName: 'postQuery',
        tableMarker: 'Posts',
        readerName: r'$PostFromRow',
        seedBudget: 2,
        treeNodes: [
          TreeNode(
            edge: authorEdge,
            aliasPath: 'author',
            parentAliasPath: null,
            budget: 1,
          ),
        ],
      );
      expect(code, contains('MappedQuery<Post> get postQuery'));
      expect(code, contains('from(Posts.table)'));
      expect(
        code,
        contains(
            '.innerJoin(author, on: Posts.authorId.eqColumn(author.col(Users.id)))'),
      );
      expect(code, contains(r".map((r) => $PostFromRow(r, Posts.table, '', 2))"));
    });
  });
}
