import 'package:flutter_test/flutter_test.dart';
import 'package:voice_expense_app/models/expense.dart';
import 'package:voice_expense_app/services/expense_parser.dart';

const _leadingAmountMarker = 'REFEREE_LEADING_AMOUNT_AMOUNT';

void main() {
  group('ExpenseParser leading amount precedence', () {
    final cases = <_ParseCase>[
      _ParseCase(
        input: 'paid 300 for 2 movie tickets',
        amount: 300.0,
        description: '2 movie tickets',
        category: Category.entertainment,
      ),
      _ParseCase(
        input: 'paid 1200 for rent of 2 months',
        amount: 1200.0,
        description: 'rent of 2 months',
        category: Category.bills,
      ),
      _ParseCase(
        input: 'spent 40 on lunch for 2',
        amount: 40.0,
        description: 'lunch for 2',
        category: Category.food,
      ),
      _ParseCase(
        input: 'spent 500 on dinner at 8',
        amount: 500.0,
        description: 'dinner at 8',
        category: Category.food,
      ),
      _ParseCase(
        input: r'paid $4.50 for coffee',
        amount: 4.50,
        description: 'coffee',
        category: Category.food,
      ),
    ];

    for (final parseCase in cases) {
      test(parseCase.input, () {
        final parsed = ExpenseParser.parse(parseCase.input);

        expect(
          parsed,
          isNotNull,
          reason: '$_leadingAmountMarker: expected a parsed expense',
        );
        expect(
          parsed!.amount,
          parseCase.amount,
          reason:
              '$_leadingAmountMarker: leading amount should be selected for '
              '"${parseCase.input}"',
        );
        expect(
          parsed.description,
          parseCase.description,
          reason:
              '$_leadingAmountMarker: later numbers must stay in description '
              'for "${parseCase.input}"',
        );
        expect(
          parsed.category,
          parseCase.category,
          reason:
              '$_leadingAmountMarker: category should be based on corrected '
              'description for "${parseCase.input}"',
        );
      });
    }
  });

  group('ExpenseParser preserved forms and rejection', () {
    final preservedCases = <_ParseCase>[
      _ParseCase(
        input: 'bought lunch for 12 dollars',
        amount: 12.0,
        description: 'lunch',
        category: Category.food,
      ),
      _ParseCase(
        input: 'spent 50 on lunch',
        amount: 50.0,
        description: 'lunch',
        category: Category.food,
      ),
      _ParseCase(
        input: '50 dollars for groceries',
        amount: 50.0,
        description: 'groceries',
        category: Category.food,
      ),
      _ParseCase(
        input: 'coffee 4.50',
        amount: 4.50,
        description: 'coffee',
        category: Category.food,
      ),
    ];

    for (final parseCase in preservedCases) {
      test(parseCase.input, () {
        final parsed = ExpenseParser.parse(parseCase.input);

        expect(parsed, isNotNull);
        expect(parsed!.amount, parseCase.amount);
        expect(parsed.description, parseCase.description);
        expect(parsed.category, parseCase.category);
      });
    }

    for (final input in ['', '   ', 'hello world', 'paid 0 for lunch']) {
      test('rejects "$input"', () {
        expect(ExpenseParser.parse(input), isNull);
      });
    }
  });
}

class _ParseCase {
  const _ParseCase({
    required this.input,
    required this.amount,
    required this.description,
    required this.category,
  });

  final String input;
  final double amount;
  final String description;
  final Category category;
}
