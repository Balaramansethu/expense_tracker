import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';
import '../models/person.dart';
import '../models/split.dart';

class DatabaseService {
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'expenses.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            description TEXT NOT NULL,
            category TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE people(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE splits(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            expense_id INTEGER NOT NULL,
            person_id INTEGER NOT NULL,
            person_name TEXT NOT NULL,
            total_amount REAL NOT NULL,
            split_amount REAL NOT NULL,
            description TEXT NOT NULL,
            category TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (expense_id) REFERENCES expenses(id),
            FOREIGN KEY (person_id) REFERENCES people(id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE people(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE splits(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              expense_id INTEGER NOT NULL,
              person_id INTEGER NOT NULL,
              person_name TEXT NOT NULL,
              total_amount REAL NOT NULL,
              split_amount REAL NOT NULL,
              description TEXT NOT NULL,
              category TEXT NOT NULL,
              created_at TEXT NOT NULL,
              FOREIGN KEY (expense_id) REFERENCES expenses(id),
              FOREIGN KEY (person_id) REFERENCES people(id)
            )
          ''');
        }
      },
    );
  }

  // --- Expenses ---

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getExpenses({DateTime? from, DateTime? to}) async {
    final db = await database;
    String? where;
    List<String>? whereArgs;

    if (from != null && to != null) {
      where = 'created_at >= ? AND created_at < ?';
      whereArgs = [from.toIso8601String(), to.toIso8601String()];
    }

    final maps = await db.query(
      'expenses',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return maps.map(Expense.fromMap).toList();
  }

  Future<void> updateExpense(Expense expense) async {
    final db = await database;
    await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<Category, double>> getMonthlySummary(int year, int month) async {
    final db = await database;
    final from = DateTime(year, month);
    final to = DateTime(year, month + 1);

    final maps = await db.query(
      'expenses',
      columns: ['category', 'SUM(amount) as total'],
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      groupBy: 'category',
    );

    final summary = <Category, double>{};
    for (final row in maps) {
      final category = Category.values.firstWhere(
        (c) => c.name == row['category'],
        orElse: () => Category.other,
      );
      summary[category] = (row['total'] as num).toDouble();
    }
    return summary;
  }

  // --- People ---

  Future<int> insertPerson(Person person) async {
    final db = await database;
    return db.insert('people', person.toMap());
  }

  Future<List<Person>> getPeople() async {
    final db = await database;
    final maps = await db.query('people', orderBy: 'name ASC');
    return maps.map(Person.fromMap).toList();
  }

  Future<void> deletePerson(int id) async {
    final db = await database;
    await db.delete('people', where: 'id = ?', whereArgs: [id]);
  }

  // --- Splits ---

  Future<int> insertSplit(SplitEntry split) async {
    final db = await database;
    return db.insert('splits', split.toMap());
  }

  Future<List<SplitEntry>> getSplitsForPerson(int personId) async {
    final db = await database;
    final maps = await db.query(
      'splits',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'created_at DESC',
    );
    return maps.map(SplitEntry.fromMap).toList();
  }

  Future<double> getPersonBalance(int personId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(split_amount) as total FROM splits WHERE person_id = ?',
      [personId],
    );
    if (result.isEmpty || result.first['total'] == null) return 0.0;
    return (result.first['total'] as num).toDouble();
  }

  Future<Map<int, double>> getAllBalances() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT person_id, SUM(split_amount) as total FROM splits GROUP BY person_id',
    );
    final balances = <int, double>{};
    for (final row in result) {
      balances[row['person_id'] as int] = (row['total'] as num).toDouble();
    }
    return balances;
  }

  Future<void> clearSplitsForPerson(int personId) async {
    final db = await database;
    await db.delete('splits', where: 'person_id = ?', whereArgs: [personId]);
  }

  Future<double> getTotalExpensesAmount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(amount) as total FROM expenses');
    if (result.isEmpty || result.first['total'] == null) return 0.0;
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getTotalSplitAmount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(split_amount) as total FROM splits');
    if (result.isEmpty || result.first['total'] == null) return 0.0;
    return (result.first['total'] as num).toDouble();
  }
}
