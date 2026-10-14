import 'package:flutter_test/flutter_test.dart';
import 'package:al_muhasib_pro/models/trial_balance.dart';

void main() {
  group('TrialBalance', () {
    test('checks equality of total debit and credit', () {
      const report = TrialBalance(rows: [
        TrialBalanceRow(
          accountCode: '1010',
          accountName: 'الصندوق',
          accountType: 'asset',
          debitMinor: 15000,
          creditMinor: 0,
        ),
        TrialBalanceRow(
          accountCode: '4010',
          accountName: 'المبيعات',
          accountType: 'income',
          debitMinor: 0,
          creditMinor: 15000,
        ),
      ]);
      expect(report.totalDebitMinor, 15000);
      expect(report.totalCreditMinor, 15000);
      expect(report.isBalanced, isTrue);
    });

    test('detects an unbalanced trial balance', () {
      const report = TrialBalance(rows: [
        TrialBalanceRow(
          accountCode: '1010',
          accountName: 'الصندوق',
          accountType: 'asset',
          debitMinor: 15000,
          creditMinor: 0,
        ),
        TrialBalanceRow(
          accountCode: '4010',
          accountName: 'المبيعات',
          accountType: 'income',
          debitMinor: 0,
          creditMinor: 12000,
        ),
      ]);
      expect(report.isBalanced, isFalse);
    });
  });
}
