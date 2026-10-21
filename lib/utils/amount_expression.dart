double? evaluateAmountExpression(String input) {
  final String normalized = _normalizeAmountExpression(input);
  if (normalized.isEmpty || normalized.length > 80) return null;
  try {
    final double value = _AmountExpressionParser(normalized).parse();
    return value.isFinite ? value : null;
  } on FormatException {
    return null;
  }
}

bool containsAmountExpression(String input) {
  final String normalized = _normalizeAmountExpression(input);
  if (RegExp(r'[+*/()]').hasMatch(normalized)) return true;
  return normalized.indexOf('-', 1) >= 0;
}

String _normalizeAmountExpression(String input) {
  final StringBuffer output = StringBuffer();
  for (final int rune in input.runes) {
    if (rune >= 0xFF10 && rune <= 0xFF19) {
      output.writeCharCode(0x30 + rune - 0xFF10);
      continue;
    }
    final String character = String.fromCharCode(rune);
    switch (character) {
      case '＋':
        output.write('+');
        break;
      case '－':
      case '−':
      case '—':
        output.write('-');
        break;
      case '×':
      case '✕':
      case '＊':
      case 'x':
      case 'X':
        output.write('*');
        break;
      case '÷':
      case '／':
        output.write('/');
        break;
      case '（':
        output.write('(');
        break;
      case '）':
        output.write(')');
        break;
      default:
        if (character.trim().isNotEmpty) output.write(character);
        break;
    }
  }
  return output.toString();
}

class _AmountExpressionParser {
  _AmountExpressionParser(this.source);

  final String source;
  int index = 0;

  double parse() {
    final double value = _parseExpression();
    if (index != source.length) throw const FormatException();
    return value;
  }

  double _parseExpression() {
    double value = _parseTerm();
    while (index < source.length) {
      final String operator = source[index];
      if (operator != '+' && operator != '-') break;
      index++;
      final double right = _parseTerm();
      value = operator == '+' ? value + right : value - right;
    }
    return value;
  }

  double _parseTerm() {
    double value = _parseFactor();
    while (index < source.length) {
      final String operator = source[index];
      if (operator != '*' && operator != '/') break;
      index++;
      final double right = _parseFactor();
      if (operator == '/' && right == 0) throw const FormatException();
      value = operator == '*' ? value * right : value / right;
    }
    return value;
  }

  double _parseFactor() {
    if (index >= source.length) throw const FormatException();
    final String operator = source[index];
    if (operator == '+' || operator == '-') {
      index++;
      final double value = _parseFactor();
      return operator == '-' ? -value : value;
    }
    if (operator == '(') {
      index++;
      final double value = _parseExpression();
      if (index >= source.length || source[index] != ')') {
        throw const FormatException();
      }
      index++;
      return value;
    }
    return _parseNumber();
  }

  double _parseNumber() {
    final int start = index;
    bool hasDigit = false;
    bool hasDecimalPoint = false;
    while (index < source.length) {
      final int codeUnit = source.codeUnitAt(index);
      if (codeUnit >= 0x30 && codeUnit <= 0x39) {
        hasDigit = true;
        index++;
        continue;
      }
      if (source[index] == '.' && !hasDecimalPoint) {
        hasDecimalPoint = true;
        index++;
        continue;
      }
      break;
    }
    if (!hasDigit) throw const FormatException();
    return double.parse(source.substring(start, index));
  }
}
