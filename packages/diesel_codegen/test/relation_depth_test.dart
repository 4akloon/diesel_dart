import 'package:diesel_codegen/src/queryable/class_info.dart';
import 'package:diesel_codegen/src/queryable/column_arg.dart';
import 'package:diesel_codegen/src/queryable/model_code_generator.dart';
import 'package:diesel_codegen/src/queryable/query_getter_emitter.dart';
import 'package:diesel_codegen/src/queryable/queryable_model.dart';
import 'package:diesel_codegen/src/queryable/relation_edge.dart';
import 'package:diesel_codegen/src/queryable/tree_node.dart';
import 'package:test/test.dart';

void main() {
  const generator = ModelCodeGenerator();
  const queryGetterEmitter = QueryGetterEmitter();

  const userColumns = [
    ColumnArg(paramName: 'id', isNamed: false, columnExpr: 'Users.id'),
    ColumnArg(paramName: 'name', isNamed: false, columnExpr: 'Users.name'),
  ];

  const postColumns = [
    ColumnArg(paramName: 'id', isNamed: false, columnExpr: 'Posts.id'),
    ColumnArg(paramName: 'title', isNamed: false, columnExpr: 'Posts.title'),
  ];

  const managerEdge = RelationEdge(
    fieldName: 'manager',
    depth: 1,
    parentMarker: 'Users',
    fkAccessor: 'managerId',
    fkNullable: true,
    targetMarker: 'Users',
    targetClass: 'User',
    pkAccessor: 'id',
  );

  const mentorEdge = RelationEdge(
    fieldName: 'mentor',
    depth: 1,
    parentMarker: 'Users',
    fkAccessor: 'mentorId',
    fkNullable: true,
    targetMarker: 'Users',
    targetClass: 'User',
    pkAccessor: 'id',
  );

  const userWithRelations = ClassInfo(
    className: 'User',
    tableMarker: 'Users',
    columnArgs: userColumns,
    ownEdges: [managerEdge, mentorEdge],
  );

  test('mixed root depths cap each relation budget at emit time', () {
    const authorEdge = RelationEdge(
      fieldName: 'author',
      depth: 1,
      parentMarker: 'Posts',
      fkAccessor: 'authorId',
      targetMarker: 'Users',
      targetClass: 'User',
      pkAccessor: 'id',
    );
    const editorEdge = RelationEdge(
      fieldName: 'editor',
      depth: 2,
      parentMarker: 'Posts',
      fkAccessor: 'editorId',
      targetMarker: 'Users',
      targetClass: 'User',
      pkAccessor: 'id',
    );

    final post = ClassInfo(
      className: 'Post',
      tableMarker: 'Posts',
      columnArgs: postColumns,
      ownEdges: [authorEdge, editorEdge],
    );

    final code = generator.generateSource(QueryableModel(
      root: post,
      classInfos: {
        'Post': post,
        'User': userWithRelations,
      },
    ));

    // Global seed is max depth (2), but author depth=1 caps budget so nested
    // manager/mentor are not read even though User has relations.
    expect(
      code,
      contains(
        r"author: (prefix.isEmpty ? (budget > 1 ? 1 : budget) : budget) <= 0 ? null : $UserFromRow(r, Users.table.aliased('${prefix}author'), '${prefix}author_', (prefix.isEmpty ? (budget > 1 ? 1 : budget) : budget) - 1)",
      ),
    );
    expect(
      code,
      contains(
        r"editor: (prefix.isEmpty ? (budget > 2 ? 2 : budget) : budget) <= 0 ? null : $UserFromRow(r, Users.table.aliased('${prefix}editor'), '${prefix}editor_', (prefix.isEmpty ? (budget > 2 ? 2 : budget) : budget) - 1)",
      ),
    );
    expect(code, contains(r".map((r) => $PostFromRow(r, Posts.table, '', 2))"));
    expect(code, contains("final author = Users.table.aliased('author');"));
    expect(code, isNot(contains('author_manager')));
    expect(code, contains("final editorManager = Users.table.aliased('editor_manager');"));
  });

  test('nullable FK fan-out at depth > 1 uses leftJoin', () {
    const authorEdge = RelationEdge(
      fieldName: 'author',
      depth: 2,
      parentMarker: 'Posts',
      fkAccessor: 'authorId',
      targetMarker: 'Users',
      targetClass: 'User',
      pkAccessor: 'id',
    );

    final post = ClassInfo(
      className: 'Post',
      tableMarker: 'Posts',
      columnArgs: postColumns,
      ownEdges: [authorEdge],
    );

    final code = generator.generateSource(QueryableModel(
      root: post,
      classInfos: {
        'Post': post,
        'User': userWithRelations,
      },
    ));

    expect(
      code,
      contains(
          '.innerJoin(author, on: Posts.authorId.eqColumn(author.col(Users.id)))'),
    );
    expect(
      code,
      contains(
          '.leftJoin(authorManager, on: author.col(Users.managerId).eqColumn(authorManager.col(Users.id)))'),
    );
    expect(
      code,
      contains(
          '.leftJoin(authorMentor, on: author.col(Users.mentorId).eqColumn(authorMentor.col(Users.id)))'),
    );
  });

  group('QueryGetterEmitter join kind', () {
    const edge = RelationEdge(
      fieldName: 'manager',
      depth: 1,
      parentMarker: 'Users',
      fkAccessor: 'managerId',
      fkNullable: true,
      targetMarker: 'Users',
      targetClass: 'User',
      pkAccessor: 'id',
    );

    test('nullable FK emits leftJoin', () {
      final code = queryGetterEmitter.emit(
        className: 'User',
        queryName: 'userQuery',
        tableMarker: 'Users',
        readerName: r'$UserFromRow',
        seedBudget: 1,
        treeNodes: [
          TreeNode(
            edge: edge,
            aliasPath: 'manager',
            parentAliasPath: null,
            budget: 1,
          ),
        ],
      );
      expect(
        code,
        contains(
            '.leftJoin(manager, on: Users.managerId.eqColumn(manager.col(Users.id)))'),
      );
    });

    test('non-nullable FK emits innerJoin', () {
      final code = queryGetterEmitter.emit(
        className: 'Post',
        queryName: 'postQuery',
        tableMarker: 'Posts',
        readerName: r'$PostFromRow',
        seedBudget: 1,
        treeNodes: [
          TreeNode(
            edge: const RelationEdge(
              fieldName: 'author',
              depth: 1,
              parentMarker: 'Posts',
              fkAccessor: 'authorId',
              targetMarker: 'Users',
              targetClass: 'User',
              pkAccessor: 'id',
            ),
            aliasPath: 'author',
            parentAliasPath: null,
            budget: 1,
          ),
        ],
      );
      expect(
        code,
        contains(
            '.innerJoin(author, on: Posts.authorId.eqColumn(author.col(Users.id)))'),
      );
    });
  });
}
