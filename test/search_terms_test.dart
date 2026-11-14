import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/database/search_terms.dart';

void main() {
  test('Splits keywords but preserves phrases, punctuation and formulas', () {
    expect(searchTerms(' 函数  顶点 '), ['函数', '顶点']);
    expect(searchTerms('"函数 顶点"'), ['函数 顶点']);
    expect(searchTerms('x - y = 1'), ['x - y = 1']);
    expect(searchTerms('hello, world'), ['hello, world']);
    expect(searchTerms('""'), ['""']);
    expect(searchTerms('  '), isEmpty);
  });
}
