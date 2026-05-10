import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/finance_service.dart';

enum ExpenseFilter {
  all,
  unpaid,
  paid,
  planned,
}

enum ExpenseType {
  standard,
  planned,
}

class _ExpenseBankAccountItem {
  final String id;
  final String name;
  final double balance;

  const _ExpenseBankAccountItem({
    required this.id,
    required this.name,
    required this.balance,
  });
}

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final FinanceService _financeService = FinanceService();

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
  );

  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy', 'it_IT');
  final DateFormat _monthFormatter = DateFormat('MMMM yyyy', 'it_IT');

  ExpenseFilter _selectedFilter = ExpenseFilter.all;

  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  double _amountFrom(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0;
  }

  bool _isPlannedExpense(Map<String, dynamic> data) {
    return data['type'] == 'planned';
  }

  List<Map<String, dynamic>> _splitItemsFrom(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return [];
  }

  List<_ExpenseBankAccountItem> _bankAccountsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    if (snapshot == null) return [];

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return _ExpenseBankAccountItem(
        id: doc.id,
        name: (data['name'] ?? 'Conto').toString(),
        balance: _amountFrom(data['balance']),
      );
    }).toList();
  }

  double _spentFromSplitItems(List<Map<String, dynamic>> items) {
    return items.fold<double>(0, (sum, item) {
      return sum + _amountFrom(item['amount']);
    });
  }

  double _remainingBudget({
    required double amount,
    required double spent,
  }) {
    final remaining = amount - spent;

    if (remaining <= 0) return 0;

    return remaining;
  }

  bool _isPastMonth(DateTime month) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final normalizedMonth = DateTime(month.year, month.month);

    return normalizedMonth.isBefore(currentMonth);
  }

  bool _isStandardPaid(Map<String, dynamic> data) {
    if (_isPlannedExpense(data)) return false;

    return data['is_paid'] == true;
  }

  bool _sameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  DateTime _expenseReferenceMonth(Map<String, dynamic> data) {
    final isPlanned = _isPlannedExpense(data);

    if (isPlanned) {
      final monthRaw = data['month'];

      if (monthRaw is Timestamp) {
        final monthDate = monthRaw.toDate();
        return DateTime(monthDate.year, monthDate.month);
      }

      return DateTime(DateTime.now().year, DateTime.now().month);
    }

    final dueDateRaw = data['due_date'];

    if (dueDateRaw is Timestamp) {
      final dueDate = dueDateRaw.toDate();
      return DateTime(dueDate.year, dueDate.month);
    }

    return DateTime(DateTime.now().year, DateTime.now().month);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docsBySelectedMonth(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      final referenceMonth = _expenseReferenceMonth(data);

      return _sameMonth(referenceMonth, _selectedMonth);
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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final monthDocs = _docsBySelectedMonth(docs);

    if (_selectedFilter == ExpenseFilter.all) {
      return monthDocs;
    }

    if (_selectedFilter == ExpenseFilter.planned) {
      return monthDocs.where((doc) {
        return _isPlannedExpense(doc.data());
      }).toList();
    }

    if (_selectedFilter == ExpenseFilter.paid) {
      return monthDocs.where((doc) {
        final data = doc.data();

        return !_isPlannedExpense(data) && data['is_paid'] == true;
      }).toList();
    }

    return monthDocs.where((doc) {
      final data = doc.data();

      return !_isPlannedExpense(data) && data['is_paid'] != true;
    }).toList();
  }

  String _deadlineLabel(DateTime dueDate, bool isPaid) {
    if (isPaid) return 'Pagata';

    final today = DateTime.now();
    final currentDate = DateTime(today.year, today.month, today.day);
    final targetDate = DateTime(dueDate.year, dueDate.month, dueDate.day);

    final diff = targetDate.difference(currentDate).inDays;

    if (diff < 0) {
      return 'Scaduta da ${diff.abs()} gg';
    }

    if (diff == 0) {
      return 'Scade oggi';
    }

    if (diff == 1) {
      return 'Scade domani';
    }

    return 'Scade tra $diff gg';
  }

  int _deadlineDiffDays(DateTime dueDate) {
    final today = DateTime.now();
    final currentDate = DateTime(today.year, today.month, today.day);
    final targetDate = DateTime(dueDate.year, dueDate.month, dueDate.day);

    return targetDate.difference(currentDate).inDays;
  }

  bool _isExpenseInWarningRange({
    required Map<String, dynamic> data,
    required DateTime dueDate,
  }) {
    if (_isPlannedExpense(data)) return false;
    if (data['is_paid'] == true) return false;
    if (data['reminder_enabled'] != true) return false;

    final diff = _deadlineDiffDays(dueDate);

    return diff <= 2;
  }

  Color _deadlineColor(DateTime dueDate, bool isPaid) {
    if (isPaid) return const Color(0xFF16A34A);

    final diff = _deadlineDiffDays(dueDate);

    if (diff <= 0) return const Color(0xFFDC2626);
    if (diff <= 2) return const Color(0xFFF59E0B);

    return const Color(0xFF2563EB);
  }

  List<_ExpenseDeadlineAlert> _expenseDeadlineAlerts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final alerts = <_ExpenseDeadlineAlert>[];

    for (final doc in docs) {
      final data = doc.data();

      if (_isPlannedExpense(data)) continue;
      if (data['is_paid'] == true) continue;
      if (data['reminder_enabled'] != true) continue;

      final dueDateRaw = data['due_date'];

      if (dueDateRaw is! Timestamp) continue;

      final dueDate = dueDateRaw.toDate();
      final diff = _deadlineDiffDays(dueDate);

      if (diff > 2) continue;

      alerts.add(
        _ExpenseDeadlineAlert(
          title: (data['title'] ?? 'Spesa').toString(),
          amount: _amountFrom(data['amount']),
          dueDate: dueDate,
          diffDays: diff,
        ),
      );
    }

    alerts.sort((a, b) => a.diffDays.compareTo(b.diffDays));

    return alerts;
  }

  double _sumAllExpected(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.fold<double>(0, (sum, doc) {
      return sum + _amountFrom(doc.data()['amount']);
    });
  }

  double _sumUnpaidStandard(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.fold<double>(0, (sum, doc) {
      final data = doc.data();

      if (_isPlannedExpense(data)) return sum;
      if (data['is_paid'] == true) return sum;

      return sum + _amountFrom(data['amount']);
    });
  }

  double _sumPlannedRemaining(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.fold<double>(0, (sum, doc) {
      final data = doc.data();

      if (!_isPlannedExpense(data)) return sum;

      final amount = _amountFrom(data['amount']);
      final splitItems = _splitItemsFrom(data['split_items']);
      final spent = _spentFromSplitItems(splitItems);

      return sum + _remainingBudget(
        amount: amount,
        spent: spent,
      );
    });
  }

  double _sumPlannedSaved(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.fold<double>(0, (sum, doc) {
      final data = doc.data();

      if (!_isPlannedExpense(data)) return sum;

      final referenceMonth = _expenseReferenceMonth(data);

      if (!_isPastMonth(referenceMonth)) return sum;

      final amount = _amountFrom(data['amount']);
      final splitItems = _splitItemsFrom(data['split_items']);
      final spent = _spentFromSplitItems(splitItems);

      final saved = amount - spent;

      if (saved <= 0) return sum;

      return sum + saved;
    });
  }

  int _unpaidStandardCount(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();

      return !_isPlannedExpense(data) && data['is_paid'] != true;
    }).length;
  }

  Future<void> _showExpenseDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
    required List<_ExpenseBankAccountItem> bankAccounts,
  }) async {
    await _showResponsiveSheet(
      maxDesktopWidth: 520,
      child: _ExpenseFormDialog(
        financeService: _financeService,
        expenseDoc: doc,
        bankAccounts: bankAccounts,
      ),
    );
  }

  Future<void> _showAddBudgetMovementDialog({
    required String expenseId,
    required String title,
    required double remainingAmount,
    required List<_ExpenseBankAccountItem> bankAccounts,
  }) async {
    await _showResponsiveSheet(
      maxDesktopWidth: 480,
      child: _BudgetMovementDialog(
        title: title,
        remainingAmount: remainingAmount,
        financeService: _financeService,
        expenseId: expenseId,
        bankAccounts: bankAccounts,
      ),
    );
  }

  Future<void> _showPayExpenseDialog({
    required String expenseId,
    required String title,
    required double amount,
    required List<_ExpenseBankAccountItem> bankAccounts,
  }) async {
    await _showResponsiveSheet(
      maxDesktopWidth: 460,
      child: _PayExpenseDialog(
        financeService: _financeService,
        expenseId: expenseId,
        title: title,
        amount: amount,
        bankAccounts: bankAccounts,
      ),
    );
  }

  Future<void> _deleteBudgetMovement({
    required String expenseId,
    required List<Map<String, dynamic>> currentItems,
    required int index,
  }) async {
    final updatedItems = List<Map<String, dynamic>>.from(currentItems);

    if (index < 0 || index >= updatedItems.length) return;

    updatedItems.removeAt(index);

    await _financeService.updateExpenseSplitItems(
      expenseId: expenseId,
      splitItems: updatedItems,
    );
  }

  Future<void> _showResponsiveSheet({
    required Widget child,
    double maxDesktopWidth = 480,
  }) async {
    final colors = _ExpensesColors.of(context);
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

  Future<void> _confirmDelete({
    required String expenseId,
    required String title,
  }) async {
    final colors = _ExpensesColors.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Eliminare spesa?',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          content: Text(
            'Vuoi davvero eliminare "$title"? Se era già stata pagata da un conto, il saldo verrà ripristinato.',
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
      await _financeService.deleteExpense(expenseId: expenseId);
    }
  }

  Future<void> _togglePaid({
    required String expenseId,
    required String title,
    required double amount,
    required bool currentValue,
    required List<_ExpenseBankAccountItem> bankAccounts,
  }) async {
    if (currentValue) {
      await _financeService.updateExpensePaid(
        expenseId: expenseId,
        isPaid: false,
      );

      return;
    }

    await _showPayExpenseDialog(
      expenseId: expenseId,
      title: title,
      amount: amount,
      bankAccounts: bankAccounts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    return Scaffold(
      backgroundColor: colors.scaffold,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _financeService.expensesStream(),
        builder: (context, snapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _financeService.bankAccountsStream(),
            builder: (context, bankAccountsSnapshot) {
              final docs = snapshot.data?.docs ?? [];
              final bankAccounts = _bankAccountsFromSnapshot(
                bankAccountsSnapshot.data,
              );

              final monthDocs = _docsBySelectedMonth(docs);
              final filteredDocs = _filteredDocs(docs);

              final totalAllExpected = _sumAllExpected(monthDocs);
              final totalUnpaidStandard = _sumUnpaidStandard(monthDocs);
              final totalPlannedRemaining = _sumPlannedRemaining(monthDocs);
              final totalPlannedSaved = _sumPlannedSaved(monthDocs);
              final unpaidCount = _unpaidStandardCount(monthDocs);
              final deadlineAlerts = _expenseDeadlineAlerts(monthDocs);

              final isSelectedMonthClosed = _isPastMonth(_selectedMonth);

              final plannedHeaderLabel =
                  isSelectedMonthClosed ? 'Risparmiato' : 'Residuo budget';

              final plannedHeaderValue = isSelectedMonthClosed
                  ? totalPlannedSaved
                  : totalPlannedRemaining;

              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting ||
                      bankAccountsSnapshot.connectionState ==
                          ConnectionState.waiting;

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
                            _ExpensesHeader(
                              totalAll: _currencyFormatter.format(
                                totalAllExpected,
                              ),
                              totalUnpaid: _currencyFormatter.format(
                                totalUnpaidStandard,
                              ),
                              plannedAmount: _currencyFormatter.format(
                                plannedHeaderValue,
                              ),
                              plannedLabel: plannedHeaderLabel,
                              unpaidCount: unpaidCount,
                              onAddExpense: () => _showExpenseDialog(
                                bankAccounts: bankAccounts,
                              ),
                            ),
                            SizedBox(height: isMobile ? 14 : 18),
                            _MonthSelector(
                              selectedMonth: _selectedMonth,
                              monthFormatter: _monthFormatter,
                              onPrevious: _goToPreviousMonth,
                              onNext: _goToNextMonth,
                              onCurrentMonth: _goToCurrentMonth,
                            ),
                            if (deadlineAlerts.isNotEmpty) ...[
                              SizedBox(height: isMobile ? 14 : 18),
                              _ExpenseDeadlineNotification(
                                alerts: deadlineAlerts,
                                currencyFormatter: _currencyFormatter,
                                dateFormatter: _dateFormatter,
                              ),
                            ],
                            SizedBox(height: isMobile ? 14 : 18),
                            _FilterBar(
                              selectedFilter: _selectedFilter,
                              onChanged: (filter) {
                                setState(() {
                                  _selectedFilter = filter;
                                });
                              },
                            ),
                            SizedBox(height: isMobile ? 18 : 22),
                            if (isLoading)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: CircularProgressIndicator(
                                    color: colors.primary,
                                  ),
                                ),
                              )
                            else if (filteredDocs.isEmpty)
                              const _EmptyExpenses()
                            else
                              Column(
                                children: filteredDocs.map((doc) {
                                  final data = doc.data();

                                  final title = data['title'] ?? 'Spesa';
                                  final category =
                                      data['category'] ?? 'Generale';

                                  final amount = _amountFrom(data['amount']);
                                  final isPlanned = _isPlannedExpense(data);
                                  final isPaid = _isStandardPaid(data);

                                  final splitItems = _splitItemsFrom(
                                    data['split_items'],
                                  );
                                  final spent = _spentFromSplitItems(splitItems);
                                  final remaining = _remainingBudget(
                                    amount: amount,
                                    spent: spent,
                                  );

                                  final reminderEnabled =
                                      data['reminder_enabled'] == true;

                                  final dueDateRaw = data['due_date'];
                                  final dueDate = dueDateRaw is Timestamp
                                      ? dueDateRaw.toDate()
                                      : DateTime.now();

                                  final monthRaw = data['month'];
                                  final monthDate = monthRaw is Timestamp
                                      ? monthRaw.toDate()
                                      : DateTime(
                                          DateTime.now().year,
                                          DateTime.now().month,
                                        );

                                  final isBudgetMonthClosed =
                                      isPlanned && _isPastMonth(monthDate);

                                  final bankAccountName =
                                      data['bankAccountName']?.toString();

                                  return _ExpenseCard(
                                    title: title.toString(),
                                    category: category.toString(),
                                    amount: _currencyFormatter.format(amount),
                                    dueDate: _dateFormatter.format(dueDate),
                                    monthLabel:
                                        _monthFormatter.format(monthDate),
                                    deadlineLabel: _deadlineLabel(
                                      dueDate,
                                      isPaid,
                                    ),
                                    deadlineColor: _deadlineColor(
                                      dueDate,
                                      isPaid,
                                    ),
                                    deadlineDiffDays: isPlanned ? null : _deadlineDiffDays(dueDate),
                                    isPaid: isPaid,
                                    isPlanned: isPlanned,
                                    isBudgetMonthClosed: isBudgetMonthClosed,
                                    reminderEnabled: reminderEnabled,
                                    bankAccountName: bankAccountName,
                                    spentAmount:
                                        _currencyFormatter.format(spent),
                                    remainingAmount: _currencyFormatter.format(
                                      remaining,
                                    ),
                                    rawRemainingAmount: remaining,
                                    splitItems: splitItems,
                                    currencyFormatter: _currencyFormatter,
                                    dateFormatter: _dateFormatter,
                                    onTogglePaid: () => _togglePaid(
                                      expenseId: doc.id,
                                      title: title.toString(),
                                      amount: amount,
                                      currentValue: isPaid,
                                      bankAccounts: bankAccounts,
                                    ),
                                    onEdit: () => _showExpenseDialog(
                                      doc: doc,
                                      bankAccounts: bankAccounts,
                                    ),
                                    onDelete: () => _confirmDelete(
                                      expenseId: doc.id,
                                      title: title.toString(),
                                    ),
                                    onAddBudgetMovement: () =>
                                        _showAddBudgetMovementDialog(
                                      expenseId: doc.id,
                                      title: title.toString(),
                                      remainingAmount: remaining,
                                      bankAccounts: bankAccounts,
                                    ),
                                    onDeleteBudgetMovement: (index) =>
                                        _deleteBudgetMovement(
                                      expenseId: doc.id,
                                      currentItems: splitItems,
                                      index: index,
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

class _ExpenseDeadlineAlert {
  final String title;
  final double amount;
  final DateTime dueDate;
  final int diffDays;

  const _ExpenseDeadlineAlert({
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.diffDays,
  });
}

class _ExpenseDeadlineNotification extends StatelessWidget {
  final List<_ExpenseDeadlineAlert> alerts;
  final NumberFormat currencyFormatter;
  final DateFormat dateFormatter;

  const _ExpenseDeadlineNotification({
    required this.alerts,
    required this.currencyFormatter,
    required this.dateFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);
    final urgentAlerts = alerts.where((alert) => alert.diffDays <= 0).toList();
    final hasUrgent = urgentAlerts.isNotEmpty;

    final mainAlert = alerts.first;

    final backgroundColor = hasUrgent
        ? colors.isDark
            ? const Color(0xFF450A0A)
            : const Color(0xFFFFF1F2)
        : colors.isDark
            ? const Color(0xFF451A03)
            : const Color(0xFFFFFBEB);

    final borderColor =
        hasUrgent ? const Color(0xFFDC2626) : const Color(0xFFF59E0B);

    final textColor = hasUrgent
        ? colors.isDark
            ? const Color(0xFFFCA5A5)
            : const Color(0xFF991B1B)
        : colors.isDark
            ? const Color(0xFFFDE68A)
            : const Color(0xFF92400E);

    final icon = hasUrgent
        ? Icons.error_rounded
        : Icons.notifications_active_rounded;

    final title = hasUrgent
        ? 'Attenzione: hai spese in scadenza oggi o già scadute'
        : 'Promemoria: hai spese in scadenza nei prossimi 2 giorni';

    final mainMessage = _messageForAlert(mainAlert);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.75),
          width: 1.3,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: colors.isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: borderColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  mainMessage,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                if (alerts.length > 1) ...[
                  const SizedBox(height: 6),
                  Text(
                    '+ altre ${alerts.length - 1} spese da controllare',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _messageForAlert(_ExpenseDeadlineAlert alert) {
    final amount = currencyFormatter.format(alert.amount);
    final date = dateFormatter.format(alert.dueDate);

    if (alert.diffDays < 0) {
      return '${alert.title} · $amount · scaduta da ${alert.diffDays.abs()} giorni ($date).';
    }

    if (alert.diffDays == 0) {
      return '${alert.title} · $amount · scade oggi ($date).';
    }

    if (alert.diffDays == 1) {
      return '${alert.title} · $amount · scade domani ($date).';
    }

    return '${alert.title} · $amount · scade tra ${alert.diffDays} giorni ($date).';
  }
}

class _ExpensesColors {
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
  final Color headerBackground;
  final Color headerText;
  final Color headerMuted;
  final Color shadow;

  const _ExpensesColors({
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
    required this.headerBackground,
    required this.headerText,
    required this.headerMuted,
    required this.shadow,
  });

  factory _ExpensesColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return const _ExpensesColors(
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
        headerBackground: Color(0xFF020617),
        headerText: Colors.white,
        headerMuted: Color(0xFFCBD5E1),
        shadow: Colors.black,
      );
    }

    return const _ExpensesColors(
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
      headerBackground: Color(0xFF172033),
      headerText: Colors.white,
      headerMuted: Color(0xFFD7DEE9),
      shadow: Colors.black,
    );
  }
}

BoxDecoration _expensesCardDecoration(BuildContext context) {
  final colors = _ExpensesColors.of(context);

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

InputDecoration _expensesInputDecoration({
  required BuildContext context,
  required String label,
  IconData? suffixIcon,
}) {
  final colors = _ExpensesColors.of(context);

  return InputDecoration(
    labelText: label,
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

Future<DateTime?> _showExpensesDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) async {
  final colors = _ExpensesColors.of(context);

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

class _ExpensesHeader extends StatelessWidget {
  final String totalAll;
  final String totalUnpaid;
  final String plannedAmount;
  final String plannedLabel;
  final int unpaidCount;
  final VoidCallback onAddExpense;

  const _ExpensesHeader({
    required this.totalAll,
    required this.totalUnpaid,
    required this.plannedAmount,
    required this.plannedLabel,
    required this.unpaidCount,
    required this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);
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
                const _ExpensesHeaderText(isMobile: true),
                const SizedBox(height: 20),
                _HeaderStatsGrid(
                  totalAll: totalAll,
                  totalUnpaid: totalUnpaid,
                  plannedAmount: plannedAmount,
                  plannedLabel: plannedLabel,
                  unpaidCount: unpaidCount,
                  isMobile: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: onAddExpense,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nuova spesa'),
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
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const Expanded(
                  child: _ExpensesHeaderText(isMobile: false),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _HeaderStatsGrid(
                      totalAll: totalAll,
                      totalUnpaid: totalUnpaid,
                      plannedAmount: plannedAmount,
                      plannedLabel: plannedLabel,
                      unpaidCount: unpaidCount,
                      isMobile: false,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: onAddExpense,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Nuova spesa'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              colors.isDark ? colors.primary : Colors.white,
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
                  ],
                ),
              ],
            ),
    );
  }
}

class _ExpensesHeaderText extends StatelessWidget {
  final bool isMobile;

  const _ExpensesHeaderText({
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestione spese',
          style: TextStyle(
            color: colors.headerText,
            fontSize: isMobile ? 27 : 32,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Gestisci scadenze, rate mensili, budget e scegli da quale conto pagare.',
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
  final String totalAll;
  final String totalUnpaid;
  final String plannedAmount;
  final String plannedLabel;
  final int unpaidCount;
  final bool isMobile;

  const _HeaderStatsGrid({
    required this.totalAll,
    required this.totalUnpaid,
    required this.plannedAmount,
    required this.plannedLabel,
    required this.unpaidCount,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _HeaderMiniStat(
        label: 'Totale previsto',
        value: totalAll,
      ),
      _HeaderMiniStat(
        label: 'Da pagare',
        value: totalUnpaid,
      ),
      _HeaderMiniStat(
        label: plannedLabel,
        value: plannedAmount,
      ),
      _HeaderMiniStat(
        label: 'Non pagate',
        value: unpaidCount.toString(),
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
    final colors = _ExpensesColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: isMobile ? double.infinity : 155,
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
              fontSize: isMobile ? 18 : 19,
              fontWeight: FontWeight.w900,
            ),
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
    final colors = _ExpensesColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    final label = monthFormatter.format(selectedMonth);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: _expensesCardDecoration(context).copyWith(
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
    final colors = _ExpensesColors.of(context);

    return Material(
      color: colors.primarySoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: colors.primary,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final ExpenseFilter selectedFilter;
  final ValueChanged<ExpenseFilter> onChanged;

  const _FilterBar({
    required this.selectedFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: _expensesCardDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(isMobile ? 24 : 999),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: colors.isDark ? 0.18 : 0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FilterChipButton(
                        label: 'Tutte',
                        selected: selectedFilter == ExpenseFilter.all,
                        onTap: () => onChanged(ExpenseFilter.all),
                      ),
                    ),
                    Expanded(
                      child: _FilterChipButton(
                        label: 'Da pagare',
                        selected: selectedFilter == ExpenseFilter.unpaid,
                        onTap: () => onChanged(ExpenseFilter.unpaid),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _FilterChipButton(
                        label: 'Pagate',
                        selected: selectedFilter == ExpenseFilter.paid,
                        onTap: () => onChanged(ExpenseFilter.paid),
                      ),
                    ),
                    Expanded(
                      child: _FilterChipButton(
                        label: 'Budget',
                        selected: selectedFilter == ExpenseFilter.planned,
                        onTap: () => onChanged(ExpenseFilter.planned),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _FilterChipButton(
                    label: 'Tutte',
                    selected: selectedFilter == ExpenseFilter.all,
                    onTap: () => onChanged(ExpenseFilter.all),
                  ),
                ),
                Expanded(
                  child: _FilterChipButton(
                    label: 'Da pagare',
                    selected: selectedFilter == ExpenseFilter.unpaid,
                    onTap: () => onChanged(ExpenseFilter.unpaid),
                  ),
                ),
                Expanded(
                  child: _FilterChipButton(
                    label: 'Pagate',
                    selected: selectedFilter == ExpenseFilter.paid,
                    onTap: () => onChanged(ExpenseFilter.paid),
                  ),
                ),
                Expanded(
                  child: _FilterChipButton(
                    label: 'Budget mensili',
                    selected: selectedFilter == ExpenseFilter.planned,
                    onTap: () => onChanged(ExpenseFilter.planned),
                  ),
                ),
              ],
            ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 42,
      decoration: BoxDecoration(
        color: selected ? colors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? colors.primary : colors.textSecondary,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final String title;
  final String category;
  final String amount;
  final String dueDate;
  final String monthLabel;
  final String deadlineLabel;
  final Color deadlineColor;
  final int? deadlineDiffDays;
  final bool isPaid;
  final bool isPlanned;
  final bool isBudgetMonthClosed;
  final bool reminderEnabled;
  final String? bankAccountName;
  final String spentAmount;
  final String remainingAmount;
  final double rawRemainingAmount;
  final List<Map<String, dynamic>> splitItems;
  final NumberFormat currencyFormatter;
  final DateFormat dateFormatter;
  final VoidCallback onTogglePaid;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddBudgetMovement;
  final ValueChanged<int> onDeleteBudgetMovement;

  const _ExpenseCard({
    required this.title,
    required this.category,
    required this.amount,
    required this.dueDate,
    required this.monthLabel,
    required this.deadlineLabel,
    required this.deadlineColor,
    required this.deadlineDiffDays,
    required this.isPaid,
    required this.isPlanned,
    required this.isBudgetMonthClosed,
    required this.reminderEnabled,
    required this.bankAccountName,
    required this.spentAmount,
    required this.remainingAmount,
    required this.rawRemainingAmount,
    required this.splitItems,
    required this.currencyFormatter,
    required this.dateFormatter,
    required this.onTogglePaid,
    required this.onEdit,
    required this.onDelete,
    required this.onAddBudgetMovement,
    required this.onDeleteBudgetMovement,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.all(isMobile ? 16 : 18),
      decoration: _cardDecoration(context),
      child: isMobile ? _mobileLayout(context) : _desktopLayout(context),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    if (!isPlanned && !isPaid && deadlineDiffDays != null) {
      if (deadlineDiffDays! <= 0) {
        return _expensesCardDecoration(context).copyWith(
          color: colors.isDark ? const Color(0xFF450A0A) : const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFDC2626),
            width: 1.4,
          ),
        );
      }

      if (deadlineDiffDays! <= 2) {
        return _expensesCardDecoration(context).copyWith(
          color: colors.isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFF59E0B),
            width: 1.4,
          ),
        );
      }
    }

    return _expensesCardDecoration(context).copyWith(
      borderRadius: BorderRadius.circular(24),
    );
  }

  Widget _mobileLayout(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _topMobile(context),
        const SizedBox(height: 14),
        if (isPlanned) ...[
          _plannedInfo(context),
          const SizedBox(height: 14),
          _budgetProgress(context),
          const SizedBox(height: 14),
          _budgetMovements(context),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: onAddBudgetMovement,
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Aggiungi uscita'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor:
                    colors.isDark ? const Color(0xFF0F172A) : Colors.white,
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
        ] else ...[
          _standardInfo(context),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: onTogglePaid,
              icon: Icon(
                isPaid ? Icons.undo_rounded : Icons.check_circle_rounded,
              ),
              label: Text(
                isPaid ? 'Segna da pagare' : 'Segna come pagata',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    isPaid ? colors.textPrimary : const Color(0xFF16A34A),
                side: BorderSide(
                  color: isPaid ? colors.border : const Color(0xFF16A34A),
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
      ],
    );
  }

  Widget _desktopLayout(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _ExpenseIcon(
              isPaid: isPaid,
              isPlanned: isPlanned,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: isPlanned
                  ? _plannedDesktopContent(context)
                  : _standardDesktopContent(context),
            ),
            const SizedBox(width: 14),
            _actionsDesktop(context),
          ],
        ),
        if (isPlanned) ...[
          const SizedBox(height: 16),
          _budgetProgress(context),
          const SizedBox(height: 12),
          _budgetMovements(context),
        ],
      ],
    );
  }

  Widget _topMobile(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    return Row(
      children: [
        _ExpenseIcon(
          isPaid: isPaid,
          isPlanned: isPlanned,
        ),
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
                isPlanned ? 'Budget: $amount' : amount,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: colors.primary,
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
    );
  }

  Widget _standardDesktopContent(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    return Wrap(
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
        _standardInfo(context),
      ],
    );
  }

  Widget _plannedDesktopContent(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              'Budget: $amount',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _plannedInfo(context),
      ],
    );
  }

  Widget _standardInfo(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InfoBadge(
          text: category,
          icon: Icons.category_rounded,
        ),
        _InfoBadge(
          text: dueDate,
          icon: Icons.calendar_month_rounded,
        ),
        _ColoredBadge(
          text: deadlineLabel,
          color: deadlineColor,
        ),
        if (isPaid && bankAccountName != null && bankAccountName!.isNotEmpty)
          _InfoBadge(
            text: bankAccountName!,
            icon: Icons.account_balance_rounded,
          ),
        if (reminderEnabled)
          const _InfoBadge(
            text: 'Promemoria',
            icon: Icons.notifications_active_rounded,
          ),
      ],
    );
  }

  Widget _plannedInfo(BuildContext context) {
    final numericTotal = _parseCurrencyText(amount);
    final numericSpent = _parseCurrencyText(spentAmount);

    final isOverBudget = numericSpent > numericTotal && numericTotal > 0;
    final saved = numericTotal - numericSpent;

    String resultText = 'Residuo: $remainingAmount';
    IconData resultIcon = Icons.savings_rounded;

    if (isBudgetMonthClosed) {
      if (isOverBudget) {
        resultText =
            'Sforato: ${currencyFormatter.format(numericSpent - numericTotal)}';
        resultIcon = Icons.warning_amber_rounded;
      } else if (saved > 0) {
        resultText = 'Risparmiato: ${currencyFormatter.format(saved)}';
        resultIcon = Icons.savings_rounded;
      } else {
        resultText = 'Budget chiuso';
        resultIcon = Icons.check_circle_rounded;
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InfoBadge(
          text: category,
          icon: Icons.category_rounded,
        ),
        _InfoBadge(
          text: monthLabel,
          icon: Icons.calendar_view_month_rounded,
        ),
        _ColoredBadge(
          text: isBudgetMonthClosed ? 'Mese chiuso' : 'Budget mensile',
          color: isBudgetMonthClosed
              ? const Color(0xFF16A34A)
              : const Color(0xFF7C3AED),
        ),
        _InfoBadge(
          text: 'Speso: $spentAmount',
          icon: Icons.payments_rounded,
        ),
        _InfoBadge(
          text: resultText,
          icon: resultIcon,
        ),
      ],
    );
  }

  Widget _actionsDesktop(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    if (isPlanned) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: onAddBudgetMovement,
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('Aggiungi uscita'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor:
                  colors.isDark ? const Color(0xFF0F172A) : Colors.white,
              elevation: 0,
            ),
          ),
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
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: onTogglePaid,
          icon: Icon(
            isPaid ? Icons.undo_rounded : Icons.check_circle_rounded,
          ),
          label: Text(
            isPaid ? 'Da pagare' : 'Pagata',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.textPrimary,
            side: BorderSide(
              color: colors.border,
            ),
          ),
        ),
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
    );
  }

  Widget _budgetProgress(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    final totalText = amount;
    final spentText = spentAmount;
    final remainingText = remainingAmount;

    double progress = 0;

    final numericTotal = _parseCurrencyText(totalText);
    final numericSpent = _parseCurrencyText(spentText);

    if (numericTotal > 0) {
      progress = (numericSpent / numericTotal).clamp(0, 1);
    }

    final isOverBudget = numericSpent > numericTotal && numericTotal > 0;
    final saved = numericTotal - numericSpent;

    String thirdLabel = 'Residuo';
    String thirdValue = remainingText;

    if (isOverBudget) {
      thirdLabel = 'Superato';
      thirdValue = currencyFormatter.format(numericSpent - numericTotal);
    } else if (isBudgetMonthClosed) {
      if (saved > 0) {
        thirdLabel = 'Risparmiato';
        thirdValue = currencyFormatter.format(saved);
      } else {
        thirdLabel = 'Chiuso';
        thirdValue = currencyFormatter.format(0);
      }
    }

    Color progressColor = colors.primary;

    if (isOverBudget) {
      progressColor = const Color(0xFFDC2626);
    } else if (isBudgetMonthClosed && saved > 0) {
      progressColor = const Color(0xFF16A34A);
    }

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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _BudgetMiniValue(
                  label: 'Previsto',
                  value: totalText,
                ),
              ),
              Expanded(
                child: _BudgetMiniValue(
                  label: 'Speso',
                  value: spentText,
                ),
              ),
              Expanded(
                child: _BudgetMiniValue(
                  label: thirdLabel,
                  value: thirdValue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: colors.border,
              color: progressColor,
            ),
          ),
          if (isBudgetMonthClosed) ...[
            const SizedBox(height: 12),
            _ClosedBudgetMessage(
              isOverBudget: isOverBudget,
              savedAmount: currencyFormatter.format(saved > 0 ? saved : 0),
              overAmount: currencyFormatter.format(
                isOverBudget ? numericSpent - numericTotal : 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _parseCurrencyText(String value) {
    final cleaned = value
        .replaceAll('€', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();

    return double.tryParse(cleaned) ?? 0;
  }

  Widget _budgetMovements(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    if (splitItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.isDark
              ? const Color(0xFF451A03)
              : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.isDark
                ? const Color(0xFF92400E)
                : const Color(0xFFFDE68A),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ancora nessuna uscita registrata per questo budget.',
                style: TextStyle(
                  color: colors.isDark
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFF92400E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.cardSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.border,
        ),
      ),
      child: Column(
        children: List.generate(splitItems.length, (index) {
          final item = splitItems[index];

          final itemTitle = item['title']?.toString().trim();
          final amountValue = item['amount'];
          final paidAtRaw = item['paid_at'];
          final accountName = item['bankAccountName']?.toString();

          final paidAt = paidAtRaw is Timestamp
              ? paidAtRaw.toDate()
              : paidAtRaw is DateTime
                  ? paidAtRaw
                  : DateTime.now();

          final subtitle = accountName == null || accountName.isEmpty
              ? dateFormatter.format(paidAt)
              : '${dateFormatter.format(paidAt)} • $accountName';

          return Column(
            children: [
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.payments_rounded,
                    size: 20,
                    color: colors.primary,
                  ),
                ),
                title: Text(
                  itemTitle == null || itemTitle.isEmpty
                      ? 'Uscita budget'
                      : itemTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currencyFormatter.format(_readMovementAmount(amountValue)),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Elimina uscita',
                      onPressed: () => onDeleteBudgetMovement(index),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
              if (index != splitItems.length - 1)
                Divider(
                  height: 1,
                  color: colors.border,
                ),
            ],
          );
        }),
      ),
    );
  }

  double _readMovementAmount(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0;
  }
}

class _BudgetMiniValue extends StatelessWidget {
  final String label;
  final String value;

  const _BudgetMiniValue({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _ClosedBudgetMessage extends StatelessWidget {
  final bool isOverBudget;
  final String savedAmount;
  final String overAmount;

  const _ClosedBudgetMessage({
    required this.isOverBudget,
    required this.savedAmount,
    required this.overAmount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    final bgColor = isOverBudget
        ? colors.isDark
            ? const Color(0xFF450A0A)
            : const Color(0xFFFEE2E2)
        : colors.isDark
            ? const Color(0xFF052E16)
            : const Color(0xFFEAF8EF);

    final textColor = isOverBudget
        ? colors.isDark
            ? const Color(0xFFFCA5A5)
            : const Color(0xFF991B1B)
        : colors.isDark
            ? const Color(0xFF86EFAC)
            : const Color(0xFF166534);

    final icon = isOverBudget
        ? Icons.warning_amber_rounded
        : Icons.savings_rounded;

    final text = isOverBudget
        ? 'Questo mese hai superato il budget di $overAmount.'
        : 'Ottimo: questo mese hai risparmiato $savedAmount.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: textColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseIcon extends StatelessWidget {
  final bool isPaid;
  final bool isPlanned;

  const _ExpenseIcon({
    required this.isPaid,
    required this.isPlanned,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    final bgColor = isPlanned
        ? colors.isDark
            ? const Color(0xFF2E1065)
            : const Color(0xFFF3E8FF)
        : isPaid
            ? colors.isDark
                ? const Color(0xFF052E16)
                : const Color(0xFFEAF8EF)
            : colors.primarySoft;

    final iconColor = isPlanned
        ? const Color(0xFF8B5CF6)
        : isPaid
            ? const Color(0xFF16A34A)
            : colors.primary;

    final icon = isPlanned
        ? Icons.account_balance_wallet_rounded
        : isPaid
            ? Icons.check_circle_rounded
            : Icons.receipt_long_rounded;

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        icon,
        color: iconColor,
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
    final colors = _ExpensesColors.of(context);

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
    final colors = _ExpensesColors.of(context);

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

class _EmptyExpenses extends StatelessWidget {
  const _EmptyExpenses();

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(34),
      decoration: _expensesCardDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 44,
            color: colors.textMuted,
          ),
          const SizedBox(height: 14),
          Text(
            'Nessuna spesa trovata',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aggiungi una nuova spesa oppure cambia filtro.',
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

class _ExpenseFormDialog extends StatefulWidget {
  final FinanceService financeService;
  final QueryDocumentSnapshot<Map<String, dynamic>>? expenseDoc;
  final List<_ExpenseBankAccountItem> bankAccounts;

  const _ExpenseFormDialog({
    required this.financeService,
    required this.bankAccounts,
    this.expenseDoc,
  });

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _categoryController;

  late DateTime _selectedDueDate;
  late DateTime _selectedMonth;
  late DateTime _repeatUntilDate;

  late bool _isPaid;
  late bool _reminderEnabled;
  late bool _repeatMonthly;

  late ExpenseType _expenseType;

  String? _selectedBankAccountId;

  bool _loading = false;

  bool get _isEditMode => widget.expenseDoc != null;
  bool get _isPlanned => _expenseType == ExpenseType.planned;

  @override
  void initState() {
    super.initState();

    final data = widget.expenseDoc?.data();

    final title = data?['title'] ?? '';
    final category = data?['category'] ?? 'Generale';

    final rawAmount = data?['amount'];
    final amount = rawAmount is int
        ? rawAmount.toDouble()
        : rawAmount is double
            ? rawAmount
            : rawAmount is num
                ? rawAmount.toDouble()
                : 0.0;

    final type = data?['type'] == 'planned' ? 'planned' : 'standard';

    _expenseType =
        type == 'planned' ? ExpenseType.planned : ExpenseType.standard;

    final rawDueDate = data?['due_date'];
    final dueDate =
        rawDueDate is Timestamp ? rawDueDate.toDate() : DateTime.now();

    final rawMonth = data?['month'];
    final monthDate = rawMonth is Timestamp
        ? rawMonth.toDate()
        : DateTime(DateTime.now().year, DateTime.now().month);

    final rawRepeatUntil = data?['repeat_until_date'];
    final repeatUntilDate = rawRepeatUntil is Timestamp
        ? rawRepeatUntil.toDate()
        : DateTime(dueDate.year, dueDate.month + 12, dueDate.day);

    _titleController = TextEditingController(text: title.toString());

    _amountController = TextEditingController(
      text: _isEditMode ? amount.toStringAsFixed(2).replaceAll('.', ',') : '',
    );

    _categoryController = TextEditingController(text: category.toString());

    _selectedDueDate = dueDate;
    _selectedMonth = DateTime(monthDate.year, monthDate.month);

    _repeatUntilDate = repeatUntilDate;

    _isPaid = data?['is_paid'] == true;

    _reminderEnabled = _isEditMode ? (data?['reminder_enabled'] == true) : true;

    _repeatMonthly = _isEditMode ? (data?['repeat_monthly'] == true) : false;

    _selectedBankAccountId = data?['bankAccountId']?.toString();

    final selectedExists = widget.bankAccounts.any(
      (account) => account.id == _selectedBankAccountId,
    );

    if (!selectedExists) {
      _selectedBankAccountId = null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  String? _selectedBankAccountName() {
    if (_selectedBankAccountId == null) return null;

    for (final account in widget.bankAccounts) {
      if (account.id == _selectedBankAccountId) {
        return account.name;
      }
    }

    return null;
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  DateTime _safeMonthlyDate({
    required int year,
    required int month,
    required int preferredDay,
  }) {
    final lastDay = _daysInMonth(year, month);
    final day = preferredDay > lastDay ? lastDay : preferredDay;

    return DateTime(year, month, day);
  }

  List<DateTime> _monthlyDueDates({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final dates = <DateTime>[];

    final preferredDay = startDate.day;

    var cursor = DateTime(startDate.year, startDate.month);

    while (!cursor.isAfter(DateTime(endDate.year, endDate.month))) {
      final dueDate = _safeMonthlyDate(
        year: cursor.year,
        month: cursor.month,
        preferredDay: preferredDay,
      );

      if (!dueDate.isBefore(startDate) && !dueDate.isAfter(endDate)) {
        dates.add(dueDate);
      }

      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    return dates;
  }

  Future<void> _pickDueDate() async {
    final picked = await _showExpensesDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;

        if (_repeatUntilDate.isBefore(_selectedDueDate)) {
          _repeatUntilDate = DateTime(
            _selectedDueDate.year,
            _selectedDueDate.month + 12,
            _selectedDueDate.day,
          );
        }
      });
    }
  }

  Future<void> _pickRepeatUntilDate() async {
    final picked = await _showExpensesDatePicker(
      context: context,
      initialDate: _repeatUntilDate.isBefore(_selectedDueDate)
          ? _selectedDueDate
          : _repeatUntilDate,
      firstDate: _selectedDueDate,
      lastDate: DateTime(2100),
      helpText: 'Seleziona fine periodo',
    );

    if (picked != null) {
      setState(() {
        _repeatUntilDate = picked;
      });
    }
  }

  Future<void> _pickMonth() async {
    final picked = await _showExpensesDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Seleziona mese budget',
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  void _showError(String message) {
    final colors = _ExpensesColors.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: TextStyle(
            color: colors.isDark ? const Color(0xFF0F172A) : Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isPlanned &&
        _repeatMonthly &&
        _repeatUntilDate.isBefore(_selectedDueDate)) {
      _showError(
        'La data di fine rata deve essere successiva alla prima scadenza.',
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final amount = double.parse(
        _amountController.text.replaceAll(',', '.'),
      );

      final typeValue = _isPlanned ? 'planned' : 'standard';

      if (_isEditMode) {
        await widget.financeService.updateExpense(
          expenseId: widget.expenseDoc!.id,
          title: _titleController.text.trim(),
          amount: amount,
          dueDate: _isPlanned ? null : _selectedDueDate,
          category: _categoryController.text.trim(),
          isPaid: _isPlanned ? false : _isPaid,
          reminderEnabled: _isPlanned ? false : _reminderEnabled,
          type: typeValue,
          month: _isPlanned ? _selectedMonth : null,
          bankAccountId:
              !_isPlanned && _isPaid ? _selectedBankAccountId : null,
          bankAccountName:
              !_isPlanned && _isPaid ? _selectedBankAccountName() : null,
        );
      } else {
        if (!_isPlanned && _repeatMonthly) {
          final dueDates = _monthlyDueDates(
            startDate: _selectedDueDate,
            endDate: _repeatUntilDate,
          );

          for (final dueDate in dueDates) {
            await widget.financeService.addExpense(
              title: _titleController.text.trim(),
              amount: amount,
              dueDate: dueDate,
              category: _categoryController.text.trim(),
              isPaid: false,
              reminderEnabled: _reminderEnabled,
              type: typeValue,
              month: null,
            );
          }
        } else {
          await widget.financeService.addExpense(
            title: _titleController.text.trim(),
            amount: amount,
            dueDate: _isPlanned ? null : _selectedDueDate,
            category: _categoryController.text.trim(),
            isPaid: _isPlanned ? false : _isPaid,
            reminderEnabled: _isPlanned ? false : _reminderEnabled,
            type: typeValue,
            month: _isPlanned ? _selectedMonth : null,
            bankAccountId:
                !_isPlanned && _isPaid ? _selectedBankAccountId : null,
            bankAccountName:
                !_isPlanned && _isPaid ? _selectedBankAccountName() : null,
          );
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showError('Errore durante il salvataggio della spesa.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditMode ? 'Modifica spesa' : 'Nuova spesa';

    final repeatDatesCount = !_isPlanned && _repeatMonthly
        ? _monthlyDueDates(
            startDate: _selectedDueDate,
            endDate: _repeatUntilDate,
          ).length
        : 0;

    return _BaseFormSheet(
      title: title,
      loading: _loading,
      saveLabel: _isEditMode ? 'Aggiorna' : 'Salva',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _ExpenseTypeSelector(
              selectedType: _expenseType,
              onChanged: (type) {
                setState(() {
                  _expenseType = type;

                  if (_isPlanned) {
                    _isPaid = false;
                    _reminderEnabled = false;
                    _repeatMonthly = false;
                    _selectedBankAccountId = null;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            _TextInput(
              controller: _titleController,
              label: _isPlanned ? 'Nome budget' : 'Titolo',
              validatorText: _isPlanned
                  ? 'Inserisci il nome del budget'
                  : 'Inserisci il titolo',
            ),
            const SizedBox(height: 12),
            _TextInput(
              controller: _amountController,
              label: _isPlanned ? 'Budget previsto' : 'Importo',
              validatorText: _isPlanned
                  ? 'Inserisci il budget previsto'
                  : 'Inserisci l’importo',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            _TextInput(
              controller: _categoryController,
              label: 'Categoria',
              validatorText: 'Inserisci la categoria',
            ),
            const SizedBox(height: 12),
            if (_isPlanned)
              _DateButton(
                label: 'Mese budget',
                date: _selectedMonth,
                displayFormat: 'MMMM yyyy',
                onTap: _pickMonth,
              )
            else ...[
              _DateButton(
                label: 'Prima scadenza',
                date: _selectedDueDate,
                displayFormat: 'dd/MM/yyyy',
                onTap: _pickDueDate,
              ),
              const SizedBox(height: 10),
              _SwitchTile(
                title: 'Spesa già pagata',
                value: _isPaid,
                onChanged: _repeatMonthly
                    ? null
                    : (value) {
                        setState(() {
                          _isPaid = value;

                          if (!value) {
                            _selectedBankAccountId = null;
                          }
                        });
                      },
              ),
              if (_isPaid) ...[
                const SizedBox(height: 10),
                _ExpenseBankAccountDropdown(
                  bankAccounts: widget.bankAccounts,
                  selectedBankAccountId: _selectedBankAccountId,
                  onChanged: (value) {
                    setState(() {
                      _selectedBankAccountId = value;
                    });
                  },
                ),
              ],
              const SizedBox(height: 8),
              _SwitchTile(
                title: 'Promemoria attivo',
                value: _reminderEnabled,
                onChanged: (value) {
                  setState(() {
                    _reminderEnabled = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              _SwitchTile(
                title: 'Ripeti mensilmente',
                value: _repeatMonthly,
                onChanged: _isEditMode
                    ? null
                    : (value) {
                        setState(() {
                          _repeatMonthly = value;

                          if (value) {
                            _isPaid = false;
                            _selectedBankAccountId = null;

                            if (_repeatUntilDate.isBefore(_selectedDueDate)) {
                              _repeatUntilDate = DateTime(
                                _selectedDueDate.year,
                                _selectedDueDate.month + 12,
                                _selectedDueDate.day,
                              );
                            }
                          }
                        });
                      },
              ),
              if (_repeatMonthly) ...[
                const SizedBox(height: 10),
                _DateButton(
                  label: 'Fine rata / fine periodo',
                  date: _repeatUntilDate,
                  displayFormat: 'dd/MM/yyyy',
                  onTap: _pickRepeatUntilDate,
                ),
                const SizedBox(height: 10),
                _RecurringInfoBox(
                  count: repeatDatesCount,
                  startDate: _selectedDueDate,
                  endDate: _repeatUntilDate,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PayExpenseDialog extends StatefulWidget {
  final FinanceService financeService;
  final String expenseId;
  final String title;
  final double amount;
  final List<_ExpenseBankAccountItem> bankAccounts;

  const _PayExpenseDialog({
    required this.financeService,
    required this.expenseId,
    required this.title,
    required this.amount,
    required this.bankAccounts,
  });

  @override
  State<_PayExpenseDialog> createState() => _PayExpenseDialogState();
}

class _PayExpenseDialogState extends State<_PayExpenseDialog> {
  String? _selectedBankAccountId;
  bool _loading = false;

  String? _selectedBankAccountName() {
    if (_selectedBankAccountId == null) return null;

    for (final account in widget.bankAccounts) {
      if (account.id == _selectedBankAccountId) {
        return account.name;
      }
    }

    return null;
  }

  Future<void> _save() async {
    setState(() => _loading = true);

    await widget.financeService.updateExpensePaid(
      expenseId: widget.expenseId,
      isPaid: true,
      bankAccountId: _selectedBankAccountId,
      bankAccountName: _selectedBankAccountName(),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);
    final formattedAmount = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
    ).format(widget.amount);

    return _BaseFormSheet(
      title: 'Segna come pagata',
      loading: _loading,
      saveLabel: 'Conferma',
      onSave: _save,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.isDark
                  ? const Color(0xFF052E16)
                  : const Color(0xFFEAF8EF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              '${widget.title}\nImporto: $formattedAmount',
              style: TextStyle(
                color: colors.isDark
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFF166534),
                fontWeight: FontWeight.w900,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ExpenseBankAccountDropdown(
            bankAccounts: widget.bankAccounts,
            selectedBankAccountId: _selectedBankAccountId,
            onChanged: (value) {
              setState(() {
                _selectedBankAccountId = value;
              });
            },
          ),
        ],
      ),
    );
  }
}

class _RecurringInfoBox extends StatelessWidget {
  final int count;
  final DateTime startDate;
  final DateTime endDate;

  const _RecurringInfoBox({
    required this.count,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);
    final formatter = DateFormat('dd/MM/yyyy', 'it_IT');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.repeat_rounded,
            color: colors.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Verranno create $count rate mensili, dalla scadenza ${formatter.format(startDate)} fino al ${formatter.format(endDate)}.',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTypeSelector extends StatelessWidget {
  final ExpenseType selectedType;
  final ValueChanged<ExpenseType> onChanged;

  const _ExpenseTypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);
    final isStandard = selectedType == ExpenseType.standard;
    final isPlanned = selectedType == ExpenseType.planned;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
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
            child: _TypeButton(
              label: 'Spesa normale',
              icon: Icons.receipt_long_rounded,
              selected: isStandard,
              onTap: () => onChanged(ExpenseType.standard),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _TypeButton(
              label: 'Budget mensile',
              icon: Icons.account_balance_wallet_rounded,
              selected: isPlanned,
              onTap: () => onChanged(ExpenseType.planned),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 46,
      decoration: BoxDecoration(
        color: selected ? colors.card : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: colors.shadow.withValues(
                    alpha: colors.isDark ? 0.18 : 0.04,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? colors.textPrimary : colors.textSecondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetMovementDialog extends StatefulWidget {
  final String title;
  final double remainingAmount;
  final FinanceService financeService;
  final String expenseId;
  final List<_ExpenseBankAccountItem> bankAccounts;

  const _BudgetMovementDialog({
    required this.title,
    required this.remainingAmount,
    required this.financeService,
    required this.expenseId,
    required this.bankAccounts,
  });

  @override
  State<_BudgetMovementDialog> createState() => _BudgetMovementDialogState();
}

class _BudgetMovementDialogState extends State<_BudgetMovementDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedBankAccountId;
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String? _selectedBankAccountName() {
    if (_selectedBankAccountId == null) return null;

    for (final account in widget.bankAccounts) {
      if (account.id == _selectedBankAccountId) {
        return account.name;
      }
    }

    return null;
  }

  Future<void> _pickDate() async {
    final picked = await _showExpensesDatePicker(
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

    final amount = double.parse(
      _amountController.text.replaceAll(',', '.'),
    );

    await widget.financeService.addExpenseSplitPayment(
      expenseId: widget.expenseId,
      title: _titleController.text.trim(),
      amount: amount,
      paidAt: _selectedDate,
      bankAccountId: _selectedBankAccountId,
      bankAccountName: _selectedBankAccountName(),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);
    final formattedRemaining = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
    ).format(widget.remainingAmount);

    return _BaseFormSheet(
      title: 'Aggiungi uscita',
      loading: _loading,
      saveLabel: 'Aggiungi',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.primarySoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '${widget.title}\nResiduo attuale: $formattedRemaining',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _TextInput(
              controller: _titleController,
              label: 'Descrizione uscita',
              validatorText: 'Inserisci una descrizione',
            ),
            const SizedBox(height: 12),
            _TextInput(
              controller: _amountController,
              label: 'Importo speso',
              validatorText: 'Inserisci l’importo',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            _ExpenseBankAccountDropdown(
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
              label: 'Data uscita',
              date: _selectedDate,
              displayFormat: 'dd/MM/yyyy',
              onTap: _pickDate,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseBankAccountDropdown extends StatelessWidget {
  final List<_ExpenseBankAccountItem> bankAccounts;
  final String? selectedBankAccountId;
  final ValueChanged<String?> onChanged;

  const _ExpenseBankAccountDropdown({
    required this.bankAccounts,
    required this.selectedBankAccountId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);
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
      decoration: _expensesInputDecoration(
        context: context,
        label: 'Paga dal conto',
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(
            'Non scalare da nessun conto',
            style: TextStyle(
              color: colors.textPrimary,
            ),
          ),
        ),
        ...bankAccounts.map((account) {
          return DropdownMenuItem<String?>(
            value: account.id,
            child: Text(
              '${account.name} · ${formatter.format(account.balance)}',
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
    final colors = _ExpensesColors.of(context);
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

  const _TextInput({
    required this.controller,
    required this.label,
    required this.validatorText,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: _expensesInputDecoration(
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
                const TextInputType.numberWithOptions(decimal: true);

        if (isNumberKeyboard) {
          final parsed = double.tryParse(value.replaceAll(',', '.'));

          if (parsed == null) {
            return 'Inserisci un numero valido';
          }

          if (parsed <= 0) {
            return 'Inserisci un importo maggiore di zero';
          }
        }

        return null;
      },
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final String displayFormat;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.date,
    required this.displayFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);
    final formattedDate = DateFormat(displayFormat, 'it_IT').format(date);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: _expensesInputDecoration(
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

class _SwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ExpensesColors.of(context);
    final disabled = onChanged == null;

    return Container(
      padding: const EdgeInsets.only(left: 14, right: 8),
      decoration: BoxDecoration(
        color: disabled ? colors.cardSofter : colors.cardSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.border,
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: disabled ? colors.textMuted : colors.textPrimary,
          ),
        ),
        activeColor: colors.primary,
      ),
    );
  }
}