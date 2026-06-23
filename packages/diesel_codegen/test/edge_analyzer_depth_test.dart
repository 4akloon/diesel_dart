import 'package:analyzer/dart/element/element.dart';
import 'package:diesel_codegen/src/queryable/edge_analyzer.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  group('validateRelationDepth', () {
    test('rejects depth < 1', () {
      final element = _FakeElement();
      expect(() => validateRelationDepth(0, element),
          throwsA(isA<InvalidGenerationSourceError>()));
      expect(() => validateRelationDepth(-1, element),
          throwsA(isA<InvalidGenerationSourceError>()));
    });

    test('accepts depth >= 1', () {
      expect(validateRelationDepth(1, _FakeElement()), 1);
      expect(validateRelationDepth(3, _FakeElement()), 3);
    });
  });
}

class _FakeElement extends Element {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
