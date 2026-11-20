/// Converts the LaTeX subset used in learning content into plain Unicode text.
///
/// Print formats without a math typesetter (PDF text runs, DOCX runs) can only
/// place characters, so a formula has to become readable text: fractions keep
/// a slash, roots use `√`, scripts use Unicode superscripts where the bundled
/// font has the glyph and `^`/`_` notation otherwise. Unknown commands keep
/// their source so a formula is never silently blanked out.
library;

const _symbols = <String, String>{
  "alpha": "α",
  "beta": "β",
  "gamma": "γ",
  "delta": "δ",
  "epsilon": "ε",
  "varepsilon": "ε",
  "zeta": "ζ",
  "eta": "η",
  "theta": "θ",
  "vartheta": "θ",
  "iota": "ι",
  "kappa": "κ",
  "lambda": "λ",
  "mu": "μ",
  "nu": "ν",
  "xi": "ξ",
  "pi": "π",
  "rho": "ρ",
  "sigma": "σ",
  "tau": "τ",
  "upsilon": "υ",
  "phi": "φ",
  "varphi": "φ",
  "chi": "χ",
  "psi": "ψ",
  "omega": "ω",
  "Gamma": "Γ",
  "Delta": "Δ",
  "Theta": "Θ",
  "Lambda": "Λ",
  "Xi": "Ξ",
  "Pi": "Π",
  "Sigma": "Σ",
  "Upsilon": "Υ",
  "Phi": "Φ",
  "Psi": "Ψ",
  "Omega": "Ω",
  "times": "×",
  "div": "÷",
  "cdot": "·",
  "pm": "±",
  "mp": "∓",
  "leq": "≤",
  "le": "≤",
  "geq": "≥",
  "ge": "≥",
  "neq": "≠",
  "ne": "≠",
  "approx": "≈",
  "equiv": "≡",
  "sim": "∽",
  "cong": "≅",
  "propto": "∝",
  "infty": "∞",
  "sum": "∑",
  "prod": "∏",
  "int": "∫",
  "oint": "∮",
  "partial": "∂",
  "nabla": "∇",
  "angle": "∠",
  "triangle": "△",
  "perp": "⊥",
  "parallel": "∥",
  "odot": "⊙",
  "circ": "∘",
  "degree": "°",
  "prime": "′",
  "in": "∈",
  "notin": "∉",
  "ni": "∋",
  "subset": "⊂",
  "subseteq": "⊆",
  "supset": "⊃",
  "supseteq": "⊇",
  "cup": "∪",
  "cap": "∩",
  "emptyset": "∅",
  "varnothing": "∅",
  "forall": "∀",
  "exists": "∃",
  "neg": "¬",
  "land": "∧",
  "lor": "∨",
  "to": "→",
  "rightarrow": "→",
  "leftarrow": "←",
  "leftrightarrow": "↔",
  "Rightarrow": "⇒",
  "Leftarrow": "⇐",
  "Leftrightarrow": "⇔",
  "uparrow": "↑",
  "downarrow": "↓",
  "ldots": "…",
  "dots": "…",
  "cdots": "…",
  "vdots": "⋮",
  "therefore": "∴",
  "because": "∵",
  "triangleq": "≜",
  "square": "□",
  "Box": "□",
};

/// Commands whose meaning is layout only; they contribute nothing.
const _transparent = {
  "left",
  "right",
  "middle",
  "big",
  "Big",
  "bigg",
  "Bigg",
  "bigl",
  "bigr",
  "Bigl",
  "Bigr",
  "displaystyle",
  "textstyle",
  "scriptstyle",
  "limits",
  "nolimits",
  "mathstrut",
  "phantom",
  "hspace",
  "vspace",
  "nonumber",
  "notag",
};

const _wrappers = {
  "text",
  "textrm",
  "textnormal",
  "mathrm",
  "mathbf",
  "mathit",
  "mathsf",
  "mathtt",
  "operatorname",
  "mbox",
  "hbox",
  "vec",
  "overline",
  "underline",
  "hat",
  "bar",
  "widehat",
  "widetilde",
  "overrightarrow",
  "overleftarrow",
  "mathcal",
  "mathbb",
  "boxed",
  "textcircled",
};

const _spacing = {
  "quad": " ",
  "qquad": " ",
  "enspace": " ",
  "thinspace": " ",
  "space": " ",
  "nobreakspace": " ",
};

