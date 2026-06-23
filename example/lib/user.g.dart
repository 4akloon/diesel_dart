// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// QueryableGenerator
// **************************************************************************

User $UserFromRow(RowReader r,
        [QuerySource<Users> src = Users.table,
        String prefix = '',
        int budget = 0]) =>
    User(
      r.get(src.col(Users.id)),
      r.get(src.col(Users.name)),
      r.get(src.col(Users.age)),
      r.get(src.col(Users.active)),
      manager: (prefix.isEmpty ? (budget > 1 ? 1 : budget) : budget) <= 0
          ? null
          : r.get(src.col(Users.managerId)) == null
              ? null
              : $UserFromRow(
                  r,
                  Users.table.aliased('${prefix}manager'),
                  '${prefix}manager_',
                  (prefix.isEmpty ? (budget > 1 ? 1 : budget) : budget) - 1),
    );

const userMapper = RowMapper<User>($UserFromRow);

MappedQuery<User> get userQuery {
  final manager = Users.table.aliased('manager');
  return from(Users.table)
      .leftJoin(manager, on: Users.managerId.eqColumn(manager.col(Users.id)))
      .map((r) => $UserFromRow(r, Users.table, '', 1));
}
