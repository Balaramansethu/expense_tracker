import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/expense.dart';
import '../models/person.dart';
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
    await _db.deleteExpense(expense.id!);
    await _reload();
  }

  Future<void> undoDelete() async {
    if (_lastDeleted == null) return;
    await _db.insertExpense(_lastDeleted!);
    _lastDeleted = null;
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

  Future<List<SplitEntry>> getSplitsForPerson(int personId) async {
    return _db.getSplitsForPerson(personId);
  }

  Future<double> getPersonBalance(int personId) async {
    return _db.getPersonBalance(personId);
  }

  Future<Map<int, double>> getAllBalances() async {
    return _db.getAllBalances();
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

  @override
  void dispose() {
    _cancelTimeout();
    super.dispose();
  }
}