const _controlSymbols = <String, String>{
  r"\": " ; ",
  ",": " ",
  ";": " ",
  ":": " ",
  "!": "",
  " ": " ",
  "{": "{",
  "}": "}",
  "%": "%",
  "&": "&",
  "#": "#",
  r"$": r"$",
  "_": "_",
  "|": "∥",
};

const _superscripts = {"1": "¹", "2": "²", "3": "³", "4": "⁴"};

/// Converts one formula (with or without `$`, `\(`, `\[` delimiters).
String latexToText(String source) {
  final stripped = _expandEnvironments(_stripDelimiters(source.trim()));
  final rendered = _render(stripped)
      .replaceAll(RegExp(r"[ \t]{2,}"), " ")
      .replaceAll(RegExp(r"\s*\n\s*"), " ")
      // A formula often sits right before a CJK comma; the space the maths
      // leaves behind would then float in the middle of the sentence.
      .replaceAllMapped(RegExp(r"\s+([)\]},;.，。、；：！？])"), (match) => match[1]!)
      .trim();
  return rendered;
}

String _stripDelimiters(String text) {
  for (final pair in const [
    (r"$$", r"$$"),
    (r"\[", r"\]"),
    (r"\(", r"\)"),
    (r"$", r"$"),
  ]) {
    final (open, close) = pair;
    if (text.length > open.length + close.length &&
        text.startsWith(open) &&
        text.endsWith(close)) {
      return text.substring(open.length, text.length - close.length).trim();
    }
  }
  return text;
}

const _environmentDelimiters = <String, (String, String)>{
  "pmatrix": ("(", ")"),
  "bmatrix": ("[", "]"),
  "Bmatrix": (r"\{", r"\}"),
  "vmatrix": ("|", "|"),
  "Vmatrix": ("‖", "‖"),
  "matrix": ("[", "]"),
  "smallmatrix": ("[", "]"),
  "cases": (r"\{", r"\}"),
  "aligned": ("", ""),
  "array": ("", ""),
};

final _environmentPattern = RegExp(
  r"\\begin\{([A-Za-z]+)\}(.*?)\\end\{\1\}",
  dotAll: true,
);

/// Turns `\begin{pmatrix}1&2\\3&4\end{pmatrix}` into `(1, 2; 3, 4)`.
///
/// A printed page cannot lay out a matrix, but keeping the row/column order and
/// the enclosing delimiters preserves the meaning for a reader.
String _expandEnvironments(String tex) {
  if (!tex.contains(r"\begin{")) return tex;
  return tex.replaceAllMapped(_environmentPattern, (match) {
    final environment = match[1]!;
    final body = _expandEnvironments(match[2]!);
    final (open, close) = _environmentDelimiters[environment] ?? ("", "");
    final rows = body
        .split(r"\\")
        .map(
          (row) => row
              .split("&")
              .map((cell) => cell.trim())
              .where((cell) => cell.isNotEmpty)
              .join(", "),
        )
        .where((row) => row.isNotEmpty)
        .join("; ");
    return "$open$rows$close";
  });
}

class _Group {
  const _Group(this.value, this.end);
  final String value;
  final int end;
}

int _skipSpaces(String text, int index) {
  var i = index;
  while (i < text.length && (text[i] == " " || text[i] == "\t")) {
    i++;
  }
  return i;
}

/// Reads `{...}` at [index] (or a single token when the braces are omitted).
_Group? _group(String text, int index) {
  final start = _skipSpaces(text, index);
  if (start >= text.length) return null;
  if (text[start] != "{") {
    if (text[start] == r"\") {
      final command = _commandAt(text, start);
      return command == null
          ? null
          : _Group(text.substring(start, command.end), command.end);
    }
    return _Group(text[start], start + 1);
  }
  var depth = 0;
  var i = start;
  while (i < text.length) {
    final c = text[i];
    if (c == r"\") {
      i += 2;
      continue;
    }
    if (c == "{") depth++;
    if (c == "}") {
      depth--;
      if (depth == 0) {
        return _Group(text.substring(start + 1, i), i + 1);
      }
    }
    i++;
  }
  return _Group(text.substring(start + 1), text.length);
}

class _Command {
  const _Command(this.start, this.end, this.name);
  final int start;
  final int end;
  final String name;
}

