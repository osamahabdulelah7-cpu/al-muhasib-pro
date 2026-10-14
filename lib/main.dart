import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'data/accounting_database.dart';
import 'models/account.dart';
import 'models/financial_entry.dart';
import 'models/trial_balance.dart';
import 'services/accounting_summary.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlMuhasibApp());
}

class AlMuhasibApp extends StatelessWidget {
  const AlMuhasibApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'المحاسب الشامل',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B58)),
          scaffoldBackgroundColor: const Color(0xFFF5F7F6),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF5F7F6),
            surfaceTintColor: Colors.transparent,
          ),
        ),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: AccountingHome(),
        ),
      );
}

class AccountingHome extends StatefulWidget {
  const AccountingHome({super.key});

  @override
  State<AccountingHome> createState() => _AccountingHomeState();
}

class _AccountingHomeState extends State<AccountingHome> {
  final _database = AccountingDatabase.instance;
  List<FinancialEntry> _entries = const [];
  bool _loading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final entries = await _database.getEntries();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل البيانات: $error')),
      );
    }
  }

  String _money(int minor) =>
      '${NumberFormat('#,##0.00', 'en').format(minor / 100)} ر.ي';

  Future<void> _addEntry() async {
    final entry = await showModalBottomSheet<FinancialEntry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddEntrySheet(),
    );
    if (entry == null) return;
    try {
      await _database.addEntry(entry);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الحركة على هذا الجهاز')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لم يتم حفظ الحركة: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = AccountingSummary.fromEntries(_entries);
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المحاسب الشامل',
                style: TextStyle(fontWeight: FontWeight.w800)),
            Text('إدارة مالية أوضح وأبسط',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _tab,
              children: [
                _dashboard(summary),
                _entriesPage(),
                _reportsPage(summary),
                _settingsPage(),
              ],
            ),
      floatingActionButton: _tab < 2
          ? FloatingActionButton.extended(
              onPressed: _addEntry,
              icon: const Icon(Icons.add_rounded),
              label: const Text('حركة جديدة'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'الحركات',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'التقارير',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }

  Widget _dashboard(AccountingSummary summary) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF145B4B), Color(0xFF21866B)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('صافي الحركات المسجلة',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                Text(
                  _money(summary.netMinor),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                const Row(children: [
                  Icon(Icons.lock_outline, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text('تُحفظ البيانات محليًا على الجهاز',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _summaryCard('الإيرادات', summary.incomeMinor,
                Icons.south_west_rounded, const Color(0xFF18845F))),
            const SizedBox(width: 12),
            Expanded(child: _summaryCard('المصروفات', summary.expenseMinor,
                Icons.north_east_rounded, const Color(0xFFC15B4A))),
          ]),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('أحدث الحركات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              TextButton(
                onPressed: () => setState(() => _tab = 1),
                child: const Text('عرض الكل'),
              ),
            ],
          ),
          if (_entries.isEmpty)
            const _EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'ابدأ بتسجيل أول حركة',
              subtitle: 'أضف إيرادًا أو مصروفًا لتظهر ملخصاتك هنا.',
            )
          else
            ..._entries.take(5).map(_entryTile),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, int amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(_money(amount),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _entriesPage() {
    if (_entries.isEmpty) {
      return const _EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'لا توجد حركات بعد',
        subtitle: 'استخدم زر «حركة جديدة» لتسجيل أول إيراد أو مصروف.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: _entries.map(_entryTile).toList(),
    );
  }

  Widget _entryTile(FinancialEntry entry) {
    final isIncome = entry.type == EntryType.income;
    final color = isIncome ? const Color(0xFF18845F) : const Color(0xFFC15B4A);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(
            isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                DateFormat('yyyy/MM/dd – HH:mm').format(entry.createdAt),
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${isIncome ? '+' : '−'}${_money(entry.amountMinor)}',
            textAlign: TextAlign.end,
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
        ),
      ]),
    );
  }

  Widget _reportsPage(AccountingSummary summary) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('ملخص مالي',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'ملخص الحركات اليومية مستقل عن ميزان المراجعة، الذي يُحتسب من القيود المزدوجة المرحلة.',
          ),
          const SizedBox(height: 18),
          _reportRow('إجمالي الإيرادات المسجلة', _money(summary.incomeMinor),
              const Color(0xFF18845F)),
          _reportRow('إجمالي المصروفات المسجلة', _money(summary.expenseMinor),
              const Color(0xFFC15B4A)),
          _reportRow('صافي الحركات المسجلة', _money(summary.netMinor),
              Theme.of(context).colorScheme.primary),
          _reportRow('عدد الحركات', _entries.length.toString(), Colors.blueGrey),
          const SizedBox(height: 20),
          const Text('ميزان المراجعة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('يعرض القيود المزدوجة المرحلة فقط. الحركات اليومية البسيطة لا تدخل في هذا الميزان.'),
          const SizedBox(height: 12),
          FutureBuilder<TrialBalance>(
            future: _database.getTrialBalance(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ));
              }
              if (snapshot.hasError) {
                return Text('تعذر إنشاء ميزان المراجعة: ${snapshot.error}');
              }
              final report = snapshot.data;
              if (report == null) return const Text('لا توجد بيانات تقرير.');
              return Column(
                children: [
                  _reportRow('إجمالي المدين', _money(report.totalDebitMinor),
                      Theme.of(context).colorScheme.primary),
                  _reportRow('إجمالي الدائن', _money(report.totalCreditMinor),
                      Theme.of(context).colorScheme.primary),
                  _reportRow('حالة التوازن',
                      report.isBalanced ? 'متوازن' : 'غير متوازن',
                      report.isBalanced ? const Color(0xFF18845F) : const Color(0xFFC15B4A)),
                  if (report.rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('لا توجد حسابات لعرضها.'),
                    ),
                  ...report.rows.map((row) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row.accountName,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(row.accountCode,
                                style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(_money(row.debitMinor),
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 11)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(_money(row.creditMinor),
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ]),
                  )),
                ],
              );
            },
          ),
        ],
      );

  Widget _reportRow(String title, String value, Color color) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ]),
      );

  Widget _settingsPage() => FutureBuilder<List<Account>>(
        future: _database.getAccounts(),
        builder: (context, snapshot) {
          final accounts = snapshot.data ?? const <Account>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('الإعدادات',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const ListTile(
                leading: Icon(Icons.storage_outlined),
                title: Text('التخزين المحلي'),
                subtitle: Text('الحركات محفوظة في قاعدة بيانات على الجهاز.'),
              ),
              const Divider(),
              const Text('دليل الحسابات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(),
              if (snapshot.hasError)
                Text('تعذر تحميل دليل الحسابات: ${snapshot.error}'),
              if (accounts.isEmpty && !snapshot.hasError &&
                  snapshot.connectionState != ConnectionState.waiting)
                const Text('لا توجد حسابات بعد.'),
              ...accounts.map((account) => ListTile(
                    dense: true,
                    leading: Icon(
                      account.parentId == null
                          ? Icons.account_tree_outlined
                          : Icons.subdirectory_arrow_left,
                    ),
                    title: Text(account.name),
                    subtitle: Text('رمز الحساب: ${account.code} • ${account.type.name}'),
                    trailing: Icon(
                      account.isActive ? Icons.check_circle_outline : Icons.pause_circle_outline,
                      size: 19,
                    ),
                  )),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.backup_outlined),
                title: Text('النسخ الاحتياطي والاستعادة'),
                subtitle: Text('سيُفعّل بعد إضافة التصدير والتحقق من سلامة النسخة.'),
              ),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.verified_user_outlined),
                title: Text('حماية البيانات'),
                subtitle: Text('لا توجد مزامنة سحابية مفعلة في هذه النسخة.'),
              ),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('الإصدار'),
                subtitle: Text('Al-Muhasib Pro 0.1.0 — نسخة تأسيسية'),
              ),
            ],
          );
        },
      );
}

