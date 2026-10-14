import 'package:flutter_test/flutter_test.dart';
import 'package:al_muhasib_pro/models/journal_entry.dart';

void main() {
  group('JournalEntry', () {
    final date = DateTime(2026, 1, 1);

    test('accepts a balanced journal entry', () {
      final entry = JournalEntry(
        reference: 'JV-001',
        description: 'إثبات مبيعات نقدية',
        date: date,
        lines: const [
          JournalLine(accountCode: '1010', accountName: 'الصندوق', debitMinor: 25000, creditMinor: 0),
          JournalLine(accountCode: '4010', accountName: 'المبيعات', debitMinor: 0, creditMinor: 25000),
        ],
      );
      expect(entry.isBalanced, isTrue);
      expect(entry.totalDebitMinor, 25000);
      expect(entry.totalCreditMinor, 25000);
      expect(() => entry.validateForPosting(), returnsNormally);
    });

    test('rejects unbalanced entry', () {
      final entry = JournalEntry(
        reference: 'JV-002',
        description: 'قيد غير متوازن',
        date: date,
        lines: const [
          JournalLine(accountCode: '1010', accountName: 'الصندوق', debitMinor: 25000, creditMinor: 0),
          JournalLine(accountCode: '4010', accountName: 'المبيعات', debitMinor: 0, creditMinor: 24000),
        ],
      );
      expect(entry.isBalanced, isFalse);
      expect(entry.validateForPosting, throwsStateError);
    });

    test('rejects a line with both debit and credit', () {
      final entry = JournalEntry(
        reference: 'JV-003',
        description: 'سطر غير صحيح',
        date: date,
        lines: const [
          JournalLine(accountCode: '1010', accountName: 'الصندوق', debitMinor: 100, creditMinor: 50),
          JournalLine(accountCode: '4010', accountName: 'المبيعات', debitMinor: 0, creditMinor: 50),
        ],
      );
      expect(entry.isBalanced, isFalse);
    });
  });
}
