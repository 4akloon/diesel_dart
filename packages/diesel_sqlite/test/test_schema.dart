import 'package:diesel/diesel.dart';

/// Shared hand-written schema for tests.
abstract final class Users {
  static const _t = 'users';
  static const id = PrimaryKey<int, Users>(_t, 'id', SqlType.integer);
  static const name = ValueColumn<String, Users>(_t, 'name', SqlType.text);
  static const age = ValueColumn<int, Users>(_t, 'age', SqlType.integer);
  static const active = ValueColumn<bool, Users>(_t, 'active', SqlType.boolean);
  static const table = TableRef<Users>(_t, [id, name, age, active]);
}

abstract final class Posts {
  static const _t = 'posts';
  static const id = PrimaryKey<int, Posts>(_t, 'id', SqlType.integer);
  static const authorId =
      Ref<int, Posts, Users>(_t, 'author_id', SqlType.integer, references: Users.id);
  static const title = ValueColumn<String, Posts>(_t, 'title', SqlType.text);
  static const views = ValueColumn<int, Posts>(_t, 'views', SqlType.integer);
  static const table = TableRef<Posts>(_t, [id, authorId, title, views]);
}

abstract final class Comments {
  static const _t = 'comments';
  static const id = PrimaryKey<int, Comments>(_t, 'id', SqlType.integer);
  static const postId =
      Ref<int, Comments, Posts>(_t, 'post_id', SqlType.integer, references: Posts.id);
  static const body = ValueColumn<String, Comments>(_t, 'body', SqlType.text);
  static const table = TableRef<Comments>(_t, [id, postId, body]);
}

/// Two foreign keys to the SAME table — needs aliased self-joins.
abstract final class Messages {
  static const _t = 'messages';
  static const id = PrimaryKey<int, Messages>(_t, 'id', SqlType.integer);
  static const senderId =
      Ref<int, Messages, Users>(_t, 'sender_id', SqlType.integer, references: Users.id);
  static const recipientId =
      Ref<int, Messages, Users>(_t, 'recipient_id', SqlType.integer, references: Users.id);
  static const body = ValueColumn<String, Messages>(_t, 'body', SqlType.text);
  static const table =
      TableRef<Messages>(_t, [id, senderId, recipientId, body]);
}

/// Has a nullable column (`bio TEXT NULL`).
abstract final class Profiles {
  static const _t = 'profiles';
  static const id = PrimaryKey<int, Profiles>(_t, 'id', SqlType.integer);
  static const bio = ValueColumn<String?, Profiles>(_t, 'bio', SqlType.textOrNull);
  static const table = TableRef<Profiles>(_t, [id, bio]);
}

/// A message with both participants resolved (each from a different alias of
/// the users table).
class Message {
  final int id;
  final String body;
  final User sender;
  final User recipient;
  const Message(this.id, this.body, {required this.sender, required this.recipient});
}

/// Reads a [User] from a specific alias of the users table.
User readUserFrom(TableAlias<Users> a, RowReader r) => User(
      r.get(a.col(Users.id)),
      r.get(a.col(Users.name)),
      r.get(a.col(Users.age)),
      r.get(a.col(Users.active)),
    );

// Data classes + reusable RowReader-based decoders — what codegen would emit.
class User {
  final int id;
  final String name;
  final int age;
  final bool active;
  const User(this.id, this.name, this.age, this.active);
}

User readUser(RowReader r) =>
    User(r.get(Users.id), r.get(Users.name), r.get(Users.age), r.get(Users.active));
const userQueryable = Queryable<User>(readUser);

class Post {
  final int id;
  final int authorId;
  final String title;
  final int views;
  final User? author;
  const Post(this.id, this.authorId, this.title, this.views, {this.author});
  Post withAuthor(User author) =>
      Post(id, authorId, title, views, author: author);
}

Post readPost(RowReader r) => Post(
    r.get(Posts.id), r.get(Posts.authorId), r.get(Posts.title), r.get(Posts.views));
const postQueryable = Queryable<Post>(readPost);

class Comment {
  final int id;
  final int postId;
  final String body;
  final Post? post;
  const Comment(this.id, this.postId, this.body, {this.post});
  Comment withPost(Post post) => Comment(id, postId, body, post: post);
}

Comment readComment(RowReader r) =>
    Comment(r.get(Comments.id), r.get(Comments.postId), r.get(Comments.body));
const commentQueryable = Queryable<Comment>(readComment);