_Command? _commandAt(String text, int index) {
  if (text[index] != r"\") return null;
  var i = index + 1;
  while (i < text.length && _isLetter(text[i])) {
    i++;
  }
  if (i == index + 1) return null;
  return _Command(index, i, text.substring(index + 1, i));
}

bool _isLetter(String c) {
  final code = c.codeUnitAt(0);
  return (code >= 0x41 && code <= 0x5a) || (code >= 0x61 && code <= 0x7a);
}

String _render(String text) {
  final out = StringBuffer();
  var i = 0;
  while (i < text.length) {
    final c = text[i];
    if (c == r"\") {
      final command = _commandAt(text, i);
      if (command != null) {
        i = command.end;
        i = _renderCommand(command.name, text, i, out);
        continue;
      }
      final symbol = i + 1 < text.length ? text[i + 1] : "";
      i += 2;
      out.write(_controlSymbols[symbol] ?? symbol);
      continue;
    }
    if (c == "^" || c == "_") {
      final argument = _group(text, i + 1);
      if (argument == null) {
        i++;
        continue;
      }
      i = argument.end;
      final value = _render(argument.value).trim();
      if (value.isEmpty) continue;
      if (c == "^") {
        out.write(_superscript(value));
      } else {
        out.write(value.length == 1 ? "_$value" : "_($value)");
      }
      continue;
    }
    if (c == "{") {
      final argument = _group(text, i);
      if (argument == null) {
        i++;
        continue;
      }
      i = argument.end;
      out.write(_render(argument.value));
      continue;
    }
    if (c == "}") {
      i++;
      continue;
    }
    if (c == "&") {
      i++;
      out.write(" ");
      continue;
    }
    // `~` is a non-breaking space in TeX.
    out.write(c == "~" ? " " : c);
    i++;
  }
  return out.toString();
}

int _renderCommand(String name, String text, int index, StringBuffer out) {
  switch (name) {
    case "frac":
    case "dfrac":
    case "tfrac":
    case "cfrac":
      final numerator = _group(text, index);
      if (numerator == null) {
        out.write("$name ");
        return index;
      }
      final denominator = _group(text, numerator.end);
      if (denominator == null) {
        out.write(_render(numerator.value));
        return numerator.end;
      }
      out.write(
        _fraction(_render(numerator.value), _render(denominator.value)),
      );
      return denominator.end;
    case "sqrt":
      var start = _skipSpaces(text, index);
      String? degree;
      if (start < text.length && text[start] == "[") {
        final close = text.indexOf("]", start);
        if (close > start) {
          degree = text.substring(start + 1, close);
          start = close + 1;
        }
      }
      final radicand = _group(text, start);
      if (radicand == null) {
        out.write("√");
        return index;
      }
      final body = _render(radicand.value);
      out.write(
        degree == null
            ? "√($body)"
            : "${_superscript(_render(degree))}√($body)",
      );
      return radicand.end;
    case "begin":
    case "end":
      final environment = _group(text, index);
      return environment?.end ?? index;
  }
  if (_symbols.containsKey(name)) {
    out.write(_symbols[name]);
    return index;
  }
  if (_spacing.containsKey(name)) {
    out.write(_spacing[name]);
    return index;
  }
  if (_transparent.contains(name)) {
    // `\left(` and `\right)` leave the delimiter to the main loop.
    return index;
  }
  if (_wrappers.contains(name)) {
    final argument = _group(text, index);
    if (argument == null) {
      return index;
    }
    out.write(_render(argument.value));
    return argument.end;
  }
  final argument = _group(text, index);
  if (argument == null) {
    out.write(
      r"\"
      "$name",
    );
    return index;
  }
  out.write(
    r"\"
    "$name("
    "${_render(argument.value)})",
  );
  return argument.end;
}

String _fraction(String numerator, String denominator) {
  final n = numerator.trim();
  final d = denominator.trim();
  return "${_fractionSide(n)}/${_fractionSide(d)}";
}

/// Parentheses are added only where the division would otherwise change the
/// expression: a product or an already bracketed group needs none.
String _fractionSide(String value) {
  if (RegExp(r"^[A-Za-z0-9.¹²³⁴]+$").hasMatch(value)) return value;
  if (value.startsWith("(") && value.endsWith(")")) return value;
  return "($value)";
}

String _superscript(String value) {
  if (value.length == 1 && _superscripts.containsKey(value)) {
    return _superscripts[value]!;
  }
  return value.length == 1 ? "^$value" : "^($value)";
}
