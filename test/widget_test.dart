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

    test('parses thousands-separated rent amount', () {
      final result = ExpenseParser.parse('spent 1,200 on rent');
      expect(result, isNotNull);
      expect(result!.amount, 1200.0);
      expect(result.description, 'rent');
      expect(result.category, Category.bills);
    });

    test('parses thousands-separated flight amount', () {
      final result = ExpenseParser.parse('paid \$2,500 for flight');
      expect(result, isNotNull);
      expect(result!.amount, 2500.0);
      expect(result.description, 'flight');
      expect(result.category, Category.travel);
    });

    test('parses thousands-separated decimal rent amount', () {
      final result = ExpenseParser.parse('spent 1,200.50 on rent');
      expect(result, isNotNull);
      expect(result!.amount, 1200.5);
      expect(result.description, 'rent');
      expect(result.category, Category.bills);
    });

    test('does not include unrelated digits in trailing-comma description', () {
      final result = ExpenseParser.parse('spent 1, on food');
      expect(result, isNotNull);
      expect(result!.amount, 1.0);
      expect(result.description, isNot(matches(RegExp(r'\d'))));
    });

    test('parses Indian-grouped rent amount', () {
      final result = ExpenseParser.parse('spent 1,00,000 on rent');
      expect(result, isNotNull);
      expect(result!.amount, 100000.0);
      expect(result.description, 'rent');
      expect(result.category, Category.bills);
    });

    test('re-asserts pre-fix lunch parsing', () {
      final result = ExpenseParser.parse('spent 50 on lunch');
      expect(result, isNotNull);
      expect(result!.amount, 50.0);
      expect(result.description, 'lunch');
      expect(result.category, Category.food);
    });

    test('re-asserts pre-fix uber parsing', () {
      final result = ExpenseParser.parse('paid \$30 for uber');
      expect(result, isNotNull);
      expect(result!.amount, 30.0);
      expect(result.description, 'uber');
      expect(result.category, Category.transport);
    });

    test('re-asserts pre-fix coffee parsing', () {
      final result = ExpenseParser.parse('coffee 4.50');
      expect(result, isNotNull);
      expect(result!.amount, 4.5);
      expect(result.description, 'coffee');
      expect(result.category, Category.food);
    });

    test('re-asserts pre-fix groceries parsing', () {
      final result = ExpenseParser.parse('50 dollars for groceries');
      expect(result, isNotNull);
      expect(result!.amount, 50.0);
      expect(result.description, 'groceries');
      expect(result.category, Category.food);
    });

    test('re-asserts pre-fix number-word dinner parsing', () {
      final result = ExpenseParser.parse('spent twenty five on dinner');
      expect(result, isNotNull);
      expect(result!.amount, 25.0);
      expect(result.description, 'dinner');
      expect(result.category, Category.food);
    });

    test('re-asserts null for hello world', () {
      expect(ExpenseParser.parse('hello world'), isNull);
    });

    test('re-asserts null for whitespace-only input', () {
      expect(ExpenseParser.parse('   '), isNull);
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
