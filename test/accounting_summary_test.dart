import 'package:flutter_test/flutter_test.dart';
import 'package:al_muhasib_pro/models/financial_entry.dart';
import 'package:al_muhasib_pro/services/accounting_summary.dart';

void main() {
  group('AccountingSummary', () {
    test('totals income and expenses and computes net', () {
      final entries = [
        FinancialEntry(title: 'مبيعات', amountMinor: 12500, type: EntryType.income, createdAt: DateTime(2026, 1, 1)),
        FinancialEntry(title: 'مصاريف', amountMinor: 3500, type: EntryType.expense, createdAt: DateTime(2026, 1, 2)),
        FinancialEntry(title: 'إيراد آخر', amountMinor: 2000, type: EntryType.income, createdAt: DateTime(2026, 1, 3)),
      ];
      final summary = AccountingSummary.fromEntries(entries);
      expect(summary.incomeMinor, 14500);
      expect(summary.expenseMinor, 3500);
      expect(summary.netMinor, 11000);
    });
    test('empty list produces zero totals', () {
      final summary = AccountingSummary.fromEntries(const []);
      expect(summary.incomeMinor, 0);
      expect(summary.expenseMinor, 0);
      expect(summary.netMinor, 0);
    });
    test('expenses can exceed income', () {
      final entries = [FinancialEntry(title: 'مصاريف', amountMinor: 800, type: EntryType.expense, createdAt: DateTime(2026, 1, 1))];
      expect(AccountingSummary.fromEntries(entries).netMinor, -800);
    });
  });
}
