import 'dart:collection';
import 'dart:convert';

import 'package:flutter/services.dart';

/// Tokenizes ordinary text, not provider-specific message framing or images.
/// The caller must select only known model/encoding combinations.
class ModelTokenizer {
  ModelTokenizer._(
    this.name,
    this._vocab,
    this._patterns,
    this._merges,
    this._specials,
  ) : _specialPattern = _specials.isEmpty
          ? null
          : RegExp(_specials.keys.map(RegExp.escape).join('|'));

  final String name;
  final Map<String, int> _vocab;
  final List<RegExp> _patterns;
  final Map<String, Map<String, int>>? _merges;
  final Map<String, int> _specials;
  final RegExp? _specialPattern;
  static final Map<String, Future<ModelTokenizer>> _cache = {};

  static String? encodingFor(
    String provider,
    String model, {
    String? endpoint,
  }) {
    final m = model.trim().toLowerCase();
    if (provider == 'deepseek' &&
        (m.startsWith('deepseek-v4') ||
            m == 'deepseek-flash' ||
            m == 'deepseek-pro')) {
      return 'deepseek_v4';
    }
    final uri = Uri.tryParse(endpoint ?? '');
    if (provider != 'chatgpt' &&
        provider != 'openai' &&
        !(provider == 'compatible' &&
            uri?.scheme == 'https' &&
            uri?.host == 'api.openai.com')) {
      return null;
    }
    bool family(String prefix) => m == prefix || m.startsWith('$prefix-');
    // GPT-6 uses o200k_base for local estimates; its official encoding is unconfirmed.
    if (RegExp(r'^gpt-[56](?:\.\d+)?(?:-|$)').hasMatch(m) ||
        const [
          'gpt-4o',
          'gpt-4.1',
          'gpt-4.5',
          'o1',
          'o3',
          'o4-mini',
          'chatgpt-4o',
        ].any(family)) {
      return 'o200k_base';
    }
    if (family('gpt-4') || family('gpt-3.5-turbo') || family('gpt-35-turbo')) {
      return 'cl100k_base';
    }
    return null;
  }

  static String assetFor(String name) => switch (name) {
    'deepseek_v4' => 'assets/tokenizers/deepseek_v4.json',
    'cl100k_base' || 'o200k_base' => 'assets/tokenizers/$name.tiktoken',
    _ => throw ArgumentError.value(name),
  };

  static Future<ModelTokenizer> load(String name) =>
      _cache.putIfAbsent(name, () async {
        return ModelTokenizer.fromAsset(
          name,
          await rootBundle.loadString(assetFor(name)),
        );
      });

  static ModelTokenizer fromAsset(String name, String data) {
    if (name == 'deepseek_v4') {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final model = json['model'] as Map<String, dynamic>;
      final vocab = (model['vocab'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as int),
      );
      final merges = <String, Map<String, int>>{};
      final raw = model['merges'] as List;
      for (var i = 0; i < raw.length; i++) {
        final pair = raw[i] is String
            ? (raw[i] as String).split(' ')
            : (raw[i] as List).cast<String>();
        merges.putIfAbsent(pair[0], () => {})[pair[1]] = i;
      }
      final specials = <String, int>{};
      for (final token in json['added_tokens'] as List) {
        specials[token['content'] as String] = token['id'] as int;
      }
      return ModelTokenizer._(name, vocab, _deepPatterns, merges, specials);
    }
    if (name != 'cl100k_base' && name != 'o200k_base') {
      throw ArgumentError.value(name);
    }
    final vocab = <String, int>{};
    for (final line in const LineSplitter().convert(data)) {
      if (line.isEmpty) continue;
      final parts = line.split(' ');
      vocab[_bytesToString(base64Decode(parts[0]))] = int.parse(parts[1]);
    }
    return ModelTokenizer._(
      name,
      vocab,
      [name == 'cl100k_base' ? _clPattern : _oPattern],
      null,
      {},
    );
  }

  List<int> encode(String text) {
    final specialPattern = _specialPattern;
    if (specialPattern == null) return _encodeOrdinary(text);
    final result = <int>[];
    var start = 0;
    for (final match in specialPattern.allMatches(text)) {
      result.addAll(_encodeOrdinary(text.substring(start, match.start)));
      result.add(_specials[match.group(0)]!);
      start = match.end;
    }
    result.addAll(_encodeOrdinary(text.substring(start)));
    return result;
  }

  int count(String text) => encode(text).length;

