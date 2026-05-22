import 'package:flutter_test/flutter_test.dart';
import 'package:voice_expense_app/services/expense_parser.dart';
import 'package:voice_expense_app/models/expense.dart';

void main() {
  group('ExpenseParser', () {
    test('parses "spent 50 on lunch"', () {
      final result = ExpenseParser.parse('spent 50 on lunch');
      expect(result, isNotNull);
      expect(result!.amount, 50.0);
      expect(result.description, 'lunch');
      expect(result.category, Category.food);
    });

    test('parses "paid \$30 for uber"', () {
      final result = ExpenseParser.parse('paid \$30 for uber');
      expect(result, isNotNull);
      expect(result!.amount, 30.0);
      expect(result.description, 'uber');
      expect(result.category, Category.transport);
    });

    test('parses "coffee 4.50"', () {
      final result = ExpenseParser.parse('coffee 4.50');
      expect(result, isNotNull);
      expect(result!.amount, 4.50);
      expect(result.description, 'coffee');
      expect(result.category, Category.food);
    });

    test('parses "50 dollars for groceries"', () {
      final result = ExpenseParser.parse('50 dollars for groceries');
      expect(result, isNotNull);
      expect(result!.amount, 50.0);
      expect(result.description, 'groceries');
      expect(result.category, Category.food);
    });

    test('parses number words "spent twenty five on dinner"', () {
      final result = ExpenseParser.parse('spent twenty five on dinner');
      expect(result, isNotNull);
      expect(result!.amount, 25.0);
      expect(result.description, 'dinner');
    });

    test('returns null for empty input', () {
      expect(ExpenseParser.parse(''), isNull);
      expect(ExpenseParser.parse('   '), isNull);
    });

    test('returns null for text without amounts', () {
      expect(ExpenseParser.parse('hello world'), isNull);
    });
  });

  group('Category detection', () {
    test('detects food category', () {
      expect(ExpenseParser.categorize('pizza'), Category.food);
      expect(ExpenseParser.categorize('groceries'), Category.food);
    });

    test('detects transport category', () {
      expect(ExpenseParser.categorize('uber ride'), Category.transport);
      expect(ExpenseParser.categorize('gas station'), Category.transport);
    });

    test('defaults to other', () {
      expect(ExpenseParser.categorize('random stuff'), Category.other);
    });
  });
}
