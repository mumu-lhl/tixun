/// Conservative token estimate for the context budget.
///
/// There is no tokenizer in the app (see the DeepSeek/GPT note in
/// `context_compactor.dart`): the budget is a trigger for summarization,
/// not a billing meter, so a rough estimate with a safety margin is
/// enough. The provider's real context window is the final backstop.
library;

/// Safety margin applied on top of the script-weighted count.
/// Deliberately pessimistic: underestimating is what lets a request
/// grow past the model window and 400.
const double kTokenEstimateSafety = 1.25;

/// Estimate how many tokens [text] costs.
///
/// - CJK, Hiragana, Katakana and Hangul characters: ~1 token each.
/// - ASCII letters and digits: ~4 characters per token.
/// - ASCII whitespace and punctuation: ~2 characters per token.
/// - Everything else (emoji, symbols, other scripts): ~2 tokens per rune.
int estimateTokens(String text) {
  if (text.isEmpty) return 0;
  var tokens = 0.0;
  for (final rune in text.runes) {
    if (_isCjk(rune)) {
      tokens += 1;
    } else if (rune < 0x80) {
      if (_isAsciiLetterOrDigit(rune)) {
        tokens += 0.25;
      } else {
        tokens += 0.5;
      }
    } else {
      tokens += 2;
    }
  }
  return (tokens * kTokenEstimateSafety).ceil();
}

bool _isCjk(int rune) =>
    (rune >= 0x3400 && rune <= 0x4dbf) || // CJK Ext A
    (rune >= 0x4e00 && rune <= 0x9fff) || // CJK Unified
    (rune >= 0x3040 && rune <= 0x309f) || // Hiragana
    (rune >= 0x30a0 && rune <= 0x30ff) || // Katakana
    (rune >= 0xac00 && rune <= 0xd7a3); // Hangul syllables

bool _isAsciiLetterOrDigit(int rune) =>
    (rune >= 0x30 && rune <= 0x39) || // 0-9
    (rune >= 0x41 && rune <= 0x5a) || // A-Z
    (rune >= 0x61 && rune <= 0x7a); // a-z
