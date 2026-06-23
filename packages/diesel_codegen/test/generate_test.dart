import 'package:diesel_codegen/src/queryable/class_info.dart';
import 'package:diesel_codegen/src/queryable/column_arg.dart';
import 'package:diesel_codegen/src/queryable/model_code_generator.dart';
import 'package:diesel_codegen/src/queryable/queryable_model.dart';
import 'package:diesel_codegen/src/queryable/relation_edge.dart';
import 'package:test/test.dart';

void main() {
  const generator = ModelCodeGenerator();

  const userColumns = [
    ColumnArg(paramName: 'id', isNamed: false, columnExpr: 'Users.id'),
    ColumnArg(paramName: 'name', isNamed: false, columnExpr: 'Users.name'),
    ColumnArg(paramName: 'age', isNamed: false, columnExpr: 'Users.age'),
    ColumnArg(paramName: 'active', isNamed: false, columnExpr: 'Users.active'),
  ];

  const postColumns = [
    ColumnArg(paramName: 'id', isNamed: false, columnExpr: 'Posts.id'),
    ColumnArg(paramName: 'title', isNamed: false, columnExpr: 'Posts.title'),
    ColumnArg(paramName: 'views', isNamed: false, columnExpr: 'Posts.views'),
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

  RelationEdge authorEdge(int depth) => RelationEdge(
        fieldName: 'author',
        depth: depth,
        parentMarker: 'Posts',
        fkAccessor: 'authorId',
        targetMarker: 'Users',
        targetClass: 'User',
        pkAccessor: 'id',
      );

  const userNoEdges = ClassInfo(
    className: 'User',
    tableMarker: 'Users',
    columnArgs: userColumns,
  );

  const userWithManager = ClassInfo(
    className: 'User',
    tableMarker: 'Users',
    columnArgs: userColumns,
    ownEdges: [managerEdge],
  );

  ClassInfo postInfo(int depth) => ClassInfo(
        className: 'Post',
        tableMarker: 'Posts',
        columnArgs: postColumns,
        ownEdges: [authorEdge(depth)],
      );

  test('emits one public leaf reader + mapper for a class with no relations',
      () {
    final code = generator.generateSource(const QueryableModel(
      root: userNoEdges,
      classInfos: {'User': userNoEdges},
    ));

    expect(
        code,
        contains(
            r'$UserFromRow(RowReader r, [QuerySource<Users> src = Users.table])'));
    expect(code, contains('r.get(src.col(Users.id))'));
    expect(
        code, contains(r'const userMapper = RowMapper<User>($UserFromRow);'));
    // No relations -> no runtime budget machinery, no query getter.
    expect(code, isNot(contains('budget')));
    expect(code, isNot(contains('MappedQuery')));
  });

  test('self-referential reader recurses into the same public reader', () {
    final code = generator.generateSource(const QueryableModel(
      root: userWithManager,
      classInfos: {'User': userWithManager},
    ));

    expect(
        code,
        contains(
            r"$UserFromRow(RowReader r, [QuerySource<Users> src = Users.table, String prefix = '', int budget = 0])"));
    expect(
        code,
        contains(
            r"manager: (prefix.isEmpty ? (budget > 1 ? 1 : budget) : budget) <= 0 ? null : r.get(src.col(Users.managerId)) == null ? null : $UserFromRow(r, Users.table.aliased('${prefix}manager'), '${prefix}manager_', (prefix.isEmpty ? (budget > 1 ? 1 : budget) : budget) - 1)"));
    expect(code, contains('MappedQuery<User> get userQuery'));
    expect(code, contains(r".map((r) => $UserFromRow(r, Users.table, '', 1))"));
  });

  test('post reader reuses the User reader instead of redefining it', () {
    final post = postInfo(1);
    final code = generator.generateSource(QueryableModel(
      root: post,
      classInfos: {'Post': post, 'User': userNoEdges},
    ));

    // User has no relations here, so the nested call stops at the leaf reader.
    expect(
        code,
        contains(
            r"author: (prefix.isEmpty ? (budget > 1 ? 1 : budget) : budget) <= 0 ? null : $UserFromRow(r, Users.table.aliased('${prefix}author'))"));
    expect(code, contains('MappedQuery<Post> get postQuery'));
    expect(
      code,
      contains(
          '.innerJoin(author, on: Posts.authorId.eqColumn(author.col(Users.id)))'),
    );
    expect(code, contains(r".map((r) => $PostFromRow(r, Posts.table, '', 1))"));
    // Crucially: the User reader is NOT regenerated in Post's output.
    expect(
        code,
        isNot(contains(
            r'$UserFromRow(RowReader r, [QuerySource<Users> src = Users.table])')));
  });

  test('depth 2 unrolls the join tree and seeds budget accordingly', () {
    final post = postInfo(2);
    final code = generator.generateSource(QueryableModel(
      root: post,
      classInfos: {'Post': post, 'User': userWithManager},
    ));

    // User has relations, so the nested call threads alias/prefix/budget.
    expect(
        code,
        contains(
            r"author: (prefix.isEmpty ? (budget > 2 ? 2 : budget) : budget) <= 0 ? null : $UserFromRow(r, Users.table.aliased('${prefix}author'), '${prefix}author_', (prefix.isEmpty ? (budget > 2 ? 2 : budget) : budget) - 1)"));
    expect(code,
        contains("final authorManager = Users.table.aliased('author_manager');"));
    expect(
      code,
      contains(
          '.leftJoin(authorManager, on: author.col(Users.managerId).eqColumn(authorManager.col(Users.id)))'),
    );
    expect(code, contains(r".map((r) => $PostFromRow(r, Posts.table, '', 2))"));
    // Post does not define a User reader; that lives in User's own file.
    expect(code, isNot(contains('manager:')));
  });
}
