import "a2ui_catalog.dart";

enum InlineA2uiKind { prose, surface, invalid }

typedef InlineA2uiPart = ({InlineA2uiKind kind, String text});

/// Only frames transport blocks. Express syntax and A2UI validation are
/// owned by the official compiler. Partial blocks never reach the renderer.
class InlineA2uiStream {
  static const _open = "<a2ui>";
  static const _close = "</a2ui>";
  String _pending = "";
  StringBuffer? _source;
  var _oversize = false;
  var _codeChar = "";
  var _codeWidth = 0;
  var _fence = false;
  var _indent = 0;
  var _lineStart = true;
  var _escaped = false;

  Iterable<InlineA2uiPart> feed(String text, {bool done = false}) sync* {
    final input = _pending + text;
    _pending = "";
    var prose = StringBuffer();
    for (var i = 0; i < input.length;) {
      final char = input[i];
      if (_source != null) {
        if (char == "<" && input.startsWith(_close, i)) {
          final source = _source!;
          _source = null;
          yield (
            kind: _oversize ? InlineA2uiKind.invalid : InlineA2uiKind.surface,
            text: _oversize ? "" : source.toString(),
          );
          _oversize = false;
          i += _close.length;
          continue;
        }
        if (char == "<" &&
            !done &&
            input.length - i < _close.length &&
            _close.startsWith(input.substring(i))) {
          _pending = input.substring(i);
          break;
        }
        if (!_oversize) {
          _source!.write(char);
          if (_source!.length > chatA2uiMaxSource) {
            _oversize = true;
            _source!.clear();
          }
        }
        i++;
        continue;
      }

      if (_codeChar.isEmpty &&
          !_escaped &&
          char == "<" &&
          !(_lineStart && _indent >= 4)) {
        if (input.startsWith(_open, i)) {
          if (prose.isNotEmpty) {
            yield (kind: InlineA2uiKind.prose, text: prose.toString());
            prose = StringBuffer();
          }
          _source = StringBuffer();
          i += _open.length;
          continue;
        }
        if (done &&
            input.length - i >= 4 &&
            input.length - i < _open.length &&
            _open.startsWith(input.substring(i))) {
          if (prose.isNotEmpty) {
            yield (kind: InlineA2uiKind.prose, text: prose.toString());
          }
          yield (kind: InlineA2uiKind.invalid, text: "");
          return;
        }
        if (!done &&
            input.length - i < _open.length &&
            _open.startsWith(input.substring(i))) {
          _pending = input.substring(i);
          break;
        }
      }

      if ((char == "`" || char == "~") && !_escaped) {
        var end = i + 1;
        while (end < input.length && input[end] == char) {
          end++;
        }
        if (!done && end == input.length && end - i < 128) {
          _pending = input.substring(i);
          break;
        }
        final width = end - i;
        final fencePosition = _lineStart && _indent <= 3 && width >= 3;
        if (_codeChar == char &&
            (_fence
                ? fencePosition && width >= _codeWidth
                : width == _codeWidth)) {
          if (_fence) {
            // A closing fence may have trailing whitespace only.
            final newline = input.indexOf("\n", end);
            if (newline < 0 &&
                !done &&
                input.length - i < 128 &&
                input.substring(end).trim().isEmpty) {
              _pending = input.substring(i);
              break;
            }
            if (input
                .substring(end, newline < 0 ? input.length : newline)
                .trim()
                .isEmpty) {
              _codeChar = "";
            }
          } else {
            _codeChar = "";
          }
        } else if (_codeChar.isEmpty && (fencePosition || char == "`")) {
          _codeChar = char;
          _codeWidth = width;
          _fence = fencePosition;
        }
        prose.write(input.substring(i, end));
        _lineStart = false;
        i = end;
        continue;
      }

      prose.write(char);
      if (char == "\n") {
        _lineStart = true;
        _indent = 0;
      } else if (_lineStart && (char == " " || char == "\t")) {
        _indent += char == " " ? 1 : 4;
      } else {
        _lineStart = false;
      }
      _escaped = !_escaped && char == "\\";
      i++;
    }
    if (prose.isNotEmpty) {
      yield (kind: InlineA2uiKind.prose, text: prose.toString());
    }
    if (done && _source != null) {
      _source = null;
      yield (kind: InlineA2uiKind.invalid, text: "");
    }
  }
}