class _AddEntrySheet extends StatefulWidget {
  const _AddEntrySheet();

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  EntryType _type = EntryType.income;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final amountMinor = (double.parse(_amount.text.trim()) * 100).round();
    Navigator.of(context).pop(FinancialEntry(
      title: _title.text.trim(),
      amountMinor: amountMinor,
      type: _type,
      createdAt: DateTime.now(),
      note: _note.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('تسجيل حركة جديدة',
                    style:
                        TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                SegmentedButton<EntryType>(
                  segments: const [
                    ButtonSegment(
                        value: EntryType.income,
                        label: Text('إيراد'),
                        icon: Icon(Icons.south_west_rounded)),
                    ButtonSegment(
                        value: EntryType.expense,
                        label: Text('مصروف'),
                        icon: Icon(Icons.north_east_rounded)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (selection) =>
                      setState(() => _type = selection.first),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                      labelText: 'البيان *', hintText: 'مثال: مبيعات نقدية'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'أدخل بيان الحركة'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'المبلغ *', suffixText: 'ر.ي'),
                  validator: (value) {
                    final amount = double.tryParse((value ?? '').trim());
                    if (amount == null ||
                        !amount.isFinite ||
                        amount <= 0 ||
                        amount > 90000000000000) {
                      return 'أدخل مبلغًا صحيحًا أكبر من صفر';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('حفظ الحركة')),
                ),
              ],
            ),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 56,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: .65)),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      );
}
