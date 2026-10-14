class JournalLine {
  const JournalLine({
    required this.accountCode,
    required this.accountName,
    required this.debitMinor,
    required this.creditMinor,
  });

  final String accountCode;
  final String accountName;
  final int debitMinor;
  final int creditMinor;

  bool get isValid =>
      accountCode.trim().isNotEmpty &&
      accountName.trim().isNotEmpty &&
      debitMinor >= 0 &&
      creditMinor >= 0 &&
      ((debitMinor > 0 && creditMinor == 0) ||
          (creditMinor > 0 && debitMinor == 0));
}

class JournalEntry {
  const JournalEntry({
    required this.reference,
    required this.description,
    required this.date,
    required this.lines,
  });

  final String reference;
  final String description;
  final DateTime date;
  final List<JournalLine> lines;

  int get totalDebitMinor =>
      lines.fold(0, (total, line) => total + line.debitMinor);
  int get totalCreditMinor =>
      lines.fold(0, (total, line) => total + line.creditMinor);
  bool get isBalanced =>
      lines.length >= 2 &&
      lines.every((line) => line.isValid) &&
      totalDebitMinor > 0 &&
      totalDebitMinor == totalCreditMinor;

  void validateForPosting() {
    if (reference.trim().isEmpty) {
      throw ArgumentError('رقم القيد مطلوب');
    }
    if (description.trim().isEmpty) {
      throw ArgumentError('بيان القيد مطلوب');
    }
    if (!isBalanced) {
      throw StateError('لا يمكن ترحيل قيد غير متوازن أو يحتوي على سطور غير صحيحة');
    }
  }
}
