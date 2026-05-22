import '../models/expense.dart';

class ParsedExpense {
  final double amount;
  final String description;
  final Category category;

  const ParsedExpense({
    required this.amount,
    required this.description,
    required this.category,
  });
}

class ExpenseParser {
  // "spent 50 on lunch", "paid $30 for dinner", "cost me 25 bucks for gas"
  static final _verbFirst = RegExp(
    r'(?:spent|paid|cost(?:\s+me)?|gave|bought)\s+'
    r'[\$£€]?\s*(\d+(?:\.\d{1,2})?)\s*(?:dollars?|bucks?)?\s*'
    r'(?:on|for|to|at)?\s*(.*)',
    caseSensitive: false,
  );

  // "50 dollars on groceries", "$25 for uber"
  static final _amountFirst = RegExp(
    r'[\$£€]?\s*(\d+(?:\.\d{1,2})?)\s*(?:dollars?|bucks?)?\s+'
    r'(?:on|for|to|at)\s+(.*)',
    caseSensitive: false,
  );

  // "lunch 12.50", "coffee 4", "uber 15 dollars"
  static final _descAmount = RegExp(
    r'([a-zA-Z][a-zA-Z\s]*?)\s+'
    r'[\$£€]?\s*(\d+(?:\.\d{1,2})?)\s*(?:dollars?|bucks?)?$',
    caseSensitive: false,
  );

  // "bought lunch for 12 dollars", "got groceries for 45"
  static final _verbDescAmount = RegExp(
    r'(?:spent|paid|cost|gave|bought|got)\s+'
    r'(?:a\s+|an\s+|the\s+|some\s+)?'
    r'(.*?)\s+(?:for|at|of)\s+'
    r'[\$£€]?\s*(\d+(?:\.\d{1,2})?)\s*(?:dollars?|bucks?)?',
    caseSensitive: false,
  );

  static final _numberWords = <String, int>{
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
    'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18,
    'nineteen': 19, 'twenty': 20, 'thirty': 30, 'forty': 40,
    'fifty': 50, 'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
    'hundred': 100,
  };

  static ParsedExpense? parse(String text) {
    if (text.trim().isEmpty) return null;

    // Replace number words with digits before matching
    var processed = _replaceNumberWords(text.trim());

    double? amount;
    String? description;

    // Try patterns in priority order
    var match = _verbDescAmount.firstMatch(processed);
    if (match != null) {
      description = match.group(1)?.trim();
      amount = double.tryParse(match.group(2) ?? '');
    }

    if (amount == null) {
      match = _verbFirst.firstMatch(processed);
      if (match != null) {
        amount = double.tryParse(match.group(1) ?? '');
        description = match.group(2)?.trim();
      }
    }

    if (amount == null) {
      match = _amountFirst.firstMatch(processed);
      if (match != null) {
        amount = double.tryParse(match.group(1) ?? '');
        description = match.group(2)?.trim();
      }
    }

    if (amount == null) {
      match = _descAmount.firstMatch(processed);
      if (match != null) {
        description = match.group(1)?.trim();
        amount = double.tryParse(match.group(2) ?? '');
      }
    }

    if (amount == null || amount <= 0) return null;

    description = _cleanDescription(description ?? 'Expense');
    if (description.isEmpty) description = 'Expense';

    return ParsedExpense(
      amount: amount,
      description: description,
      category: categorize(description),
    );
  }

  static String _replaceNumberWords(String text) {
    var result = text.toLowerCase();

    // Handle compound numbers: "twenty five" -> 25
    final compoundPattern = RegExp(
      r'\b(twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)\s+'
      r'(one|two|three|four|five|six|seven|eight|nine)\b',
    );
    result = result.replaceAllMapped(compoundPattern, (m) {
      final tens = _numberWords[m.group(1)] ?? 0;
      final ones = _numberWords[m.group(2)] ?? 0;
      return '${tens + ones}';
    });

    // Handle "X hundred" patterns
    final hundredPattern = RegExp(
      r'\b(one|two|three|four|five|six|seven|eight|nine|ten)\s+hundred\b',
    );
    result = result.replaceAllMapped(hundredPattern, (m) {
      final multiplier = _numberWords[m.group(1)] ?? 1;
      return '${multiplier * 100}';
    });

    // Handle single number words
    for (final entry in _numberWords.entries) {
      if (entry.value <= 100) {
        result = result.replaceAll(
          RegExp('\\b${entry.key}\\b'),
          '${entry.value}',
        );
      }
    }

    return result;
  }

  static String _cleanDescription(String desc) {
    return desc
        .replaceAll(RegExp(r'^(a|an|the|some)\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'[.\,!?]+$'), '')
        .trim();
  }

  static Category categorize(String description) {
    final lower = description.toLowerCase();
    for (final cat in Category.values) {
      if (cat == Category.other) continue;
      for (final keyword in cat.keywords) {
        if (RegExp('\\b$keyword\\b').hasMatch(lower)) {
          return cat;
        }
      }
    }
    return Category.other;
  }
}
