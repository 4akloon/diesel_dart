// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// QueryableGenerator
// **************************************************************************

Post $PostFromRow(RowReader r,
        [QuerySource<Posts> src = Posts.table,
        String prefix = '',
        int budget = 0]) =>
    Post(
      id: r.get(src.col(Posts.id)),
      title: r.get(src.col(Posts.title)),
      views: r.get(src.col(Posts.views)),
      author: (prefix.isEmpty ? (budget > 2 ? 2 : budget) : budget) <= 0
          ? null
          : $UserFromRow(
              r,
              Users.table.aliased('${prefix}author'),
              '${prefix}author_',
              (prefix.isEmpty ? (budget > 2 ? 2 : budget) : budget) - 1),
    );

const postMapper = RowMapper<Post>($PostFromRow);

MappedQuery<Post> get postQuery {
  final author = Users.table.aliased('author');
  final authorManager = Users.table.aliased('author_manager');
  return from(Posts.table)
      .innerJoin(author, on: Posts.authorId.eqColumn(author.col(Users.id)))
      .leftJoin(authorManager,
          on: author.col(Users.managerId).eqColumn(authorManager.col(Users.id)))
      .map((r) => $PostFromRow(r, Posts.table, '', 2));
}
