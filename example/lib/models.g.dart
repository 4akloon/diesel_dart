// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// QueryableGenerator
// **************************************************************************

User _$UserFromRow(RowReader r) => User(
      r.get(Users.id),
      r.get(Users.name),
      r.get(Users.age),
      r.get(Users.active),
    );

const userMapper = RowMapper<User>(_$UserFromRow);

Post _$PostFromRow(RowReader r) => Post(
      r.get(Posts.id),
      r.get(Posts.title),
      r.get(Posts.views),
    );

const postMapper = RowMapper<Post>(_$PostFromRow);
