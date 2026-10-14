import '../models/financial_entry.dart';

class AccountingSummary {
  const AccountingSummary({required this.incomeMinor, required this.expenseMinor});
  final int incomeMinor;
  final int expenseMinor;
  int get netMinor => incomeMinor - expenseMinor;

  factory AccountingSummary.fromEntries(Iterable<FinancialEntry> entries) {
    var income = 0;
    var expense = 0;
    for (final entry in entries) {
      if (entry.type == EntryType.income) {
        income += entry.amountMinor;
      } else {
        expense += entry.amountMinor;
      }
    }
    return AccountingSummary(incomeMinor: income, expenseMinor: expense);
  }
}
