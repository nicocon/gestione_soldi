import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/finance_service.dart';

class IncomesPage extends StatefulWidget {
  const IncomesPage({super.key});

  @override
  State<IncomesPage> createState() => _IncomesPageState();
}

class _IncomesPageState extends State<IncomesPage> {
  final FinanceService _financeService = FinanceService();

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
  );

  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy', 'it_IT');
  final DateFormat _monthFormatter = DateFormat('MMMM yyyy', 'it_IT');

  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  double _extractAmount(Map<String, dynamic> data) {
    final rawAmount = data['amount'];

    if (rawAmount is int) return rawAmount.toDouble();
    if (rawAmount is double) return rawAmount;
    if (rawAmount is num) return rawAmount.toDouble();

    return 0.0;
  }

  double _extractBalance(Map<String, dynamic> data) {
    final rawBalance = data['balance'];

    if (rawBalance is int) return rawBalance.toDouble();
    if (rawBalance is double) return rawBalance;
    if (rawBalance is num) return rawBalance.toDouble();

    return 0.0;
  }

  DateTime _extractDate(Map<String, dynamic> data) {
    final rawDate = data['date'];

    if (rawDate is Timestamp) return rawDate.toDate();

    return DateTime.now();
  }

  bool _sameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docsBySelectedMonth(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final date = _extractDate(doc.data());

      return _sameMonth(date, _selectedMonth);
    }).toList();
  }

  void _goToPreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      );
    });
  }

  void _goToNextMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
      );
    });
  }

  void _goToCurrentMonth() {
    setState(() {
      _selectedMonth = DateTime(
        DateTime.now().year,
        DateTime.now().month,
      );
    });
  }

  Future<void> _showIncomeDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> bankAccounts,
  }) async {
    await _showResponsiveSheet(
      maxDesktopWidth: 520,
      child: _IncomeFormDialog(
        financeService: _financeService,
        incomeDoc: doc,
        bankAccounts: bankAccounts,
      ),
    );
  }

  Future<void> _showBankAccountDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    await _showResponsiveSheet(
      maxDesktopWidth: 480,
      child: _BankAccountFormDialog(
        financeService: _financeService,
        bankAccountDoc: doc,
      ),
    );
  }

  Future<void> _showTransferDialog({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> bankAccounts,
  }) async {
    if (bankAccounts.length < 2) {
      _showMessage(
        'Per spostare soldi devi avere almeno due conti bancari.',
        isError: true,
      );
      return;
    }

    await _showResponsiveSheet(
      maxDesktopWidth: 520,
      child: _TransferMoneyFormDialog(
        financeService: _financeService,
        bankAccounts: bankAccounts,
      ),
    );
  }

  Future<void> _showResponsiveSheet({
    required Widget child,
    double maxDesktopWidth = 480,
  }) async {
    final colors = _IncomesColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    if (isMobile) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => child,
      );

      return;
    }

    await showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: colors.card,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxDesktopWidth),
          child: child,
        ),
      ),
    );
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    final colors = _IncomesColors.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        action: SnackBarAction(
          label: 'OK',
          textColor: colors.isDark ? const Color(0xFF0F172A) : Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _confirmDeleteIncome({
    required String incomeId,
    required String title,
  }) async {
    final colors = _IncomesColors.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Eliminare entrata?',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          content: Text(
            'Vuoi davvero eliminare "$title"? Se era collegata a un conto, il saldo verrà aggiornato.',
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Annulla',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.delete_rounded),
              label: const Text('Elimina'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _financeService.deleteIncome(incomeId: incomeId);
    }
  }

  Future<void> _confirmDeleteBankAccount({
    required String bankAccountId,
    required String name,
  }) async {
    final colors = _IncomesColors.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Eliminare conto?',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          content: Text(
            'Vuoi davvero eliminare "$name"? Le entrate già salvate resteranno visibili, ma non saranno più collegate a questo conto.',
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Annulla',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.delete_rounded),
              label: const Text('Elimina'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _financeService.deleteBankAccount(
        bankAccountId: bankAccountId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);

    return Scaffold(
      backgroundColor: colors.scaffold,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _financeService.incomesStream(),
        builder: (context, incomesSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _financeService.bankAccountsStream(),
            builder: (context, accountsSnapshot) {
              final docs = incomesSnapshot.data?.docs ?? [];
              final bankAccounts = accountsSnapshot.data?.docs ?? [];

              final monthDocs = _docsBySelectedMonth(docs);

              final totalAll = docs.fold<double>(0, (sum, doc) {
                return sum + _extractAmount(doc.data());
              });

              final totalMonth = monthDocs.fold<double>(0, (sum, doc) {
                return sum + _extractAmount(doc.data());
              });

              final totalBankBalance = bankAccounts.fold<double>(0, (sum, doc) {
                return sum + _extractBalance(doc.data());
              });

              final incomeCountMonth = monthDocs.length;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 700;

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 16 : 24,
                      isMobile ? 16 : 24,
                      isMobile ? 16 : 24,
                      isMobile ? 120 : 36,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _IncomesHeader(
                              totalAll: _currencyFormatter.format(totalAll),
                              totalMonth:
                                  _currencyFormatter.format(totalMonth),
                              totalBankBalance:
                                  _currencyFormatter.format(totalBankBalance),
                              incomeCountMonth: incomeCountMonth,
                              bankAccountsCount: bankAccounts.length,
                              onAddIncome: () => _showIncomeDialog(
                                bankAccounts: bankAccounts,
                              ),
                              onAddBankAccount: () => _showBankAccountDialog(),
                            ),
                            SizedBox(height: isMobile ? 14 : 18),
                            _BankAccountsSection(
                              bankAccounts: bankAccounts,
                              currencyFormatter: _currencyFormatter,
                              onAdd: () => _showBankAccountDialog(),
                              onTransfer: () => _showTransferDialog(
                                bankAccounts: bankAccounts,
                              ),
                              onEdit: (doc) => _showBankAccountDialog(doc: doc),
                              onDelete: (doc) {
                                final data = doc.data();
                                final name = data['name'] ?? 'Conto';

                                _confirmDeleteBankAccount(
                                  bankAccountId: doc.id,
                                  name: name.toString(),
                                );
                              },
                            ),
                            SizedBox(height: isMobile ? 14 : 18),
                            _MonthSelector(
                              selectedMonth: _selectedMonth,
                              monthFormatter: _monthFormatter,
                              onPrevious: _goToPreviousMonth,
                              onNext: _goToNextMonth,
                              onCurrentMonth: _goToCurrentMonth,
                            ),
                            SizedBox(height: isMobile ? 18 : 22),
                            if (incomesSnapshot.connectionState ==
                                    ConnectionState.waiting ||
                                accountsSnapshot.connectionState ==
                                    ConnectionState.waiting)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: CircularProgressIndicator(
                                    color: colors.primary,
                                  ),
                                ),
                              )
                            else if (monthDocs.isEmpty)
                              const _EmptyIncomes()
                            else
                              Column(
                                children: monthDocs.map((doc) {
                                  final data = doc.data();

                                  final title = data['title'] ?? 'Entrata';
                                  final amount = _extractAmount(data);
                                  final date = _extractDate(data);
                                  final bankAccountName =
                                      data['bankAccountName']?.toString();

                                  return _IncomeCard(
                                    title: title.toString(),
                                    amount: _currencyFormatter.format(amount),
                                    date: _dateFormatter.format(date),
                                    bankAccountName: bankAccountName,
                                    onEdit: () => _showIncomeDialog(
                                      doc: doc,
                                      bankAccounts: bankAccounts,
                                    ),
                                    onDelete: () => _confirmDeleteIncome(
                                      incomeId: doc.id,
                                      title: title.toString(),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _IncomesColors {
  final bool isDark;
  final Color scaffold;
  final Color card;
  final Color cardSoft;
  final Color cardSofter;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primary;
  final Color primarySoft;
  final Color success;
  final Color successSoft;
  final Color headerBackground;
  final Color headerText;
  final Color headerMuted;
  final Color shadow;

  const _IncomesColors({
    required this.isDark,
    required this.scaffold,
    required this.card,
    required this.cardSoft,
    required this.cardSofter,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.primarySoft,
    required this.success,
    required this.successSoft,
    required this.headerBackground,
    required this.headerText,
    required this.headerMuted,
    required this.shadow,
  });

  factory _IncomesColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return const _IncomesColors(
        isDark: true,
        scaffold: Color(0xFF0F172A),
        card: Color(0xFF172033),
        cardSoft: Color(0xFF111827),
        cardSofter: Color(0xFF1E293B),
        border: Color(0xFF334155),
        textPrimary: Color(0xFFF8FAFC),
        textSecondary: Color(0xFFCBD5E1),
        textMuted: Color(0xFF94A3B8),
        primary: Color(0xFF60A5FA),
        primarySoft: Color(0xFF1E3A5F),
        success: Color(0xFF22C55E),
        successSoft: Color(0xFF052E16),
        headerBackground: Color(0xFF020617),
        headerText: Colors.white,
        headerMuted: Color(0xFFCBD5E1),
        shadow: Colors.black,
      );
    }

    return const _IncomesColors(
      isDark: false,
      scaffold: Color(0xFFF5F8FC),
      card: Colors.white,
      cardSoft: Color(0xFFF7FAFE),
      cardSofter: Color(0xFFF3F6FB),
      border: Color(0xFFE5ECF5),
      textPrimary: Color(0xFF172033),
      textSecondary: Color(0xFF64748B),
      textMuted: Color(0xFF94A3B8),
      primary: Color(0xFF1677F2),
      primarySoft: Color(0xFFE3F2FD),
      success: Color(0xFF16A34A),
      successSoft: Color(0xFFEAF8EF),
      headerBackground: Color(0xFF172033),
      headerText: Colors.white,
      headerMuted: Color(0xFFD7DEE9),
      shadow: Colors.black,
    );
  }
}

BoxDecoration _incomesCardDecoration(BuildContext context) {
  final colors = _IncomesColors.of(context);

  return BoxDecoration(
    color: colors.card,
    borderRadius: BorderRadius.circular(26),
    border: Border.all(
      color: colors.border,
    ),
    boxShadow: [
      BoxShadow(
        color: colors.shadow.withValues(alpha: colors.isDark ? 0.18 : 0.035),
        blurRadius: colors.isDark ? 22 : 16,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

InputDecoration _incomesInputDecoration({
  required BuildContext context,
  required String label,
  IconData? suffixIcon,
  bool alignLabelWithHint = false,
}) {
  final colors = _IncomesColors.of(context);

  return InputDecoration(
    labelText: label,
    alignLabelWithHint: alignLabelWithHint,
    labelStyle: TextStyle(
      color: colors.textSecondary,
      fontWeight: FontWeight.w700,
    ),
    suffixIcon: suffixIcon == null
        ? null
        : Icon(
            suffixIcon,
            color: colors.textSecondary,
          ),
    filled: true,
    fillColor: colors.cardSoft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: colors.border,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: colors.border,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: colors.primary,
        width: 1.5,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: Color(0xFFDC2626),
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: Color(0xFFDC2626),
        width: 1.5,
      ),
    ),
  );
}

Future<DateTime?> _showIncomesDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) async {
  final colors = _IncomesColors.of(context);

  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: colors.isDark
              ? const ColorScheme.dark(
                  primary: Color(0xFF60A5FA),
                  onPrimary: Color(0xFF0F172A),
                  surface: Color(0xFF172033),
                  onSurface: Color(0xFFF8FAFC),
                )
              : const ColorScheme.light(
                  primary: Color(0xFF1677F2),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF172033),
                ),
        ),
        child: child!,
      );
    },
  );
}

class _IncomesHeader extends StatelessWidget {
  final String totalAll;
  final String totalMonth;
  final String totalBankBalance;
  final int incomeCountMonth;
  final int bankAccountsCount;
  final VoidCallback onAddIncome;
  final VoidCallback onAddBankAccount;

  const _IncomesHeader({
    required this.totalAll,
    required this.totalMonth,
    required this.totalBankBalance,
    required this.incomeCountMonth,
    required this.bankAccountsCount,
    required this.onAddIncome,
    required this.onAddBankAccount,
  });

  bool get _shouldShowFirstBankButton => bankAccountsCount == 0;

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 22 : 28),
      decoration: BoxDecoration(
        color: colors.headerBackground,
        borderRadius: BorderRadius.circular(isMobile ? 26 : 30),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: colors.isDark ? 0.24 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _IncomesHeaderText(isMobile: true),
                const SizedBox(height: 20),
                _HeaderStatsGrid(
                  totalMonth: totalMonth,
                  totalAll: totalAll,
                  totalBankBalance: totalBankBalance,
                  incomeCountMonth: incomeCountMonth,
                  isMobile: true,
                ),
                const SizedBox(height: 16),
                if (_shouldShowFirstBankButton)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: onAddIncome,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Entrata'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.isDark
                                  ? colors.primary
                                  : Colors.white,
                              foregroundColor: colors.isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF172033),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: onAddBankAccount,
                            icon: const Icon(Icons.account_balance_rounded),
                            label: const Text('Conto'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.success,
                              foregroundColor: colors.isDark
                                  ? const Color(0xFF052E16)
                                  : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: onAddIncome,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nuova entrata'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            colors.isDark ? colors.primary : Colors.white,
                        foregroundColor: colors.isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF172033),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : Row(
              children: [
                const Expanded(
                  child: _IncomesHeaderText(isMobile: false),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _HeaderStatsGrid(
                      totalMonth: totalMonth,
                      totalAll: totalAll,
                      totalBankBalance: totalBankBalance,
                      incomeCountMonth: incomeCountMonth,
                      isMobile: false,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: onAddIncome,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Nuova entrata'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.isDark
                                  ? colors.primary
                                  : Colors.white,
                              foregroundColor: colors.isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF172033),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        if (_shouldShowFirstBankButton)
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: onAddBankAccount,
                              icon: const Icon(Icons.account_balance_rounded),
                              label: const Text('Nuovo conto'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.success,
                                foregroundColor: colors.isDark
                                    ? const Color(0xFF052E16)
                                    : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _IncomesHeaderText extends StatelessWidget {
  final bool isMobile;

  const _IncomesHeaderText({
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestione entrate',
          style: TextStyle(
            color: colors.headerText,
            fontSize: isMobile ? 27 : 32,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Registra stipendio, bonus e rimborsi. Collega ogni entrata al conto giusto e tieni sotto controllo i soldi disponibili.',
          style: TextStyle(
            color: colors.headerMuted,
            fontSize: isMobile ? 15 : 16,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _HeaderStatsGrid extends StatelessWidget {
  final String totalMonth;
  final String totalAll;
  final String totalBankBalance;
  final int incomeCountMonth;
  final bool isMobile;

  const _HeaderStatsGrid({
    required this.totalMonth,
    required this.totalAll,
    required this.totalBankBalance,
    required this.incomeCountMonth,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _HeaderMiniStat(
        label: 'Entrate mese',
        value: totalMonth,
      ),
      _HeaderMiniStat(
        label: 'Totale banca',
        value: totalBankBalance,
      ),
      _HeaderMiniStat(
        label: 'Totale entrate',
        value: totalAll,
      ),
      _HeaderMiniStat(
        label: 'Movimenti mese',
        value: incomeCountMonth.toString(),
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: stats[0]),
              const SizedBox(width: 10),
              Expanded(child: stats[1]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: stats[2]),
              const SizedBox(width: 10),
              Expanded(child: stats[3]),
            ],
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      children: stats,
    );
  }
}

class _HeaderMiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderMiniStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: isMobile ? double.infinity : 160,
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.headerMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.headerText,
              fontSize: isMobile ? 20 : 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BankAccountsSection extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> bankAccounts;
  final NumberFormat currencyFormatter;
  final VoidCallback onAdd;
  final VoidCallback onTransfer;
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>> doc) onEdit;
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>> doc) onDelete;

  const _BankAccountsSection({
    required this.bankAccounts,
    required this.currencyFormatter,
    required this.onAdd,
    required this.onTransfer,
    required this.onEdit,
    required this.onDelete,
  });

  bool get _hasAccounts => bankAccounts.isNotEmpty;
  bool get _canTransfer => bankAccounts.length >= 2;

  double _balanceFrom(Map<String, dynamic> data) {
    final value = data['balance'];

    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 18),
      decoration: _incomesCardDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(isMobile ? 24 : 26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Conti bancari',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_hasAccounts) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: onAdd,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Aggiungi'),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.primary,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      if (_canTransfer)
                        Expanded(
                          child: TextButton.icon(
                            onPressed: onTransfer,
                            icon: const Icon(Icons.swap_horiz_rounded),
                            label: const Text('Sposta'),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.success,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            )
          else
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Conti bancari',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (_hasAccounts) ...[
                  if (_canTransfer) ...[
                    TextButton.icon(
                      onPressed: onTransfer,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Sposta soldi'),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.success,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Aggiungi'),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 12),
          if (bankAccounts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.cardSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colors.border,
                ),
              ),
              child: Text(
                'Nessun conto inserito. Aggiungi il saldo che hai già in banca usando il pulsante verde in alto, ad esempio “Conto principale”, “Revolut”, “Postepay”, ecc.',
                style: TextStyle(
                  color: colors.textSecondary,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: bankAccounts.map((doc) {
                final data = doc.data();
                final name = data['name'] ?? 'Conto';
                final balance = _balanceFrom(data);

                return _BankAccountCard(
                  name: name.toString(),
                  balance: currencyFormatter.format(balance),
                  onEdit: () => onEdit(doc),
                  onDelete: () => onDelete(doc),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _BankAccountCard extends StatelessWidget {
  final String name;
  final String balance;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BankAccountCard({
    required this.name,
    required this.balance,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: isMobile ? double.infinity : 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.account_balance_rounded,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  balance,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.success,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: colors.card,
            iconColor: colors.textSecondary,
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(
                  'Modifica',
                  style: TextStyle(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Elimina',
                  style: TextStyle(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final DateFormat monthFormatter;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCurrentMonth;

  const _MonthSelector({
    required this.selectedMonth,
    required this.monthFormatter,
    required this.onPrevious,
    required this.onNext,
    required this.onCurrentMonth,
  });

  bool get _isCurrentMonth {
    final now = DateTime.now();

    return selectedMonth.year == now.year && selectedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    final label = monthFormatter.format(selectedMonth);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: _incomesCardDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(isMobile ? 24 : 26),
      ),
      child: isMobile
          ? Column(
              children: [
                Row(
                  children: [
                    _MonthArrowButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: onPrevious,
                    ),
                    Expanded(
                      child: Text(
                        label.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _MonthArrowButton(
                      icon: Icons.chevron_right_rounded,
                      onTap: onNext,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: _isCurrentMonth ? null : onCurrentMonth,
                    icon: const Icon(Icons.today_rounded),
                    label: const Text('Torna al mese attuale'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      disabledForegroundColor: colors.textMuted,
                      side: BorderSide(
                        color: colors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                _MonthArrowButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: onPrevious,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _MonthArrowButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: onNext,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _isCurrentMonth ? null : onCurrentMonth,
                    icon: const Icon(Icons.today_rounded),
                    label: const Text('Mese attuale'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      disabledForegroundColor: colors.textMuted,
                      side: BorderSide(
                        color: colors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MonthArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthArrowButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);

    return Material(
      color: colors.successSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: colors.success,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _IncomeCard extends StatelessWidget {
  final String title;
  final String amount;
  final String date;
  final String? bankAccountName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _IncomeCard({
    required this.title,
    required this.amount,
    required this.date,
    required this.bankAccountName,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.all(isMobile ? 16 : 18),
      decoration: _incomesCardDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(24),
      ),
      child: isMobile ? _mobileLayout(context) : _desktopLayout(context),
    );
  }

  Widget _mobileLayout(BuildContext context) {
    final colors = _IncomesColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _IncomeIcon(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: colors.success,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              color: colors.card,
              iconColor: colors.textSecondary,
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text(
                    'Modifica',
                    style: TextStyle(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Elimina',
                    style: TextStyle(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoBadge(
              text: date,
              icon: Icons.calendar_month_rounded,
            ),
            _InfoBadge(
              text: bankAccountName == null || bankAccountName!.isEmpty
                  ? 'Nessun conto'
                  : bankAccountName!,
              icon: Icons.account_balance_rounded,
            ),
            const _ColoredBadge(
              text: 'Entrata',
              color: Color(0xFF16A34A),
            ),
          ],
        ),
      ],
    );
  }

  Widget _desktopLayout(BuildContext context) {
    final colors = _IncomesColors.of(context);

    return Row(
      children: [
        const _IncomeIcon(),
        const SizedBox(width: 16),
        Expanded(
          child: Wrap(
            runSpacing: 8,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoBadge(
                    text: date,
                    icon: Icons.calendar_month_rounded,
                  ),
                  _InfoBadge(
                    text: bankAccountName == null || bankAccountName!.isEmpty
                        ? 'Nessun conto'
                        : bankAccountName!,
                    icon: Icons.account_balance_rounded,
                  ),
                  const _ColoredBadge(
                    text: 'Entrata',
                    color: Color(0xFF16A34A),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            IconButton(
              tooltip: 'Modifica',
              onPressed: onEdit,
              color: colors.textSecondary,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Elimina',
              onPressed: onDelete,
              color: colors.textSecondary,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _IncomeIcon extends StatelessWidget {
  const _IncomeIcon();

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: colors.successSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        Icons.trending_up_rounded,
        color: colors.success,
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String text;
  final IconData icon;

  const _InfoBadge({
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: colors.cardSofter,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colors.isDark ? colors.border : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColoredBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _ColoredBadge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: colors.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyIncomes extends StatelessWidget {
  const _EmptyIncomes();

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(34),
      decoration: _incomesCardDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.trending_up_rounded,
            size: 44,
            color: colors.textMuted,
          ),
          const SizedBox(height: 14),
          Text(
            'Nessuna entrata trovata',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aggiungi stipendio, bonus, rimborsi o altre entrate per questo mese.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeFormDialog extends StatefulWidget {
  final FinanceService financeService;
  final QueryDocumentSnapshot<Map<String, dynamic>>? incomeDoc;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> bankAccounts;

  const _IncomeFormDialog({
    required this.financeService,
    required this.bankAccounts,
    this.incomeDoc,
  });

  @override
  State<_IncomeFormDialog> createState() => _IncomeFormDialogState();
}

class _IncomeFormDialogState extends State<_IncomeFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late DateTime _selectedDate;

  String? _selectedBankAccountId;
  bool _loading = false;

  bool get _isEditMode => widget.incomeDoc != null;

  @override
  void initState() {
    super.initState();

    final data = widget.incomeDoc?.data();

    final title = data?['title'] ?? '';

    final rawAmount = data?['amount'];
    final amount = rawAmount is int
        ? rawAmount.toDouble()
        : rawAmount is double
            ? rawAmount
            : rawAmount is num
                ? rawAmount.toDouble()
                : 0.0;

    final rawDate = data?['date'];
    final date = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();

    _selectedBankAccountId = data?['bankAccountId']?.toString();

    final existsSelectedAccount = widget.bankAccounts.any(
      (doc) => doc.id == _selectedBankAccountId,
    );

    if (!existsSelectedAccount) {
      _selectedBankAccountId = null;
    }

    _titleController = TextEditingController(text: title.toString());

    _amountController = TextEditingController(
      text: _isEditMode ? amount.toStringAsFixed(2).replaceAll('.', ',') : '',
    );

    _selectedDate = date;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String? _selectedBankAccountName() {
    if (_selectedBankAccountId == null) return null;

    for (final doc in widget.bankAccounts) {
      if (doc.id == _selectedBankAccountId) {
        final data = doc.data();
        return data['name']?.toString();
      }
    }

    return null;
  }

  Future<void> _pickDate() async {
    final picked = await _showIncomesDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final amount = double.parse(
        _amountController.text.replaceAll(',', '.'),
      );

      final bankAccountName = _selectedBankAccountName();

      if (_isEditMode) {
        await widget.financeService.updateIncome(
          incomeId: widget.incomeDoc!.id,
          title: _titleController.text.trim(),
          amount: amount,
          date: _selectedDate,
          bankAccountId: _selectedBankAccountId,
          bankAccountName: bankAccountName,
        );
      } else {
        await widget.financeService.addIncome(
          title: _titleController.text.trim(),
          amount: amount,
          date: _selectedDate,
          bankAccountId: _selectedBankAccountId,
          bankAccountName: bankAccountName,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditMode ? 'Modifica entrata' : 'Nuova entrata';

    return _BaseFormSheet(
      title: title,
      loading: _loading,
      saveLabel: _isEditMode ? 'Aggiorna' : 'Salva',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextInput(
              controller: _titleController,
              label: 'Titolo',
              validatorText: 'Inserisci il titolo',
            ),
            const SizedBox(height: 12),
            _TextInput(
              controller: _amountController,
              label: 'Importo',
              validatorText: 'Inserisci l’importo',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            _BankAccountDropdown(
              bankAccounts: widget.bankAccounts,
              selectedBankAccountId: _selectedBankAccountId,
              onChanged: (value) {
                setState(() {
                  _selectedBankAccountId = value;
                });
              },
            ),
            const SizedBox(height: 12),
            _DateButton(
              label: 'Data entrata',
              date: _selectedDate,
              onTap: _pickDate,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferMoneyFormDialog extends StatefulWidget {
  final FinanceService financeService;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> bankAccounts;

  const _TransferMoneyFormDialog({
    required this.financeService,
    required this.bankAccounts,
  });

  @override
  State<_TransferMoneyFormDialog> createState() =>
      _TransferMoneyFormDialogState();
}

class _TransferMoneyFormDialogState extends State<_TransferMoneyFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  String? _fromBankAccountId;
  String? _toBankAccountId;
  DateTime _selectedDate = DateTime.now();

  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController();
    _noteController = TextEditingController();

    if (widget.bankAccounts.isNotEmpty) {
      _fromBankAccountId = widget.bankAccounts.first.id;
    }

    if (widget.bankAccounts.length > 1) {
      _toBankAccountId = widget.bankAccounts[1].id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double _balanceFrom(Map<String, dynamic> data) {
    final value = data['balance'];

    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0.0;
  }

  String _accountName(String? id) {
    if (id == null) return '';

    for (final doc in widget.bankAccounts) {
      if (doc.id == id) {
        final data = doc.data();
        return data['name']?.toString() ?? 'Conto';
      }
    }

    return '';
  }

  double _accountBalance(String? id) {
    if (id == null) return 0.0;

    for (final doc in widget.bankAccounts) {
      if (doc.id == id) {
        return _balanceFrom(doc.data());
      }
    }

    return 0.0;
  }

  Future<void> _pickDate() async {
    final picked = await _showIncomesDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromBankAccountId == null || _toBankAccountId == null) {
      _showError('Seleziona entrambi i conti.');
      return;
    }

    if (_fromBankAccountId == _toBankAccountId) {
      _showError(
        'Il conto di partenza e quello di destinazione devono essere diversi.',
      );
      return;
    }

    final amount = double.parse(
      _amountController.text.replaceAll(',', '.'),
    );

    final fromBalance = _accountBalance(_fromBankAccountId);

    if (amount > fromBalance) {
      _showError(
        'Saldo insufficiente sul conto "${_accountName(_fromBankAccountId)}".',
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await widget.financeService.transferMoneyBetweenBankAccounts(
        fromBankAccountId: _fromBankAccountId!,
        toBankAccountId: _toBankAccountId!,
        amount: amount,
        date: _selectedDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
    );

    final fromBalance = _accountBalance(_fromBankAccountId);
    final toBalance = _accountBalance(_toBankAccountId);

    return _BaseFormSheet(
      title: 'Sposta soldi',
      loading: _loading,
      saveLabel: 'Sposta',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TransferInfoBox(
              fromAccountName: _accountName(_fromBankAccountId),
              fromBalance: formatter.format(fromBalance),
              toAccountName: _accountName(_toBankAccountId),
              toBalance: formatter.format(toBalance),
            ),
            const SizedBox(height: 14),
            _TransferAccountDropdown(
              label: 'Da quale conto',
              bankAccounts: widget.bankAccounts,
              selectedBankAccountId: _fromBankAccountId,
              onChanged: (value) {
                setState(() {
                  _fromBankAccountId = value;

                  if (_fromBankAccountId == _toBankAccountId) {
                    _toBankAccountId = widget.bankAccounts
                        .where((doc) => doc.id != _fromBankAccountId)
                        .map((doc) => doc.id)
                        .firstOrNull;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            _TransferAccountDropdown(
              label: 'Verso quale conto',
              bankAccounts: widget.bankAccounts,
              selectedBankAccountId: _toBankAccountId,
              disabledBankAccountId: _fromBankAccountId,
              onChanged: (value) {
                setState(() {
                  _toBankAccountId = value;
                });
              },
            ),
            const SizedBox(height: 12),
            _TextInput(
              controller: _amountController,
              label: 'Importo da spostare',
              validatorText: 'Inserisci l’importo',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            _DateButton(
              label: 'Data trasferimento',
              date: _selectedDate,
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            _OptionalTextInput(
              controller: _noteController,
              label: 'Nota opzionale',
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferInfoBox extends StatelessWidget {
  final String fromAccountName;
  final String fromBalance;
  final String toAccountName;
  final String toBalance;

  const _TransferInfoBox({
    required this.fromAccountName,
    required this.fromBalance,
    required this.toAccountName,
    required this.toBalance,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TransferInfoAccount(
              label: 'Partenza',
              name:
                  fromAccountName.isEmpty ? 'Seleziona conto' : fromAccountName,
              balance: fromBalance,
              color: const Color(0xFFDC2626),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              color: colors.primary,
            ),
          ),
          Expanded(
            child: _TransferInfoAccount(
              label: 'Arrivo',
              name: toAccountName.isEmpty ? 'Seleziona conto' : toAccountName,
              balance: toBalance,
              color: colors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferInfoAccount extends StatelessWidget {
  final String label;
  final String name;
  final String balance;
  final Color color;

  const _TransferInfoAccount({
    required this.label,
    required this.name,
    required this.balance,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          balance,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _TransferAccountDropdown extends StatelessWidget {
  final String label;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> bankAccounts;
  final String? selectedBankAccountId;
  final String? disabledBankAccountId;
  final ValueChanged<String?> onChanged;

  const _TransferAccountDropdown({
    required this.label,
    required this.bankAccounts,
    required this.selectedBankAccountId,
    required this.onChanged,
    this.disabledBankAccountId,
  });

  double _balanceFrom(Map<String, dynamic> data) {
    final value = data['balance'];

    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);
    final formatter = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
    );

    return DropdownButtonFormField<String>(
      value: selectedBankAccountId,
      dropdownColor: colors.card,
      style: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: _incomesInputDecoration(
        context: context,
        label: label,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Seleziona un conto';
        }

        return null;
      },
      items: bankAccounts.map((doc) {
        final data = doc.data();
        final name = data['name'] ?? 'Conto';
        final balance = _balanceFrom(data);
        final disabled = doc.id == disabledBankAccountId;

        return DropdownMenuItem<String>(
          value: doc.id,
          enabled: !disabled,
          child: Text(
            disabled
                ? '${name.toString()} · già selezionato'
                : '${name.toString()} · ${formatter.format(balance)}',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: disabled ? colors.textMuted : colors.textPrimary,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _BankAccountFormDialog extends StatefulWidget {
  final FinanceService financeService;
  final QueryDocumentSnapshot<Map<String, dynamic>>? bankAccountDoc;

  const _BankAccountFormDialog({
    required this.financeService,
    this.bankAccountDoc,
  });

  @override
  State<_BankAccountFormDialog> createState() => _BankAccountFormDialogState();
}

class _BankAccountFormDialogState extends State<_BankAccountFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;

  bool _loading = false;

  bool get _isEditMode => widget.bankAccountDoc != null;

  @override
  void initState() {
    super.initState();

    final data = widget.bankAccountDoc?.data();

    final name = data?['name'] ?? '';

    final rawBalance = data?['balance'];
    final balance = rawBalance is int
        ? rawBalance.toDouble()
        : rawBalance is double
            ? rawBalance
            : rawBalance is num
                ? rawBalance.toDouble()
                : 0.0;

    _nameController = TextEditingController(text: name.toString());

    _balanceController = TextEditingController(
      text: _isEditMode ? balance.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final balance = double.parse(
        _balanceController.text.replaceAll(',', '.'),
      );

      if (_isEditMode) {
        await widget.financeService.updateBankAccount(
          bankAccountId: widget.bankAccountDoc!.id,
          name: _nameController.text.trim(),
          balance: balance,
        );
      } else {
        await widget.financeService.addBankAccount(
          name: _nameController.text.trim(),
          balance: balance,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditMode ? 'Modifica conto' : 'Nuovo conto';

    return _BaseFormSheet(
      title: title,
      loading: _loading,
      saveLabel: _isEditMode ? 'Aggiorna' : 'Salva',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextInput(
              controller: _nameController,
              label: 'Nome conto',
              validatorText: 'Inserisci il nome del conto',
            ),
            const SizedBox(height: 12),
            _TextInput(
              controller: _balanceController,
              label: 'Saldo disponibile',
              validatorText: 'Inserisci il saldo',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              allowZero: true,
              allowNegative: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _BankAccountDropdown extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> bankAccounts;
  final String? selectedBankAccountId;
  final ValueChanged<String?> onChanged;

  const _BankAccountDropdown({
    required this.bankAccounts,
    required this.selectedBankAccountId,
    required this.onChanged,
  });

  double _balanceFrom(Map<String, dynamic> data) {
    final value = data['balance'];

    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);
    final formatter = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
    );

    return DropdownButtonFormField<String?>(
      value: selectedBankAccountId,
      dropdownColor: colors.card,
      style: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: _incomesInputDecoration(
        context: context,
        label: 'Conto bancario',
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(
            'Non collegare a nessun conto',
            style: TextStyle(
              color: colors.textPrimary,
            ),
          ),
        ),
        ...bankAccounts.map((doc) {
          final data = doc.data();
          final name = data['name'] ?? 'Conto';
          final balance = _balanceFrom(data);

          return DropdownMenuItem<String?>(
            value: doc.id,
            child: Text(
              '${name.toString()} · ${formatter.format(balance)}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
              ),
            ),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }
}

class _BaseFormSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final bool loading;
  final String saveLabel;
  final Future<void> Function() onSave;

  const _BaseFormSheet({
    required this.title,
    required this.child,
    required this.loading,
    required this.saveLabel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: isMobile ? bottomInset : 0),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          isMobile ? 20 : 24,
          12,
          isMobile ? 20 : 24,
          isMobile ? 20 : 24,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(isMobile ? 28 : 24),
            bottom: Radius.circular(isMobile ? 0 : 24),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMobile) ...[
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: loading ? null : () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                child,
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed:
                              loading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            side: BorderSide(
                              color: colors.border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: const Text('Annulla'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: loading ? null : onSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.isDark
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          child: loading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.isDark
                                        ? const Color(0xFF0F172A)
                                        : Colors.white,
                                  ),
                                )
                              : Text(saveLabel),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String validatorText;
  final TextInputType? keyboardType;
  final bool allowZero;
  final bool allowNegative;

  const _TextInput({
    required this.controller,
    required this.label,
    required this.validatorText,
    this.keyboardType,
    this.allowZero = false,
    this.allowNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: _incomesInputDecoration(
        context: context,
        label: label,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return validatorText;
        }

        final isNumberKeyboard =
            keyboardType == TextInputType.number ||
            keyboardType ==
                const TextInputType.numberWithOptions(decimal: true) ||
            keyboardType ==
                const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                );

        if (isNumberKeyboard) {
          final parsed = double.tryParse(value.replaceAll(',', '.'));

          if (parsed == null) {
            return 'Inserisci un numero valido';
          }

          if (!allowNegative && parsed < 0) {
            return 'Inserisci un importo non negativo';
          }

          if (!allowZero && parsed <= 0) {
            return 'Inserisci un importo maggiore di zero';
          }
        }

        return null;
      },
    );
  }
}

class _OptionalTextInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _OptionalTextInput({
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);

    return TextFormField(
      controller: controller,
      minLines: 2,
      maxLines: 4,
      style: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: _incomesInputDecoration(
        context: context,
        label: label,
        alignLabelWithHint: true,
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _IncomesColors.of(context);
    final formattedDate = DateFormat('dd/MM/yyyy', 'it_IT').format(date);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: _incomesInputDecoration(
          context: context,
          label: label,
          suffixIcon: Icons.calendar_month_rounded,
        ),
        child: Text(
          formattedDate,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}