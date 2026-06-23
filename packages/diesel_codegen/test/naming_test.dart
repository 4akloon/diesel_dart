import 'package:diesel_codegen/src/queryable/naming.dart';
import 'package:test/test.dart';

void main() {
  group('camelCase', () {
    test('converts snake_case', () {
      expect(camelCase('author_id'), 'authorId');
      expect(camelCase('created_at'), 'createdAt');
    });

    test('leaves single word unchanged', () {
      expect(camelCase('title'), 'title');
    });
  });

  group('lowerFirst / ucFirst', () {
    test('lowerFirst', () {
      expect(lowerFirst('Post'), 'post');
      expect(lowerFirst('Posts'), 'posts');
    });

    test('ucFirst', () {
      expect(ucFirst('author'), 'Author');
    });
  });
}