  List<int> _encodeOrdinary(String text) {
    var parts = [text];
    for (final pattern in _patterns) {
      final next = <String>[];
      for (final part in parts) {
        var end = 0;
        for (final match in pattern.allMatches(part)) {
          if (match.start > end) next.add(part.substring(end, match.start));
          if (match.end > match.start) next.add(match.group(0)!);
          end = match.end;
        }
        if (end < part.length) next.add(part.substring(end));
      }
      parts = next;
    }
    final ids = <int>[];
    for (final part in parts) {
      final bytes = utf8.encode(part);
      if (bytes.isEmpty) continue;
      final encoded = _bytesToString(bytes);
      if (_merges == null && _vocab.containsKey(encoded)) {
        ids.add(_vocab[encoded]!);
        continue;
      }
      ids.addAll(_merge(bytes));
    }
    return ids;
  }

  Iterable<int> _merge(List<int> bytes) sync* {
    final symbols = [for (final b in bytes) _byteAlphabet[b]];
    final left = List.generate(bytes.length, (i) => i - 1);
    final right = List.generate(bytes.length, (i) => i + 1);
    // Rank first; for ties choose the leftmost pair. Only the two neighboring
    // candidates change after a merge, even in very long uninterrupted text.
    final candidates = SplayTreeSet<(int, int)>((a, b) {
      final rank = a.$1.compareTo(b.$1);
      return rank != 0 ? rank : a.$2.compareTo(b.$2);
    });
    int? rankAt(int i) {
      final j = right[i];
      if (j == -1 || j == symbols.length) return null;
      return _merges == null
          ? _vocab[symbols[i] + symbols[j]]
          : _merges[symbols[i]]?[symbols[j]];
    }

    void queue(int i) {
      if (i >= 0) {
        if (rankAt(i) case final int rank) candidates.add((rank, i));
      }
    }

    for (var i = 0; i < symbols.length - 1; i++) {
      queue(i);
    }
    while (candidates.isNotEmpty) {
      final pair = candidates.first;
      candidates.remove(pair);
      final (rank, i) = pair;
      if (rankAt(i) != rank) continue;
      final j = right[i];
      symbols[i] += symbols[j];
      right[i] = right[j];
      right[j] = -1;
      if (right[i] < symbols.length) left[right[i]] = i;
      queue(left[i]);
      queue(i);
    }
    for (var i = 0; i < symbols.length; i = right[i]) {
      yield _vocab[symbols[i]]!;
    }
  }
}

String _bytesToString(List<int> bytes) =>
    bytes.map((b) => _byteAlphabet[b]).join();
final List<String> _byteAlphabet = () {
  final direct = <int>[
    for (var i = 33; i <= 126; i++) i,
    for (var i = 161; i <= 172; i++) i,
    for (var i = 174; i <= 255; i++) i,
  ];
  final map = List<String>.filled(256, '');
  for (final b in direct) {
    map[b] = String.fromCharCode(b);
  }
  var extra = 0;
  for (var b = 0; b < 256; b++) {
    if (map[b].isEmpty) map[b] = String.fromCharCode(256 + extra++);
  }
  return map;
}();

final _clPattern = RegExp(
  r"'[sSdDmMtT]|'[lL][lL]|'[vV][eE]|'[rR][eE]|[^\r\n\p{L}\p{N}]?\p{L}+|\p{N}{1,3}| ?[^\s\p{L}\p{N}]+[\r\n]*|\s+$|\s*[\r\n]|\s+(?!\S)|\s",
  unicode: true,
);
final _oPattern = RegExp(
  r"[^\r\n\p{L}\p{N}]?[\p{Lu}\p{Lt}\p{Lm}\p{Lo}\p{M}]*[\p{Ll}\p{Lm}\p{Lo}\p{M}]+(?:'[sStTmM]|'[rR][eE]|'[vV][eE]|'[lL][lL]|'[dD])?|[^\r\n\p{L}\p{N}]?[\p{Lu}\p{Lt}\p{Lm}\p{Lo}\p{M}]+[\p{Ll}\p{Lm}\p{Lo}\p{M}]*(?:'[sStTmM]|'[rR][eE]|'[vV][eE]|'[lL][lL]|'[dD])?|\p{N}{1,3}| ?[^\s\p{L}\p{N}]+[\r\n/]*|\s*[\r\n]+|\s+(?!\S)|\s+",
  unicode: true,
);
final _deepPatterns = [
  RegExp(r'\p{N}{1,3}', unicode: true),
  RegExp(r'[一-龥぀-ゟ゠-ヿ]+', unicode: true),
  RegExp(
    r'''[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~][A-Za-z]+|[^\r\n\p{L}\p{P}\p{S}]?[\p{L}\p{M}]+| ?[\p{P}\p{S}]+[\r\n]*|\s*[\r\n]+|\s+(?!\S)|\s+''',
    unicode: true,
  ),
];
