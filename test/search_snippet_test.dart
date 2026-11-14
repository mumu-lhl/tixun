import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ui/search_snippet.dart';

void main() {
  test('extracts case-insensitive literal match with bounded context', () {
    expect(searchExcerpt('123456ABCdef789', 'abc', context: 2), '…56ABCde…');
    expect(searchExcerpt('二次函数\n顶点', '函数'), '二次函数 顶点');
    expect(searchExcerpt('内容', '不存在'), isNull);
    expect(searchExcerpt('内容', ''), isNull);
    expect(searchExcerpt('函数顶点', '函数 顶点'), '函数顶点');
    expect(searchExcerpt('x = 1', 'x = 1'), 'x = 1');
  });
}
