import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/account.dart';
import '../models/financial_entry.dart';
import '../models/journal_entry.dart';
import '../models/trial_balance.dart';

class AccountingDatabase {
  AccountingDatabase._();
  static final AccountingDatabase instance = AccountingDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final directory = await getApplicationDocumentsDirectory();
    _database = await openDatabase(
      p.join(directory.path, 'al_muhasib_pro.db'),
      version: 2,
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seedAccounts(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createAccountingTables(db);
          await _seedAccounts(db);
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    return _database!;
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
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
    await _createAccountingTables(db);
  }

  Future<void> _createAccountingTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('asset','liability','equity','income','expense')),
        parent_id INTEGER REFERENCES accounts(id),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1))
      )
    ''');
    await db.execute('''
      CREATE TABLE journal_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reference TEXT NOT NULL UNIQUE,
        description TEXT NOT NULL,
        entry_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'posted' CHECK(status IN ('posted','reversed'))
      )
    ''');
    await db.execute('''
      CREATE TABLE journal_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        journal_entry_id INTEGER NOT NULL REFERENCES journal_entries(id) ON DELETE RESTRICT,
        account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
        debit_minor INTEGER NOT NULL DEFAULT 0 CHECK(debit_minor >= 0),
        credit_minor INTEGER NOT NULL DEFAULT 0 CHECK(credit_minor >= 0),
        CHECK((debit_minor > 0 AND credit_minor = 0) OR
              (credit_minor > 0 AND debit_minor = 0))
      )
    ''');
    await db.execute('CREATE INDEX idx_journal_date ON journal_entries(entry_date)');
    await db.execute('CREATE INDEX idx_journal_lines_account ON journal_lines(account_id)');
  }

  Future<void> _seedAccounts(DatabaseExecutor db) async {
    const roots = <Account>[
      Account(code: '1000', name: 'الأصول', type: AccountType.asset),
      Account(code: '2000', name: 'الالتزامات', type: AccountType.liability),
      Account(code: '3000', name: 'حقوق الملكية', type: AccountType.equity),
      Account(code: '4000', name: 'الإيرادات', type: AccountType.income),
      Account(code: '5000', name: 'المصروفات', type: AccountType.expense),
    ];
    for (final account in roots) {
      await db.insert('accounts', account.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    const children = <({String code, String name, AccountType type, String parentCode})>[
      (code: '1010', name: 'الصندوق', type: AccountType.asset, parentCode: '1000'),
      (code: '1100', name: 'العملاء', type: AccountType.asset, parentCode: '1000'),
      (code: '2010', name: 'الموردون', type: AccountType.liability, parentCode: '2000'),
    ];
    for (final child in children) {
      final parent = await db.query('accounts',
          columns: ['id'], where: 'code = ?', whereArgs: [child.parentCode], limit: 1);
      await db.insert('accounts', {
        'code': child.code,
        'name': child.name,
        'type': child.type.name,
        'parent_id': parent.isEmpty ? null : parent.first['id'],
        'is_active': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<FinancialEntry>> getEntries() async {
    final rows = await (await database).query('financial_entries',
        orderBy: 'created_at DESC, id DESC');
    return rows.map(FinancialEntry.fromMap).toList(growable: false);
  }

  Future<int> addEntry(FinancialEntry entry) async {
    if (entry.title.trim().isEmpty) throw ArgumentError('يجب إدخال وصف للحركة');
    if (entry.amountMinor <= 0) throw ArgumentError('يجب أن يكون المبلغ أكبر من صفر');
    return (await database).insert('financial_entries', entry.toMap()..remove('id'));
  }

  Future<List<Account>> getAccounts({bool activeOnly = false}) async {
    final rows = await (await database).query(
      'accounts',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'code ASC',
    );
    return rows.map(Account.fromMap).toList(growable: false);
  }

  Future<int> addAccount(Account account) async {
    if (account.code.trim().isEmpty || account.name.trim().isEmpty) {
      throw ArgumentError('رمز الحساب واسم الحساب مطلوبان');
    }
    return (await database).insert('accounts', account.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> postJournalEntry(JournalEntry entry) async {
    entry.validateForPosting();
    final db = await database;
    return db.transaction((txn) async {
      final headerId = await txn.insert('journal_entries', {
        'reference': entry.reference.trim(),
        'description': entry.description.trim(),
        'entry_date': entry.date.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'status': 'posted',
      });
      for (final line in entry.lines) {
        final accounts = await txn.query('accounts',
            columns: ['id'],
            where: 'code = ? AND is_active = 1',
            whereArgs: [line.accountCode],
            limit: 1);
        if (accounts.isEmpty) {
          throw StateError('الحساب ${line.accountCode} غير موجود أو غير نشط');
        }
        await txn.insert('journal_lines', {
          'journal_entry_id': headerId,
          'account_id': accounts.first['id'],
          'debit_minor': line.debitMinor,
          'credit_minor': line.creditMinor,
        });
      }
      final totals = await txn.rawQuery(
        'SELECT COALESCE(SUM(debit_minor),0) AS debit, COALESCE(SUM(credit_minor),0) AS credit FROM journal_lines WHERE journal_entry_id = ?',
        [headerId],
      );
      final debit = totals.first['debit'] as int;
      final credit = totals.first['credit'] as int;
      if (debit <= 0 || debit != credit) {
        throw StateError('فشل التحقق النهائي من توازن القيد');
      }
      return headerId;
    });
  }

  Future<TrialBalance> getTrialBalance({
    DateTime? from,
    DateTime? through,
  }) async {
    final db = await database;
    final clauses = <String>[];
    final args = <Object?>[];
    if (from != null) {
      clauses.add('je.entry_date >= ?');
      args.add(from.toIso8601String());
    }
    if (through != null) {
      final endOfDay = DateTime(
        through.year, through.month, through.day, 23, 59, 59, 999,
      );
      clauses.add('je.entry_date <= ?');
      args.add(endOfDay.toIso8601String());
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT a.code AS account_code, a.name AS account_name, a.type AS account_type,
             COALESCE(SUM(jl.debit_minor), 0) AS debit_minor,
             COALESCE(SUM(jl.credit_minor), 0) AS credit_minor
      FROM accounts a
      LEFT JOIN journal_lines jl ON jl.account_id = a.id
      LEFT JOIN journal_entries je ON je.id = jl.journal_entry_id AND je.status = 'posted'
      $where
      GROUP BY a.id, a.code, a.name, a.type
      ORDER BY a.code ASC
    ''', args);
    final reportRows = rows.map((row) => TrialBalanceRow(
      accountCode: row['account_code'] as String,
      accountName: row['account_name'] as String,
      accountType: row['account_type'] as String,
      debitMinor: row['debit_minor'] as int,
      creditMinor: row['credit_minor'] as int,
    )).toList(growable: false);
    return TrialBalance(rows: reportRows);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
