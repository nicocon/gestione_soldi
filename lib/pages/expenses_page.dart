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

  Color _deadlineColor(DateTime dueDate, bool isPaid) {
    if (isPaid) return const Color(0xFF16A34A);

    final today = DateTime.now();
    final currentDate = DateTime(today.year, today.month, today.day);
    final targetDate = DateTime(dueDate.year, dueDate.month, dueDate.day);

    final diff = targetDate.difference(currentDate).inDays;

    if (diff < 0) return const Color(0xFFDC2626);
    if (diff <= 3) return const Color(0xFFF59E0B);

    return const Color(0xFF2563EB);
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
  }) async {
    await _showResponsiveSheet(
      maxDesktopWidth: 520,
      child: _ExpenseFormDialog(
        financeService: _financeService,
        expenseDoc: doc,
      ),
    );
  }

  Future<void> _showAddBudgetMovementDialog({
    required String expenseId,
    required String title,
    required double remainingAmount,
  }) async {
    await _showResponsiveSheet(
      maxDesktopWidth: 480,
      child: _BudgetMovementDialog(
        title: title,
        remainingAmount: remainingAmount,
        financeService: _financeService,
        expenseId: expenseId,
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Eliminare spesa?',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF172033),
            ),
          ),
          content: Text(
            'Vuoi davvero eliminare "$title"? Questa azione non può essere annullata.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
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
    required bool currentValue,
  }) async {
    await _financeService.updateExpensePaid(
      expenseId: expenseId,
      isPaid: !currentValue,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _financeService.expensesStream(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final monthDocs = _docsBySelectedMonth(docs);
          final filteredDocs = _filteredDocs(docs);

          final totalAllExpected = _sumAllExpected(monthDocs);
          final totalUnpaidStandard = _sumUnpaidStandard(monthDocs);
          final totalPlannedRemaining = _sumPlannedRemaining(monthDocs);
          final unpaidCount = _unpaidStandardCount(monthDocs);

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
                          plannedRemaining: _currencyFormatter.format(
                            totalPlannedRemaining,
                          ),
                          unpaidCount: unpaidCount,
                          onAddExpense: () => _showExpenseDialog(),
                        ),
                        SizedBox(height: isMobile ? 14 : 18),
                        _MonthSelector(
                          selectedMonth: _selectedMonth,
                          monthFormatter: _monthFormatter,
                          onPrevious: _goToPreviousMonth,
                          onNext: _goToNextMonth,
                          onCurrentMonth: _goToCurrentMonth,
                        ),
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
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (filteredDocs.isEmpty)
                          const _EmptyExpenses()
                        else
                          Column(
                            children: filteredDocs.map((doc) {
                              final data = doc.data();

                              final title = data['title'] ?? 'Spesa';
                              final category = data['category'] ?? 'Generale';

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

                              return _ExpenseCard(
                                title: title.toString(),
                                category: category.toString(),
                                amount: _currencyFormatter.format(amount),
                                dueDate: _dateFormatter.format(dueDate),
                                monthLabel: _monthFormatter.format(monthDate),
                                deadlineLabel: _deadlineLabel(
                                  dueDate,
                                  isPaid,
                                ),
                                deadlineColor: _deadlineColor(
                                  dueDate,
                                  isPaid,
                                ),
                                isPaid: isPaid,
                                isPlanned: isPlanned,
                                reminderEnabled: reminderEnabled,
                                spentAmount: _currencyFormatter.format(spent),
                                remainingAmount: _currencyFormatter.format(
                                  remaining,
                                ),
                                rawRemainingAmount: remaining,
                                splitItems: splitItems,
                                currencyFormatter: _currencyFormatter,
                                dateFormatter: _dateFormatter,
                                onTogglePaid: () => _togglePaid(
                                  expenseId: doc.id,
                                  currentValue: isPaid,
                                ),
                                onEdit: () => _showExpenseDialog(doc: doc),
                                onDelete: () => _confirmDelete(
                                  expenseId: doc.id,
                                  title: title.toString(),
                                ),
                                onAddBudgetMovement: () =>
                                    _showAddBudgetMovementDialog(
                                  expenseId: doc.id,
                                  title: title.toString(),
                                  remainingAmount: remaining,
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
      ),
    );
  }
}

class _ExpensesHeader extends StatelessWidget {
  final String totalAll;
  final String totalUnpaid;
  final String plannedRemaining;
  final int unpaidCount;
  final VoidCallback onAddExpense;

  const _ExpensesHeader({
    required this.totalAll,
    required this.totalUnpaid,
    required this.plannedRemaining,
    required this.unpaidCount,
    required this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 22 : 28),
      decoration: BoxDecoration(
        color: const Color(0xFF172033),
        borderRadius: BorderRadius.circular(isMobile ? 26 : 30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
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
                  plannedRemaining: plannedRemaining,
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
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF172033),
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
                      plannedRemaining: plannedRemaining,
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
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF172033),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestione spese',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 27 : 32,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Gestisci le spese con scadenza e i budget mensili che consumi poco alla volta.',
          style: TextStyle(
            color: const Color(0xFFD7DEE9),
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
  final String plannedRemaining;
  final int unpaidCount;
  final bool isMobile;

  const _HeaderStatsGrid({
    required this.totalAll,
    required this.totalUnpaid,
    required this.plannedRemaining,
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
        label: 'Residuo budget',
        value: plannedRemaining,
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
            style: const TextStyle(
              color: Color(0xFFD7DEE9),
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
              color: Colors.white,
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
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    final label = monthFormatter.format(selectedMonth);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 24 : 26),
        border: Border.all(
          color: const Color(0xFFE5ECF5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
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
                    _MonthArrowButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: onPrevious,
                    ),
                    Expanded(
                      child: Text(
                        label.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF172033),
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
                      foregroundColor: const Color(0xFF1677F2),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      side: const BorderSide(
                        color: Color(0xFFE5ECF5),
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
                    style: const TextStyle(
                      color: Color(0xFF172033),
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
                      foregroundColor: const Color(0xFF1677F2),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      side: const BorderSide(
                        color: Color(0xFFE5ECF5),
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
    return Material(
      color: const Color(0xFFE3F2FD),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: const Color(0xFF1565C0),
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
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 24 : 999),
        border: Border.all(
          color: const Color(0xFFE5ECF5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 42,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE3F2FD) : Colors.transparent,
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
              color:
                  selected ? const Color(0xFF1565C0) : const Color(0xFF4B5563),
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
  final bool isPaid;
  final bool isPlanned;
  final bool reminderEnabled;
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
    required this.isPaid,
    required this.isPlanned,
    required this.reminderEnabled,
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

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.all(isMobile ? 16 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE5ECF5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isMobile ? _mobileLayout() : _desktopLayout(),
    );
  }

  Widget _mobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _topMobile(),
        const SizedBox(height: 14),
        if (isPlanned) ...[
          _plannedInfo(),
          const SizedBox(height: 14),
          _budgetProgress(),
          const SizedBox(height: 14),
          _budgetMovements(),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: onAddBudgetMovement,
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Aggiungi uscita'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1677F2),
                foregroundColor: Colors.white,
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
          _standardInfo(),
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
                    isPaid ? const Color(0xFF172033) : const Color(0xFF16A34A),
                side: BorderSide(
                  color: isPaid
                      ? const Color(0xFFE5ECF5)
                      : const Color(0xFF16A34A),
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

  Widget _desktopLayout() {
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
              child:
                  isPlanned ? _plannedDesktopContent() : _standardDesktopContent(),
            ),
            const SizedBox(width: 14),
            _actionsDesktop(),
          ],
        ),
        if (isPlanned) ...[
          const SizedBox(height: 16),
          _budgetProgress(),
          const SizedBox(height: 12),
          _budgetMovements(),
        ],
      ],
    );
  }

  Widget _topMobile() {
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF172033),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isPlanned ? 'Budget: $amount' : amount,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E88E5),
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: Text('Modifica'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text('Elimina'),
            ),
          ],
          icon: const Icon(Icons.more_vert_rounded),
        ),
      ],
    );
  }

  Widget _standardDesktopContent() {
    return Wrap(
      runSpacing: 8,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF172033),
                ),
              ),
            ),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF172033),
              ),
            ),
          ],
        ),
        _standardInfo(),
      ],
    );
  }

  Widget _plannedDesktopContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF172033),
                ),
              ),
            ),
            Text(
              'Budget: $amount',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF172033),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _plannedInfo(),
      ],
    );
  }

  Widget _standardInfo() {
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
        if (reminderEnabled)
          const _InfoBadge(
            text: 'Promemoria',
            icon: Icons.notifications_active_rounded,
          ),
      ],
    );
  }

  Widget _plannedInfo() {
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
        const _ColoredBadge(
          text: 'Budget mensile',
          color: Color(0xFF7C3AED),
        ),
        _InfoBadge(
          text: 'Speso: $spentAmount',
          icon: Icons.payments_rounded,
        ),
        _InfoBadge(
          text: 'Residuo: $remainingAmount',
          icon: Icons.savings_rounded,
        ),
      ],
    );
  }

  Widget _actionsDesktop() {
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
              backgroundColor: const Color(0xFF1677F2),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          IconButton(
            tooltip: 'Modifica',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Elimina',
            onPressed: onDelete,
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
        ),
        IconButton(
          tooltip: 'Modifica',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Elimina',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );
  }

  Widget _budgetProgress() {
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5ECF5),
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
                  label: isOverBudget ? 'Superato' : 'Residuo',
                  value: isOverBudget
                      ? currencyFormatter.format(numericSpent - numericTotal)
                      : remainingText,
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
              backgroundColor: const Color(0xFFE5ECF5),
              color: isOverBudget
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF1677F2),
            ),
          ),
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

  Widget _budgetMovements() {
    if (splitItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFDE68A),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFF59E0B),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ancora nessuna uscita registrata per questo budget.',
                style: TextStyle(
                  color: Color(0xFF92400E),
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
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5ECF5),
        ),
      ),
      child: Column(
        children: List.generate(splitItems.length, (index) {
          final item = splitItems[index];

          final itemTitle = item['title']?.toString().trim();
          final amountValue = item['amount'];
          final paidAtRaw = item['paid_at'];

          final paidAt = paidAtRaw is Timestamp
              ? paidAtRaw.toDate()
              : paidAtRaw is DateTime
                  ? paidAtRaw
                  : DateTime.now();

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
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    size: 20,
                    color: Color(0xFF1677F2),
                  ),
                ),
                title: Text(
                  itemTitle == null || itemTitle.isEmpty
                      ? 'Uscita budget'
                      : itemTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF172033),
                  ),
                ),
                subtitle: Text(
                  dateFormatter.format(paidAt),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currencyFormatter.format(_readMovementAmount(amountValue)),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF172033),
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
                const Divider(
                  height: 1,
                  color: Color(0xFFE5ECF5),
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
    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF172033),
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
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
    final bgColor = isPlanned
        ? const Color(0xFFF3E8FF)
        : isPaid
            ? const Color(0xFFEAF8EF)
            : const Color(0xFFE3F2FD);

    final iconColor = isPlanned
        ? const Color(0xFF7C3AED)
        : isPaid
            ? const Color(0xFF16A34A)
            : const Color(0xFF1E88E5);

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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: const Color(0xFF64748B),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF64748B),
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFE5ECF5),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 44,
            color: Color(0xFF94A3B8),
          ),
          SizedBox(height: 14),
          Text(
            'Nessuna spesa trovata',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF172033),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Aggiungi una nuova spesa oppure cambia filtro.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
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

  const _ExpenseFormDialog({
    required this.financeService,
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
  late bool _isPaid;
  late bool _reminderEnabled;
  late ExpenseType _expenseType;

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

    _titleController = TextEditingController(text: title.toString());

    _amountController = TextEditingController(
      text: _isEditMode ? amount.toStringAsFixed(2).replaceAll('.', ',') : '',
    );

    _categoryController = TextEditingController(text: category.toString());

    _selectedDueDate = dueDate;
    _selectedMonth = DateTime(monthDate.year, monthDate.month);

    _isPaid = data?['is_paid'] == true;

    _reminderEnabled = _isEditMode ? (data?['reminder_enabled'] == true) : true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

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
      );
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
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditMode ? 'Modifica spesa' : 'Nuova spesa';

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
                label: 'Data scadenza',
                date: _selectedDueDate,
                displayFormat: 'dd/MM/yyyy',
                onTap: _pickDueDate,
              ),
              const SizedBox(height: 10),
              _SwitchTile(
                title: 'Spesa già pagata',
                value: _isPaid,
                onChanged: (value) {
                  setState(() {
                    _isPaid = value;
                  });
                },
              ),
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
            ],
          ],
        ),
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
    final isStandard = selectedType == ExpenseType.standard;
    final isPlanned = selectedType == ExpenseType.planned;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5ECF5),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 46,
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
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
              color:
                  selected ? const Color(0xFF1677F2) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF172033)
                      : const Color(0xFF64748B),
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

  const _BudgetMovementDialog({
    required this.title,
    required this.remainingAmount,
    required this.financeService,
    required this.expenseId,
  });

  @override
  State<_BudgetMovementDialog> createState() => _BudgetMovementDialogState();
}

class _BudgetMovementDialogState extends State<_BudgetMovementDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
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
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '${widget.title}\nResiduo attuale: $formattedRemaining',
                style: const TextStyle(
                  color: Color(0xFF1565C0),
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
          color: Colors.white,
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
                      color: const Color(0xFFD7DEE9),
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
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF172033),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: loading ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
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
                            foregroundColor: const Color(0xFF172033),
                            side: const BorderSide(
                              color: Color(0xFFE5ECF5),
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
                            backgroundColor: const Color(0xFF1677F2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
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
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7FAFE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE5ECF5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE5ECF5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF1677F2),
            width: 1.5,
          ),
        ),
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
    final formattedDate = DateFormat(displayFormat, 'it_IT').format(date);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF7FAFE),
          suffixIcon: const Icon(Icons.calendar_month_rounded),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFFE5ECF5),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFFE5ECF5),
            ),
          ),
        ),
        child: Text(
          formattedDate,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF172033),
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5ECF5),
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF172033),
          ),
        ),
        activeColor: const Color(0xFF1677F2),
      ),
    );
  }
}