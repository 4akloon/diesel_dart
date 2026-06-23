import '../ast/sql_node.dart';
import '../expression/expression.dart';
import '../schema/table.dart';
import 'row_reader.dart';

/// The shape the serializer and `Connection` consume. Implemented by the
/// terminal [MappedQuery]; [Query] is the builder that produces it.
abstract interface class SelectQuery<R> {
  String get fromTable;
  String? get fromAlias;
  List<Join> get joins;
  List<ColumnNode> get projection;
  SqlNode? get whereNode;
  List<Ordering> get orderings;
  int? get limitCount;
  int? get offsetCount;
  R Function(List<Object?> row) get rowDecoder;
}

/// A reusable, codegen-friendly row decoder for a data class. `@Queryable(Users)`
/// emits one of these (a single `read` built from `RowReader.get` calls). They
/// compose freely — a `Comment` reader can call a `Post` reader on the same
/// [RowReader] to nest objects, with no arity-specific machinery.
final class RowMapper<R> {
  final R Function(RowReader reader) read;
  const RowMapper(this.read);
}

/// Immutable SELECT builder.
///
/// `Scope` is the table marker for a single-table query (so `where` stays
/// compile-time scoped to that table) and becomes `Object?` once joined (the
/// relaxed scope; the serializer then validates table membership at build time).
/// The projection defaults to every column of the involved tables; narrow it
/// with [select]. Call [map] to finish with a typed row decoder.
final class Query<Scope> {
  final String fromTable;
  final String? fromAlias;
  final List<Join> joins;
  final List<Column<Object?, Object?>> projection;
  final SqlNode? whereNode;
  final List<Ordering> orderings;
  final int? limitCount;
  final int? offsetCount;

  const Query({
    required this.fromTable,
    this.fromAlias,
    this.joins = const [],
    required this.projection,
    this.whereNode,
    this.orderings = const [],
    this.limitCount,
    this.offsetCount,
  });

  Query<Scope> where(Expression<bool, Scope> predicate) =>
      _copy(whereNode: predicate.node);

  Query<Scope> orderBy(Ordering ordering) =>
      _copy(orderings: [...orderings, ordering]);

  Query<Scope> limit(int count) => _copy(limitCount: count);
  Query<Scope> offset(int count) => _copy(offsetCount: count);

  /// Narrow the projection to exactly [columns] (default is all columns of the
  /// involved tables).
  Query<Scope> select(List<Column<Object?, Object?>> columns) =>
      _copy(projection: columns);

  /// INNER JOIN [other] (a [TableRef] or an aliased [TableAlias]). Provide the
  /// condition either explicitly (`on:`) or by a foreign key (`onFk:` — its
  /// `column = referenced-pk` becomes the `ON`). Use `on:` for self-joins.
  Query<Object?> innerJoin<Other>(QuerySource<Other> other,
          {Expression<bool, Object?>? on, Ref<Object?, Object?, Object?>? onFk}) =>
      _join(JoinKind.inner, other, on, onFk);

  Query<Object?> leftJoin<Other>(QuerySource<Other> other,
          {Expression<bool, Object?>? on, Ref<Object?, Object?, Object?>? onFk}) =>
      _join(JoinKind.left, other, on, onFk);

  Query<Object?> _join<Other>(JoinKind kind, QuerySource<Other> other,
      Expression<bool, Object?>? on, Ref<Object?, Object?, Object?>? onFk) {
    final SqlNode onNode;
    if (onFk case final fk?) {
      onNode = BinaryNode(fk.node, '=', fk.references.node);
    } else if (on case final predicate?) {
      onNode = predicate.node;
    } else {
      throw ArgumentError('innerJoin/leftJoin needs either on: or onFk:');
    }
    return Query<Object?>(
      fromTable: fromTable,
      fromAlias: fromAlias,
      joins: [...joins, Join(kind, other.table, onNode, alias: other.alias)],
      projection: [...projection, ...other.columns],
      whereNode: whereNode,
      orderings: orderings,
      limitCount: limitCount,
      offsetCount: offsetCount,
    );
  }

  /// Attach a row decoder. The result is still chainable via [MappedQuery.orderBy],
  /// [MappedQuery.limit], and friends.
  MappedQuery<R> map<R>(R Function(RowReader reader) decode) =>
      MappedQuery._(this, decode);

  /// Like [map] but using a reusable [RowMapper] (the codegen output).
  MappedQuery<R> mapWith<R>(RowMapper<R> mapper) => map(mapper.read);

  Query<Scope> _copy({
    List<Column<Object?, Object?>>? projection,
    SqlNode? whereNode,
    List<Ordering>? orderings,
    int? limitCount,
    int? offsetCount,
  }) =>
      Query<Scope>(
        fromTable: fromTable,
        fromAlias: fromAlias,
        joins: joins,
        projection: projection ?? this.projection,
        whereNode: whereNode ?? this.whereNode,
        orderings: orderings ?? this.orderings,
        limitCount: limitCount ?? this.limitCount,
        offsetCount: offsetCount ?? this.offsetCount,
      );
}

/// Start a query from [source] (a table or an alias). Single-table scope keeps
/// `where` strictly typed.
Query<Tbl> from<Tbl>(QuerySource<Tbl> source) => Query<Tbl>(
      fromTable: source.table,
      fromAlias: source.alias,
      projection: source.columns,
    );

/// A [Query] finished with a decoder — the executable [SelectQuery].
final class MappedQuery<R> implements SelectQuery<R> {
  final Query<dynamic> _query;
  final R Function(RowReader reader) _decode;
  final Map<String, int> _columnIndex;

  MappedQuery._(Query<dynamic> query, this._decode)
      : _query = query,
        _columnIndex = {
          for (var i = 0; i < query.projection.length; i++)
            '${query.projection[i].table}.${query.projection[i].name}': i,
        };

  @override
  String get fromTable => _query.fromTable;
  @override
  String? get fromAlias => _query.fromAlias;
  @override
  List<Join> get joins => _query.joins;
  @override
  List<ColumnNode> get projection =>
      [for (final c in _query.projection) c.node];
  @override
  SqlNode? get whereNode => _query.whereNode;
  @override
  List<Ordering> get orderings => _query.orderings;
  @override
  int? get limitCount => _query.limitCount;
  @override
  int? get offsetCount => _query.offsetCount;
  @override
  R Function(List<Object?>) get rowDecoder =>
      (row) => _decode(RowReader(_columnIndex, row));

  /// Further refine the query while keeping the row decoder.
  MappedQuery<R> orderBy(Ordering ordering) =>
      MappedQuery._(_query.orderBy(ordering), _decode);

  MappedQuery<R> limit(int count) =>
      MappedQuery._(_query.limit(count), _decode);

  MappedQuery<R> offset(int count) =>
      MappedQuery._(_query.offset(count), _decode);

  MappedQuery<R> where(Expression<bool, dynamic> predicate) =>
      MappedQuery._(_query.where(predicate), _decode);
}
