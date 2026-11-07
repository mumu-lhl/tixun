import 'ai_types.dart';

class ToolCallCollector {
  final _calls = <int, Map<String, String>>{};
  void add(List<dynamic> parts) {
    if (parts.length > 8) throw const AiFailure('一次最多允许 8 个工具调用。');
    for (final raw in parts) {
      if (raw is! Map ||
          raw['index'] is! int ||
          raw['index'] < 0 ||
          raw['index'] > 7) {
        throw const AiFailure('工具调用索引无效。');
      }
      final call = _calls.putIfAbsent(
        raw['index'] as int,
        () => {'id': '', 'name': '', 'arguments': ''},
      );
      if (raw['id'] != null) {
        if (raw['id'] is! String) throw const AiFailure('工具调用 ID 无效。');
        call['id'] = raw['id'] as String;
      }
      if (raw['function'] != null) {
        if (raw['function'] is! Map) throw const AiFailure('工具调用格式无效。');
        final f = raw['function'] as Map;
        for (final key in ['name', 'arguments']) {
          if (f[key] != null) {
            if (f[key] is! String) throw const AiFailure('工具参数片段无效。');
            call[key] = '${call[key]}${f[key]}';
          }
        }
      }
      if (call['arguments']!.length > 64000 ||
          call['name']!.length > 100 ||
          call['id']!.length > 200) {
        throw const AiFailure('工具调用数据过长。');
      }
    }
  }

  List<ToolCall> finish() {
    final sorted = _calls.keys.toList()..sort();
    final ids = <String>{};
    return sorted.map((i) {
      final c = _calls[i]!;
      if (c['id']!.isEmpty || c['name']!.isEmpty || !ids.add(c['id']!)) {
        throw const AiFailure('工具调用不完整或 ID 重复。');
      }
      return ToolCall(c['id']!, c['name']!, c['arguments']!);
    }).toList();
  }
}
