class TrialBalanceRow {
  const TrialBalanceRow({
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.debitMinor,
    required this.creditMinor,
  });

  final String accountCode;
  final String accountName;
  final String accountType;
  final int debitMinor;
  final int creditMinor;
}

class TrialBalance {
  const TrialBalance({required this.rows});
  final List<TrialBalanceRow> rows;

  int get totalDebitMinor =>
      rows.fold(0, (total, row) => total + row.debitMinor);
  int get totalCreditMinor =>
      rows.fold(0, (total, row) => total + row.creditMinor);
  bool get isBalanced => totalDebitMinor == totalCreditMinor;
}
