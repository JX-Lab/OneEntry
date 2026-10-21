import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/utils/amount_expression.dart';

void main() {
  group('evaluateAmountExpression', () {
    test('respects operator precedence', () {
      expect(evaluateAmountExpression('12 + 3 * 4'), 24);
    });

    test('supports parentheses and division', () {
      expect(evaluateAmountExpression('(100-20)/4'), 20);
    });

    test('normalizes Chinese and full-width symbols', () {
      expect(evaluateAmountExpression('（１００－２０）÷４'), 20);
      expect(evaluateAmountExpression('12.5×3+6'), 43.5);
    });

    test('supports unary signs and decimals', () {
      expect(evaluateAmountExpression('-2.5 * -4'), 10);
    });

    test('rejects invalid or unsafe expressions', () {
      expect(evaluateAmountExpression(''), isNull);
      expect(evaluateAmountExpression('1+'), isNull);
      expect(evaluateAmountExpression('1/0'), isNull);
      expect(evaluateAmountExpression('1..2'), isNull);
      expect(evaluateAmountExpression('2abc'), isNull);
    });
  });
}
