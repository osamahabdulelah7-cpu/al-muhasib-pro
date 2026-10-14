import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/financial_entry.dart';

class AccountingDatabase {
  AccountingDatabase._();
  static final AccountingDatabase instance = AccountingDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final directory = await getApplicationDocumentsDirectory();
    _database = await openDatabase(
      p.join(directory.path, 'al_muhasib_pro.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE financial_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
            type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
            created_at TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('CREATE INDEX idx_entries_created_at ON financial_entries(created_at)');
      },
    );
    return _database!;
  }

  Future<List<FinancialEntry>> getEntries() async {
    final rows = await (await database).query('financial_entries', orderBy: 'created_at DESC, id DESC');
    return rows.map(FinancialEntry.fromMap).toList(growable: false);
  }

  Future<int> addEntry(FinancialEntry entry) async {
    if (entry.title.trim().isEmpty) throw ArgumentError('يجب إدخال وصف للحركة');
    if (entry.amountMinor <= 0) throw ArgumentError('يجب أن يكون المبلغ أكبر من صفر');
    return (await database).insert('financial_entries', entry.toMap()..remove('id'));
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
