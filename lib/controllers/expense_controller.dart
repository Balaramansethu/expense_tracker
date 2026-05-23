import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../models/person.dart';
import '../models/recurring_expense.dart';
import '../models/split.dart';
import '../services/database.dart';
import '../services/speech_service.dart';
import '../services/expense_parser.dart';

class ExpenseController extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final SpeechService _speech = SpeechService();

  // Expense data
  List<Expense> _expenses = [];
  Map<Category, double> _monthlySummary = {};
  double _monthlyTotal = 0;
  int _currentYear = DateTime.now().year;
  int _currentMonth = DateTime.now().month;

  // Voice input state
  String _liveTranscript = '';
  ParsedExpense? _parsedPreview;
  bool _isListening = false;
  bool _isSpeechAvailable = false;
  bool _permissionDenied = false;
  String? _errorMessage;

  // Safety timeout
  Timer? _listenTimeout;

  // Debounce: track last parsed text to avoid redundant parses
  String _lastParsedText = '';

  // People & splits
  List<Person> _people = [];

  // Undo support
  Expense? _lastDeleted;
  List<SplitEntry> _lastDeletedSplits = [];

  // Getters
  List<Expense> get expenses => _expenses;
  Map<Category, double> get monthlySummary => _monthlySummary;
  double get monthlyTotal => _monthlyTotal;
  int get currentYear => _currentYear;
  int get currentMonth => _currentMonth;
  String get liveTranscript => _liveTranscript;
  ParsedExpense? get parsedPreview => _parsedPreview;
  bool get isListening => _isListening;
  bool get isSpeechAvailable => _isSpeechAvailable;
  bool get permissionDenied => _permissionDenied;
  String? get errorMessage => _errorMessage;
  List<Person> get people => _people;

  Future<void> init() async {
    await _initSpeech();
    await loadExpenses();
    await loadMonthlySummary();
    await loadPeople();
    await loadRecurring();
    await processRecurringExpenses();
  }

  Future<void> _initSpeech() async {
    // Check microphone permission first
    final micStatus = await Permission.microphone.status;
    if (micStatus.isDenied) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        _permissionDenied = true;
        _isSpeechAvailable = false;
        return;
      }
    } else if (micStatus.isPermanentlyDenied) {
      _permissionDenied = true;
      _isSpeechAvailable = false;
      return;
    }

    _permissionDenied = false;
    _isSpeechAvailable = await _speech.initialize(
      onError: _onSpeechError,
      onStatus: _onSpeechStatus,
    );
  }

  void _onSpeechError(String error) {
    _isListening = false;
    _cancelTimeout();
    // Don't overwrite transcript — user can still see what was captured
    if (_liveTranscript.isEmpty) {
      _errorMessage = 'Speech recognition failed. Try again.';
    }
    notifyListeners();
  }

  void _onSpeechStatus(String status) {
    // Speech engine reports "done" or "notListening" when it stops
    if (status == 'done' || status == 'notListening') {
      if (_isListening) {
        _isListening = false;
        _cancelTimeout();
        notifyListeners();
      }
    }
  }

  // --- Data loading ---

  Future<void> loadExpenses() async {
    final from = DateTime(_currentYear, _currentMonth);
    final to = DateTime(_currentYear, _currentMonth + 1);
    _expenses = await _db.getExpenses(from: from, to: to);
    notifyListeners();
  }

  Future<void> loadMonthlySummary() async {
    _monthlySummary = await _db.getMonthlySummary(_currentYear, _currentMonth);
    _monthlyTotal = _monthlySummary.values.fold(0.0, (a, b) => a + b);
    notifyListeners();
  }

  Future<void> _reload() async {
    await loadExpenses();
    await loadMonthlySummary();
  }

  // --- Month navigation ---

  void previousMonth() {
    if (_currentMonth == 1) {
      _currentMonth = 12;
      _currentYear--;
    } else {
      _currentMonth--;
    }
    _reload();
  }

  void nextMonth() {
    final now = DateTime.now();
    if (_currentYear == now.year && _currentMonth == now.month) return;
    if (_currentMonth == 12) {
      _currentMonth = 1;
      _currentYear++;
    } else {
      _currentMonth++;
    }
    _reload();
  }

  bool get canGoNext {
    final now = DateTime.now();
    return !(_currentYear == now.year && _currentMonth == now.month);
  }

  // --- Voice flow ---

  Future<void> startListening() async {
    // Clear previous state
    _liveTranscript = '';
    _parsedPreview = null;
    _errorMessage = null;
    _lastParsedText = '';

    // Check permission first
    if (_permissionDenied || !_isSpeechAvailable) {
      // Try one more time — permission may have been granted in Settings
      await _initSpeech();
    }

    if (_permissionDenied) {
      _errorMessage = 'Microphone permission denied. Please enable it in Settings.';
      notifyListeners();
      return;
    }

    if (!_isSpeechAvailable) {
      _errorMessage = 'Speech recognition not available on this device.';
      notifyListeners();
      return;
    }

    // Now safe to show listening state
    _isListening = true;
    notifyListeners();

    final started = await _speech.startListening(
      onResult: (text, isFinal) {
        _liveTranscript = text;

        // Only parse when text actually changed and has substance
        if (text != _lastParsedText && text.trim().length > 2) {
          _lastParsedText = text;
          try {
            _parsedPreview = ExpenseParser.parse(text);
          } catch (_) {
            // Parser failure is non-fatal — keep transcript visible
            _parsedPreview = null;
          }
        }

        if (isFinal) {
          _isListening = false;
          _cancelTimeout();
        }
        notifyListeners();
      },
      onError: (error) {
        _onSpeechError(error);
      },
    );

    if (!started) {
      // startListening returned false — engine failed to start
      _isListening = false;
      _errorMessage = 'Could not start speech recognition. Try again.';
      notifyListeners();
      return;
    }

    // Safety timeout: if speech engine hangs, recover after 35s
    _startTimeout();
  }

  void _startTimeout() {
    _cancelTimeout();
    _listenTimeout = Timer(const Duration(seconds: 35), () {
      if (_isListening) {
        _speech.stopListening();
        _isListening = false;
        if (_liveTranscript.isEmpty) {
          _errorMessage = 'No speech detected. Tap the mic to try again.';
        }
        notifyListeners();
      }
    });
  }

  void _cancelTimeout() {
    _listenTimeout?.cancel();
    _listenTimeout = null;
  }

  Future<void> stopListening() async {
    _cancelTimeout();
    await _speech.stopListening();
    _isListening = false;
    notifyListeners();
  }

  Future<void> cancelVoiceInput() async {
    _cancelTimeout();
    await _speech.cancelListening();
    _isListening = false;
    _liveTranscript = '';
    _parsedPreview = null;
    notifyListeners();
  }

  /// Called when the voice sheet is dismissed (by any means).
  /// Guarantees speech stops and state is clean.
  Future<void> stopAndCleanup() async {
    _cancelTimeout();
    if (_isListening) {
      await _speech.stopListening();
      _isListening = false;
    }
    // Don't clear transcript/preview — user may reopen sheet
    notifyListeners();
  }

  void clearVoiceState() {
    _liveTranscript = '';
    _parsedPreview = null;
    _errorMessage = null;
    _lastParsedText = '';
    notifyListeners();
  }

  // --- CRUD ---

  Future<void> saveExpense({
    required double amount,
    required String description,
    required Category category,
  }) async {
    final expense = Expense(
      amount: amount,
      description: description,
      category: category,
      createdAt: DateTime.now(),
    );
    await _db.insertExpense(expense);
    clearVoiceState();
    await _reload();
  }

  Future<void> updateExpense(Expense expense) async {
    await _db.updateExpense(expense);
    await _reload();
  }

  Future<void> deleteExpense(Expense expense) async {
    if (expense.id == null) return;
    _lastDeleted = expense;
    _lastDeletedSplits = await _db.getSplitsForExpense(expense.id!);
    await _db.deleteExpense(expense.id!);
    await _reload();
  }

  Future<void> undoDelete() async {
    if (_lastDeleted == null) return;
    final newId = await _db.insertExpense(_lastDeleted!);
    // Restore splits with the new expense ID
    for (final split in _lastDeletedSplits) {
      final restored = SplitEntry(
        expenseId: newId,
        personId: split.personId,
        personName: split.personName,
        totalAmount: split.totalAmount,
        splitAmount: split.splitAmount,
        description: split.description,
        category: split.category,
        createdAt: split.createdAt,
      );
      await _db.insertSplit(restored);
    }
    _lastDeleted = null;
    _lastDeletedSplits = [];
    await _reload();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // --- Grouping for display ---

  Map<String, List<Expense>> get groupedExpenses {
    final groups = <String, List<Expense>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final expense in _expenses) {
      final date = DateTime(
        expense.createdAt.year,
        expense.createdAt.month,
        expense.createdAt.day,
      );

      String label;
      if (date == today) {
        label = 'Today';
      } else if (date == yesterday) {
        label = 'Yesterday';
      } else {
        label =
            '${_monthName(date.month)} ${date.day}';
      }

      groups.putIfAbsent(label, () => []).add(expense);
    }
    return groups;
  }

  static String _monthName(int month) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[month];
  }

  // --- People ---

  Future<void> loadPeople() async {
    _people = await _db.getPeople();
    notifyListeners();
  }

  Future<void> addPerson(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final person = Person(name: trimmed, createdAt: DateTime.now());
    await _db.insertPerson(person);
    await loadPeople();
  }

  Future<void> removePerson(int id) async {
    await _db.deletePerson(id);
    await loadPeople();
  }

  // --- Splits ---

  /// Save an expense split across multiple people with custom amounts.
  /// [splits] maps each person to the amount they owe.
  /// The remainder (total - sum of splits) is "your part".
  Future<void> saveSplitExpense({
    required double amount,
    required String description,
    required Category category,
    required Map<Person, double> splits,
  }) async {
    final now = DateTime.now();
    final expense = Expense(
      amount: amount,
      description: description,
      category: category,
      createdAt: now,
    );
    final expenseId = await _db.insertExpense(expense);

    for (final entry in splits.entries) {
      final person = entry.key;
      final splitAmount = entry.value;
      if (splitAmount <= 0) continue;

      final split = SplitEntry(
        expenseId: expenseId,
        personId: person.id!,
        personName: person.name,
        totalAmount: amount,
        splitAmount: splitAmount,
        description: description,
        category: category.name,
        createdAt: now,
      );
      await _db.insertSplit(split);
    }

    clearVoiceState();
    await _reload();
  }

  /// Add splits to an existing expense (used from edit dialog).
  /// Clears any previous splits for this expense first.
  Future<void> addSplitsToExpense({
    required int expenseId,
    required double totalAmount,
    required String description,
    required Category category,
    required Map<Person, double> splits,
  }) async {
    // Remove old splits for this expense
    await _db.deleteSplitsForExpense(expenseId);

    final now = DateTime.now();
    for (final entry in splits.entries) {
      final person = entry.key;
      final splitAmount = entry.value;
      if (splitAmount <= 0) continue;

      final split = SplitEntry(
        expenseId: expenseId,
        personId: person.id!,
        personName: person.name,
        totalAmount: totalAmount,
        splitAmount: splitAmount,
        description: description,
        category: category.name,
        createdAt: now,
      );
      await _db.insertSplit(split);
    }

    await _reload();
  }

  Future<List<SplitEntry>> getSplitsForPerson(int personId) async {
    return _db.getSplitsForPerson(personId);
  }

  Future<double> getPersonBalance(int personId) async {
    return _db.getPersonBalance(personId);
  }

  Future<Map<int, double>> getAllBalances() async {
    return _db.getAllBalances();
  }

  /// Get all expenses (no month filter) for detail view.
  Future<List<Expense>> getAllExpenses() async {
    return _db.getAllExpenses();
  }

  /// Clear all expenses and splits. Full reset.
  Future<void> clearAllExpenses() async {
    await _db.clearAllExpenses();
    await _reload();
    notifyListeners();
  }

  /// Clear all splits for a person (settle up / clear tab).
  Future<void> clearPersonTab(int personId) async {
    await _db.clearSplitsForPerson(personId);
    notifyListeners();
  }

  /// Get total of all expenses ever recorded.
  Future<double> getTotalExpenses() async {
    return _db.getTotalExpensesAmount();
  }

  /// Get "my actual share" = total expenses - what others owe me.
  Future<double> getMyActualShare() async {
    final total = await _db.getTotalExpensesAmount();
    final othersOwe = await _db.getTotalSplitAmount();
    return total - othersOwe;
  }

  String generateReport(Person person, List<SplitEntry> splits, double balance) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final buf = StringBuffer();

    buf.writeln('--- Split Report: ${person.name} ---');
    buf.writeln('Generated: ${dateFormat.format(DateTime.now())}');
    buf.writeln();

    for (final s in splits) {
      final desc = s.description.padRight(20);
      final total = s.totalAmount.toStringAsFixed(2);
      final part = s.splitAmount.toStringAsFixed(2);
      final date = dateFormat.format(s.createdAt);
      buf.writeln('$desc  \$$total  ->  Split  ->  \$$part their part  ($date)');
    }

    buf.writeln();
    buf.writeln('Total splits: ${splits.length}');
    buf.writeln('Total amount: \$${splits.fold(0.0, (sum, s) => sum + s.totalAmount).toStringAsFixed(2)}');
    buf.writeln('${person.name} owes you: \$${balance.toStringAsFixed(2)}');

    return buf.toString();
  }

  // --- Save with image ---

  Future<void> saveExpenseWithImage({
    required double amount,
    required String description,
    required Category category,
    String? imagePath,
  }) async {
    final expense = Expense(
      amount: amount,
      description: description,
      category: category,
      createdAt: DateTime.now(),
      imagePath: imagePath,
    );
    await _db.insertExpense(expense);
    clearVoiceState();
    await _reload();
  }

  // --- Recurring Expenses ---

  List<RecurringExpense> _recurringExpenses = [];
  List<RecurringExpense> get recurringExpenses => _recurringExpenses;

  Future<void> loadRecurring() async {
    _recurringExpenses = await _db.getRecurringExpenses();
    notifyListeners();
  }

  Future<void> addRecurring({
    required double amount,
    required String description,
    required Category category,
    required int dayOfMonth,
  }) async {
    final recurring = RecurringExpense(
      amount: amount,
      description: description,
      category: category,
      dayOfMonth: dayOfMonth,
      createdAt: DateTime.now(),
    );
    await _db.insertRecurring(recurring);
    await loadRecurring();
  }

  Future<void> updateRecurring(RecurringExpense recurring) async {
    await _db.updateRecurring(recurring);
    await loadRecurring();
  }

  Future<void> deleteRecurring(int id) async {
    await _db.deleteRecurring(id);
    await loadRecurring();
  }

  /// Auto-log recurring expenses that are due.
  /// Called on app launch. For each active recurring expense,
  /// checks if it should have been logged this month (or missed months).
  /// Auto-log recurring expenses that are due.
  /// Called on app launch. For each active recurring expense,
  /// checks if it should have been logged this month (or missed months).
  Future<int> processRecurringExpenses() async {
    final recurring = await _db.getRecurringExpenses();
    final now = DateTime.now();
    int totalLogged = 0;

    for (final r in recurring) {
      if (!r.isActive) continue;

      int itemLogged = 0;

      // Determine which months need logging
      DateTime checkFrom;
      if (r.lastLoggedAt != null) {
        // Start from the month after last logged
        checkFrom = DateTime(r.lastLoggedAt!.year, r.lastLoggedAt!.month + 1, 1);
      } else {
        // Never logged — start from creation month
        checkFrom = DateTime(r.createdAt.year, r.createdAt.month, 1);
      }

      final currentMonth = DateTime(now.year, now.month, 1);

      while (!checkFrom.isAfter(currentMonth)) {
        final dueDay = r.dayOfMonth;
        final dueDate = DateTime(checkFrom.year, checkFrom.month, dueDay);

        // Only log if the due date has passed (or is today)
        if (!dueDate.isAfter(now)) {
          final expense = Expense(
            amount: r.amount,
            description: r.description,
            category: r.category,
            createdAt: dueDate,
          );
          await _db.insertExpense(expense);
          itemLogged++;
        }

        checkFrom = DateTime(checkFrom.year, checkFrom.month + 1, 1);
      }

      // Update last_logged_at only if this item actually logged entries
      if (itemLogged > 0) {
        await _db.updateRecurring(r.copyWith(lastLoggedAt: now));
        totalLogged += itemLogged;
      }
    }

    if (totalLogged > 0) {
      await _reload();
      await loadRecurring();
    }
    return totalLogged;
  }

  // --- Insights ---

  Future<List<String>> generateInsights() async {
    final insights = <String>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // This week vs last week
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));
    final thisWeekSpent = await _db.getTotalInRange(weekStart, today.add(const Duration(days: 1)));
    final lastWeekSpent = await _db.getTotalInRange(lastWeekStart, weekStart);

    if (lastWeekSpent > 0 && thisWeekSpent > 0) {
      final pctChange = ((thisWeekSpent - lastWeekSpent) / lastWeekSpent * 100).round();
      if (pctChange > 15) {
        insights.add('Spending is up $pctChange% this week compared to last week.');
      } else if (pctChange < -15) {
        insights.add('Great job! Spending is down ${-pctChange}% this week vs last week.');
      }
    }

    // Category comparison: this week vs average
    final thisWeekCats = await _db.getCategoryTotals(weekStart, today.add(const Duration(days: 1)));
    final lastWeekCats = await _db.getCategoryTotals(lastWeekStart, weekStart);
    for (final cat in thisWeekCats.keys) {
      final thisVal = thisWeekCats[cat] ?? 0;
      final lastVal = lastWeekCats[cat] ?? 0;
      if (lastVal > 10 && thisVal > lastVal * 1.3) {
        final pct = ((thisVal - lastVal) / lastVal * 100).round();
        final catName = cat[0].toUpperCase() + cat.substring(1);
        insights.add('$catName spending is up $pct% this week.');
        break; // only show top category change
      }
    }

    // Budget pace prediction
    final budget = await _db.getActiveBudget();
    if (budget != null) {
      final budgetStart = budget.startDate;
      final budgetEnd = budget.endDate;
      final totalDays = budgetEnd.difference(budgetStart).inDays + 1;
      final elapsed = today.difference(budgetStart).inDays + 1;

      if (elapsed > 3 && elapsed < totalDays) {
        final spentSoFar = await _db.getTotalInRange(
          budgetStart,
          today.add(const Duration(days: 1)),
        );
        final dailyRate = spentSoFar / elapsed;
        final projected = dailyRate * totalDays;

        if (projected > budget.amount * 1.1) {
          final overBy = (projected - budget.amount).toStringAsFixed(0);
          final daysLeft = totalDays - elapsed;
          insights.add('At this pace, you\'ll exceed your budget by \$$overBy with $daysLeft days left.');
        } else if (projected < budget.amount * 0.8) {
          insights.add('You\'re well under budget — on track to save \$${(budget.amount - projected).toStringAsFixed(0)}.');
        }
      }
    }

    // No-spend days this week
    final todayCount = await _db.getCountInRange(today, today.add(const Duration(days: 1)));
    if (todayCount == 0 && now.hour >= 18) {
      insights.add('No expenses logged today — did you forget to track something?');
    }

    // Biggest spending day pattern
    final dailySpend = await _db.getDailyExpenses(
      today.subtract(const Duration(days: 28)),
      today.add(const Duration(days: 1)),
    );
    if (dailySpend.length >= 7) {
      final dayTotals = <int, double>{}; // weekday → total
      final dayCounts = <int, int>{};
      for (final entry in dailySpend.entries) {
        final wd = entry.key.weekday;
        dayTotals[wd] = (dayTotals[wd] ?? 0) + entry.value;
        dayCounts[wd] = (dayCounts[wd] ?? 0) + 1;
      }
      int? biggestDay;
      double biggestAvg = 0;
      for (final wd in dayTotals.keys) {
        final avg = dayTotals[wd]! / dayCounts[wd]!;
        if (avg > biggestAvg) {
          biggestAvg = avg;
          biggestDay = wd;
        }
      }
      if (biggestDay != null && insights.length < 3) {
        const dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        insights.add('Your biggest spending day is usually ${dayNames[biggestDay]}.');
      }
    }

    return insights.take(3).toList();
  }

  // --- Budget ---

  Future<void> setBudget(double amount, DateTime startDate, DateTime endDate) async {
    final budget = Budget(
      amount: amount,
      startDate: startDate,
      endDate: endDate,
      createdAt: DateTime.now(),
    );
    await _db.insertBudget(budget);
    notifyListeners();
  }

  Future<Budget?> getActiveBudget() async {
    return _db.getActiveBudget();
  }

  Future<void> deleteBudget() async {
    await _db.deleteBudget();
    notifyListeners();
  }

  Future<Map<DateTime, double>> getDailySpending(DateTime start, DateTime end) async {
    return _db.getDailyExpenses(start, end);
  }

  @override
  void dispose() {
    _cancelTimeout();
    super.dispose();
  }
}
