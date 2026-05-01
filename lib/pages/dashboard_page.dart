import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/finance_service.dart';

enum DashboardExpenseType {
  standard,
  planned,
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AuthService _authService = AuthService();
  final FinanceService _financeService = FinanceService();

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
  );

  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy', 'it_IT');
  final DateFormat _monthFormatter = DateFormat('MMMM yyyy', 'it_IT');
  final DateFormat _shortMonthFormatter = DateFormat('MMM', 'it_IT');

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _financeService.updateWatchSummary();
        debugPrint('WATCH SUMMARY AGGIORNATO');
      } catch (e) {
        debugPrint('ERRORE WATCH SUMMARY: $e');
      }
    });
  }

  double _amountFrom(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0;
  }

  bool _sameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  DateTime get _currentMonth {
    final now = DateTime.now();

    return DateTime(now.year, now.month);
  }

  DateTime get _previousMonth {
    final now = DateTime.now();

    return DateTime(now.year, now.month - 1);
  }

  List<DateTime> _lastMonths({
    int count = 6,
  }) {
    final now = _currentMonth;

    return List.generate(count, (index) {
      final diff = count - 1 - index;

      return DateTime(now.year, now.month - diff);
    });
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

  double _sumIncomesForMonth(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
    DateTime month,
  ) {
    if (snapshot == null) return 0;

    double total = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final rawDate = data['date'];

      if (rawDate is! Timestamp) continue;

      final date = rawDate.toDate();

      if (_sameMonth(date, month)) {
        total += _amountFrom(data['amount']);
      }
    }

    return total;
  }

  double _sumExpensesForMonth(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
    DateTime month,
  ) {
    if (snapshot == null) return 0;

    double total = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      if (_isPlannedExpense(data)) {
        final splitItems = _splitItemsFrom(data['split_items']);

        for (final item in splitItems) {
          final rawPaidAt = item['paid_at'];

          if (rawPaidAt is! Timestamp) continue;

          final paidAt = rawPaidAt.toDate();

          if (_sameMonth(paidAt, month)) {
            total += _amountFrom(item['amount']);
          }
        }

        continue;
      }

      final rawDueDate = data['due_date'];

      if (rawDueDate is! Timestamp) continue;

      final dueDate = rawDueDate.toDate();

      if (_sameMonth(dueDate, month)) {
        total += _amountFrom(data['amount']);
      }
    }

    return total;
  }

  double _sumPlannedBudgetExpectedForMonth(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
    DateTime month,
  ) {
    if (snapshot == null) return 0;

    double total = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      if (!_isPlannedExpense(data)) continue;

      final rawMonth = data['month'];

      if (rawMonth is! Timestamp) continue;

      final budgetMonth = rawMonth.toDate();

      if (_sameMonth(budgetMonth, month)) {
        total += _amountFrom(data['amount']);
      }
    }

    return total;
  }

  int _countMonthlyExpenses(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
    DateTime month,
  ) {
    if (snapshot == null) return 0;

    int count = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      if (_isPlannedExpense(data)) {
        final splitItems = _splitItemsFrom(data['split_items']);

        for (final item in splitItems) {
          final rawPaidAt = item['paid_at'];

          if (rawPaidAt is! Timestamp) continue;

          if (_sameMonth(rawPaidAt.toDate(), month)) {
            count++;
          }
        }

        continue;
      }

      final rawDueDate = data['due_date'];

      if (rawDueDate is Timestamp && _sameMonth(rawDueDate.toDate(), month)) {
        count++;
      }
    }

    return count;
  }

  List<_MonthlySummaryItem> _monthlySummaries(
    QuerySnapshot<Map<String, dynamic>>? incomesSnapshot,
    QuerySnapshot<Map<String, dynamic>>? expensesSnapshot,
    List<DateTime> months,
  ) {
    return months.map((month) {
      final incomes = _sumIncomesForMonth(incomesSnapshot, month);
      final expenses = _sumExpensesForMonth(expensesSnapshot, month);

      return _MonthlySummaryItem(
        month: month,
        monthLabel: _monthFormatter.format(month),
        shortMonthLabel: _shortMonthFormatter.format(month),
        incomes: incomes,
        expenses: expenses,
        balance: incomes - expenses,
      );
    }).toList();
  }

  double _averagePastExpenses(List<_MonthlySummaryItem> summaries) {
    if (summaries.length <= 1) return 0;

    final pastMonths = summaries.take(summaries.length - 1).toList();

    if (pastMonths.isEmpty) return 0;

    final total = pastMonths.fold<double>(
      0,
      (sum, item) => sum + item.expenses,
    );

    return total / pastMonths.length;
  }

  List<_ExpensePreviewItem> _expensePreviewItemsForCurrentMonth(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    if (snapshot == null) return [];

    final List<_ExpensePreviewItem> items = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final title = (data['title'] ?? 'Spesa').toString();
      final category = (data['category'] ?? 'Generale').toString();

      if (_isPlannedExpense(data)) {
        final splitItems = _splitItemsFrom(data['split_items']);

        for (final item in splitItems) {
          final rawPaidAt = item['paid_at'];

          if (rawPaidAt is! Timestamp) continue;

          final paidAt = rawPaidAt.toDate();

          if (!_sameMonth(paidAt, _currentMonth)) continue;

          final itemTitle = (item['title'] ?? '').toString().trim();

          items.add(
            _ExpensePreviewItem(
              title: itemTitle.isEmpty ? title : itemTitle,
              subtitle: '$title • Budget mensile',
              amount: _amountFrom(item['amount']),
              date: paidAt,
              isPlanned: true,
            ),
          );
        }

        continue;
      }

      final rawDueDate = data['due_date'];

      if (rawDueDate is! Timestamp) continue;

      final dueDate = rawDueDate.toDate();

      if (!_sameMonth(dueDate, _currentMonth)) continue;

      final isPaid = data['is_paid'] == true;

      items.add(
        _ExpensePreviewItem(
          title: title,
          subtitle: '$category • ${isPaid ? 'Pagata' : 'Da pagare'}',
          amount: _amountFrom(data['amount']),
          date: dueDate,
          isPlanned: false,
        ),
      );
    }

    items.sort((a, b) => b.date.compareTo(a.date));

    return items.take(6).toList();
  }

  Future<void> _showAddIncomeDialog() async {
    await _showResponsiveSheet(
      child: _AddIncomeDialog(
        financeService: _financeService,
      ),
    );
  }

  Future<void> _showAddExpenseDialog() async {
    await _showResponsiveSheet(
      child: _AddExpenseDialog(
        financeService: _financeService,
      ),
    );
  }

  Future<void> _showAddGoalDialog() async {
    await _showResponsiveSheet(
      child: _AddGoalDialog(
        financeService: _financeService,
      ),
    );
  }

  Future<void> _showResponsiveSheet({
    required Widget child,
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
          constraints: const BoxConstraints(maxWidth: 500),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Utente non trovato'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          final userData = userSnapshot.data?.data();
          final name = userData?['name'] ?? user.displayName ?? 'utente';

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _financeService.incomesStream(),
            builder: (context, incomesSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _financeService.expensesStream(),
                builder: (context, expensesSnapshot) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _financeService.goalsStream(),
                    builder: (context, goalsSnapshot) {
                      final incomesDocs = incomesSnapshot.data;
                      final expensesDocs = expensesSnapshot.data;
                      final goalsDocs = goalsSnapshot.data;

                      final currentMonth = _currentMonth;
                      final previousMonth = _previousMonth;

                      final months = _lastMonths(count: 6);

                      final monthlySummaries = _monthlySummaries(
                        incomesDocs,
                        expensesDocs,
                        months,
                      );

                      final currentMonthIncomes = _sumIncomesForMonth(
                        incomesDocs,
                        currentMonth,
                      );

                      final previousMonthIncomes = _sumIncomesForMonth(
                        incomesDocs,
                        previousMonth,
                      );

                      final currentMonthExpenses = _sumExpensesForMonth(
                        expensesDocs,
                        currentMonth,
                      );

                      final previousMonthExpenses = _sumExpensesForMonth(
                        expensesDocs,
                        previousMonth,
                      );

                      final averagePastExpenses =
                          _averagePastExpenses(monthlySummaries);

                      final currentMonthBudgetExpected =
                          _sumPlannedBudgetExpectedForMonth(
                        expensesDocs,
                        currentMonth,
                      );

                      final currentMonthBalance =
                          currentMonthIncomes - currentMonthExpenses;

                      final previousMonthBalance =
                          previousMonthIncomes - previousMonthExpenses;

                      final expensesDifference =
                          currentMonthExpenses - previousMonthExpenses;

                      final expensesDifferencePercent =
                          previousMonthExpenses <= 0
                              ? null
                              : (expensesDifference / previousMonthExpenses) *
                                  100;

                      final activeGoals = goalsDocs?.docs.length ?? 0;

                      final expenseCountCurrentMonth = _countMonthlyExpenses(
                        expensesDocs,
                        currentMonth,
                      );

                      final currentMonthExpenseItems =
                          _expensePreviewItemsForCurrentMonth(expensesDocs);

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = constraints.maxWidth < 700;
                          final isWide = constraints.maxWidth >= 950;

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
                                constraints:
                                    const BoxConstraints(maxWidth: 1200),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _HeaderSection(
                                      name: name.toString(),
                                      currentMonthLabel:
                                          _monthFormatter.format(currentMonth),
                                      onAddIncome: _showAddIncomeDialog,
                                      onAddExpense: _showAddExpenseDialog,
                                      onAddGoal: _showAddGoalDialog,
                                    ),
                                    SizedBox(height: isMobile ? 18 : 24),
                                    _MonthlyInsightCard(
                                      currentMonthLabel:
                                          _monthFormatter.format(currentMonth),
                                      previousMonthLabel:
                                          _monthFormatter.format(previousMonth),
                                      currentMonthExpenses:
                                          currentMonthExpenses,
                                      previousMonthExpenses:
                                          previousMonthExpenses,
                                      averagePastExpenses: averagePastExpenses,
                                      expensesDifference: expensesDifference,
                                      expensesDifferencePercent:
                                          expensesDifferencePercent,
                                      currentMonthBalance:
                                          currentMonthBalance,
                                      previousMonthBalance:
                                          previousMonthBalance,
                                      currentMonthBudgetExpected:
                                          currentMonthBudgetExpected,
                                      currencyFormatter: _currencyFormatter,
                                    ),
                                    SizedBox(height: isMobile ? 18 : 24),
                                    _SummaryGrid(
                                      currentMonthIncomes: currentMonthIncomes,
                                      currentMonthExpenses:
                                          currentMonthExpenses,
                                      currentMonthBalance:
                                          currentMonthBalance,
                                      activeGoals: activeGoals,
                                      expenseCountCurrentMonth:
                                          expenseCountCurrentMonth,
                                      currencyFormatter: _currencyFormatter,
                                    ),
                                    SizedBox(height: isMobile ? 20 : 28),
                                    _MonthlyTrendChart(
                                      summaries: monthlySummaries,
                                      currencyFormatter: _currencyFormatter,
                                    ),
                                    SizedBox(height: isMobile ? 20 : 28),
                                    if (isWide)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _ExpensesList(
                                              items:
                                                  currentMonthExpenseItems,
                                              currencyFormatter:
                                                  _currencyFormatter,
                                              dateFormatter: _dateFormatter,
                                            ),
                                          ),
                                          const SizedBox(width: 18),
                                          Expanded(
                                            child: _GoalsList(
                                              snapshot: goalsDocs,
                                              currencyFormatter:
                                                  _currencyFormatter,
                                              dateFormatter: _dateFormatter,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Column(
                                        children: [
                                          _ExpensesList(
                                            items: currentMonthExpenseItems,
                                            currencyFormatter:
                                                _currencyFormatter,
                                            dateFormatter: _dateFormatter,
                                          ),
                                          const SizedBox(height: 18),
                                          _GoalsList(
                                            snapshot: goalsDocs,
                                            currencyFormatter:
                                                _currencyFormatter,
                                            dateFormatter: _dateFormatter,
                                          ),
                                        ],
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
              );
            },
          );
        },
      ),
    );
  }
}

class _MonthlySummaryItem {
  final DateTime month;
  final String monthLabel;
  final String shortMonthLabel;
  final double incomes;
  final double expenses;
  final double balance;

  const _MonthlySummaryItem({
    required this.month,
    required this.monthLabel,
    required this.shortMonthLabel,
    required this.incomes,
    required this.expenses,
    required this.balance,
  });
}

class _ExpensePreviewItem {
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;
  final bool isPlanned;

  const _ExpensePreviewItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.isPlanned,
  });
}

class _HeaderSection extends StatelessWidget {
  final String name;
  final String currentMonthLabel;
  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;
  final VoidCallback onAddGoal;

  const _HeaderSection({
    required this.name,
    required this.currentMonthLabel,
    required this.onAddIncome,
    required this.onAddExpense,
    required this.onAddGoal,
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
                _HeaderText(
                  name: name,
                  currentMonthLabel: currentMonthLabel,
                  isMobile: true,
                ),
                const SizedBox(height: 20),
                _HeaderActions(
                  onAddIncome: onAddIncome,
                  onAddExpense: onAddExpense,
                  onAddGoal: onAddGoal,
                  isMobile: true,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _HeaderText(
                    name: name,
                    currentMonthLabel: currentMonthLabel,
                    isMobile: false,
                  ),
                ),
                const SizedBox(width: 20),
                _HeaderActions(
                  onAddIncome: onAddIncome,
                  onAddExpense: onAddExpense,
                  onAddGoal: onAddGoal,
                  isMobile: false,
                ),
              ],
            ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String name;
  final String currentMonthLabel;
  final bool isMobile;

  const _HeaderText({
    required this.name,
    required this.currentMonthLabel,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ciao $name 👋',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 26 : 32,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Riepilogo di ${currentMonthLabel.toUpperCase()}: controlla entrate, spese reali, budget consumati e andamento degli ultimi mesi.',
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

class _HeaderActions extends StatelessWidget {
  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;
  final VoidCallback onAddGoal;
  final bool isMobile;

  const _HeaderActions({
    required this.onAddIncome,
    required this.onAddExpense,
    required this.onAddGoal,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: [
          _ActionButton(
            label: 'Aggiungi entrata',
            icon: Icons.add_rounded,
            onPressed: onAddIncome,
            fullWidth: true,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Spesa',
                  icon: Icons.remove_rounded,
                  onPressed: onAddExpense,
                  fullWidth: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'Obiettivo',
                  icon: Icons.flag_rounded,
                  onPressed: onAddGoal,
                  fullWidth: true,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        _ActionButton(
          label: 'Entrata',
          icon: Icons.add_rounded,
          onPressed: onAddIncome,
        ),
        _ActionButton(
          label: 'Spesa',
          icon: Icons.remove_rounded,
          onPressed: onAddExpense,
        ),
        _ActionButton(
          label: 'Obiettivo',
          icon: Icons.flag_rounded,
          onPressed: onAddGoal,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool fullWidth;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF172033),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MonthlyInsightCard extends StatelessWidget {
  final String currentMonthLabel;
  final String previousMonthLabel;
  final double currentMonthExpenses;
  final double previousMonthExpenses;
  final double averagePastExpenses;
  final double expensesDifference;
  final double? expensesDifferencePercent;
  final double currentMonthBalance;
  final double previousMonthBalance;
  final double currentMonthBudgetExpected;
  final NumberFormat currencyFormatter;

  const _MonthlyInsightCard({
    required this.currentMonthLabel,
    required this.previousMonthLabel,
    required this.currentMonthExpenses,
    required this.previousMonthExpenses,
    required this.averagePastExpenses,
    required this.expensesDifference,
    required this.expensesDifferencePercent,
    required this.currentMonthBalance,
    required this.previousMonthBalance,
    required this.currentMonthBudgetExpected,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    final isSpendingMore = expensesDifference > 0;
    final isSpendingLess = expensesDifference < 0;

    final averageDifference = currentMonthExpenses - averagePastExpenses;

    String comparisonText;

    if (previousMonthExpenses <= 0 && currentMonthExpenses > 0) {
      comparisonText =
          'Questo mese hai iniziato a registrare spese. Nei prossimi mesi il confronto diventerà sempre più preciso.';
    } else if (currentMonthExpenses <= 0 && previousMonthExpenses <= 0) {
      comparisonText =
          'Non ci sono ancora abbastanza spese registrate per creare un confronto utile.';
    } else if (isSpendingMore) {
      comparisonText =
          'Stai spendendo ${currencyFormatter.format(expensesDifference)} in più rispetto a $previousMonthLabel.';
    } else if (isSpendingLess) {
      comparisonText =
          'Stai spendendo ${currencyFormatter.format(expensesDifference.abs())} in meno rispetto a $previousMonthLabel.';
    } else {
      comparisonText =
          'Le spese sono stabili rispetto a $previousMonthLabel.';
    }

    if (averagePastExpenses > 0) {
      if (averageDifference > 0) {
        comparisonText +=
            ' Sei anche sopra la media degli ultimi mesi di ${currencyFormatter.format(averageDifference)}.';
      } else if (averageDifference < 0) {
        comparisonText +=
            ' Sei sotto la media degli ultimi mesi di ${currencyFormatter.format(averageDifference.abs())}.';
      } else {
        comparisonText += ' Sei perfettamente in linea con la media recente.';
      }
    }

    final percentText = expensesDifferencePercent == null
        ? 'N/D'
        : '${expensesDifferencePercent!.abs().toStringAsFixed(1)}%';

    final balanceDifference = currentMonthBalance - previousMonthBalance;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFE5ECF5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InsightHeader(
                  isSpendingMore: isSpendingMore,
                  isSpendingLess: isSpendingLess,
                ),
                const SizedBox(height: 16),
                Text(
                  comparisonText,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                _InsightStats(
                  currentMonthLabel: currentMonthLabel,
                  previousMonthLabel: previousMonthLabel,
                  currentMonthExpenses: currentMonthExpenses,
                  previousMonthExpenses: previousMonthExpenses,
                  averagePastExpenses: averagePastExpenses,
                  percentText: percentText,
                  balanceDifference: balanceDifference,
                  currentMonthBudgetExpected: currentMonthBudgetExpected,
                  currencyFormatter: currencyFormatter,
                  isMobile: true,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InsightHeader(
                        isSpendingMore: isSpendingMore,
                        isSpendingLess: isSpendingLess,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        comparisonText,
                        style: const TextStyle(
                          color: Color(0xFF172033),
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 460,
                  child: _InsightStats(
                    currentMonthLabel: currentMonthLabel,
                    previousMonthLabel: previousMonthLabel,
                    currentMonthExpenses: currentMonthExpenses,
                    previousMonthExpenses: previousMonthExpenses,
                    averagePastExpenses: averagePastExpenses,
                    percentText: percentText,
                    balanceDifference: balanceDifference,
                    currentMonthBudgetExpected: currentMonthBudgetExpected,
                    currencyFormatter: currencyFormatter,
                    isMobile: false,
                  ),
                ),
              ],
            ),
    );
  }
}

class _InsightHeader extends StatelessWidget {
  final bool isSpendingMore;
  final bool isSpendingLess;

  const _InsightHeader({
    required this.isSpendingMore,
    required this.isSpendingLess,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSpendingMore
        ? const Color(0xFFDC2626)
        : isSpendingLess
            ? const Color(0xFF16A34A)
            : const Color(0xFF1677F2);

    final icon = isSpendingMore
        ? Icons.trending_up_rounded
        : isSpendingLess
            ? Icons.trending_down_rounded
            : Icons.drag_handle_rounded;

    final title = isSpendingMore
        ? 'Spesa in aumento'
        : isSpendingLess
            ? 'Stai spendendo meno'
            : 'Spese stabili';

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF172033),
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightStats extends StatelessWidget {
  final String currentMonthLabel;
  final String previousMonthLabel;
  final double currentMonthExpenses;
  final double previousMonthExpenses;
  final double averagePastExpenses;
  final String percentText;
  final double balanceDifference;
  final double currentMonthBudgetExpected;
  final NumberFormat currencyFormatter;
  final bool isMobile;

  const _InsightStats({
    required this.currentMonthLabel,
    required this.previousMonthLabel,
    required this.currentMonthExpenses,
    required this.previousMonthExpenses,
    required this.averagePastExpenses,
    required this.percentText,
    required this.balanceDifference,
    required this.currentMonthBudgetExpected,
    required this.currencyFormatter,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _SmallInsightBox(
        label: currentMonthLabel,
        value: currencyFormatter.format(currentMonthExpenses),
      ),
      _SmallInsightBox(
        label: previousMonthLabel,
        value: currencyFormatter.format(previousMonthExpenses),
      ),
      _SmallInsightBox(
        label: 'Media mesi',
        value: currencyFormatter.format(averagePastExpenses),
      ),
      _SmallInsightBox(
        label: 'Variazione',
        value: percentText,
      ),
      _SmallInsightBox(
        label: 'Budget previsti',
        value: currencyFormatter.format(currentMonthBudgetExpected),
      ),
      _SmallInsightBox(
        label: 'Saldo vs mese scorso',
        value: currencyFormatter.format(balanceDifference),
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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: stats[4]),
              const SizedBox(width: 10),
              Expanded(child: stats[5]),
            ],
          ),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: stats,
    );
  }
}

class _SmallInsightBox extends StatelessWidget {
  final String label;
  final String value;

  const _SmallInsightBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: isMobile ? double.infinity : 145,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5ECF5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF172033),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final double currentMonthIncomes;
  final double currentMonthExpenses;
  final double currentMonthBalance;
  final int activeGoals;
  final int expenseCountCurrentMonth;
  final NumberFormat currencyFormatter;

  const _SummaryGrid({
    required this.currentMonthIncomes,
    required this.currentMonthExpenses,
    required this.currentMonthBalance,
    required this.activeGoals,
    required this.expenseCountCurrentMonth,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    final cards = [
      _SummaryCard(
        icon: Icons.trending_up_rounded,
        title: 'Entrate mese',
        value: currencyFormatter.format(currentMonthIncomes),
        subtitle: 'Entrate registrate nel mese',
      ),
      _SummaryCard(
        icon: Icons.trending_down_rounded,
        title: 'Spese mese',
        value: currencyFormatter.format(currentMonthExpenses),
        subtitle: '$expenseCountCurrentMonth movimenti conteggiati',
      ),
      _SummaryCard(
        icon: Icons.account_balance_wallet_rounded,
        title: 'Saldo mese',
        value: currencyFormatter.format(currentMonthBalance),
        subtitle: currentMonthBalance >= 0
            ? 'Situazione positiva'
            : 'Uscite superiori alle entrate',
      ),
      _SummaryCard(
        icon: Icons.flag_rounded,
        title: 'Obiettivi attivi',
        value: activeGoals.toString(),
        subtitle: 'Obiettivi di risparmio',
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards
            .map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: card,
              ),
            )
            .toList(),
      );
    }

    return Wrap(
      spacing: 18,
      runSpacing: 18,
      children: cards,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return SizedBox(
      width: isMobile ? double.infinity : 280,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 18 : 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE5ECF5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: isMobile
            ? Row(
                children: [
                  _SummaryIcon(icon: icon),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SummaryText(
                      title: title,
                      value: value,
                      subtitle: subtitle,
                      compact: true,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryIcon(icon: icon),
                  const SizedBox(height: 18),
                  _SummaryText(
                    title: title,
                    value: value,
                    subtitle: subtitle,
                    compact: false,
                  ),
                ],
              ),
      ),
    );
  }
}

class _SummaryIcon extends StatelessWidget {
  final IconData icon;

  const _SummaryIcon({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        icon,
        color: const Color(0xFF1E88E5),
        size: 28,
      ),
    );
  }
}

class _SummaryText extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final bool compact;

  const _SummaryText({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 22 : 25,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF172033),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF7C8798),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _MonthlyTrendChart extends StatelessWidget {
  final List<_MonthlySummaryItem> summaries;
  final NumberFormat currencyFormatter;

  const _MonthlyTrendChart({
    required this.summaries,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return _Panel(
      title: 'Andamento ultimi 6 mesi',
      icon: Icons.show_chart_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Asse X: mesi • Asse Y: importi in euro',
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),
          SizedBox(
            height: isMobile ? 260 : 320,
            width: double.infinity,
            child: CustomPaint(
              painter: _MonthlyTrendChartPainter(
                summaries: summaries,
                currencyFormatter: currencyFormatter,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _ChartLegend(
                label: 'Entrate',
                color: Color(0xFF16A34A),
              ),
              _ChartLegend(
                label: 'Spese',
                color: Color(0xFFDC2626),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyTrendChartPainter extends CustomPainter {
  final List<_MonthlySummaryItem> summaries;
  final NumberFormat currencyFormatter;

  _MonthlyTrendChartPainter({
    required this.summaries,
    required this.currencyFormatter,
  });

  static const Color _axisColor = Color(0xFFCBD5E1);
  static const Color _gridColor = Color(0xFFEAF0F7);
  static const Color _labelColor = Color(0xFF64748B);
  static const Color _incomeColor = Color(0xFF16A34A);
  static const Color _expenseColor = Color(0xFFDC2626);

  @override
  void paint(Canvas canvas, Size size) {
    if (summaries.isEmpty) return;

    final leftPadding = size.width < 420 ? 48.0 : 62.0;
    const topPadding = 18.0;
    const rightPadding = 18.0;
    const bottomPadding = 42.0;

    final chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );

    final rawMaxValue = summaries.fold<double>(1, (maxValue, item) {
      return math.max(maxValue, math.max(item.incomes, item.expenses));
    });

    final maxValue = _niceMaxValue(rawMaxValue);

    final axisPaint = Paint()
      ..color = _axisColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = _gridColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(chartRect.left, chartRect.top),
      Offset(chartRect.left, chartRect.bottom),
      axisPaint,
    );

    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );

    const gridLines = 4;

    for (int i = 0; i <= gridLines; i++) {
      final progress = i / gridLines;
      final y = chartRect.bottom - chartRect.height * progress;
      final value = maxValue * progress;

      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );

      _drawText(
        canvas: canvas,
        text: _compactCurrency(value),
        offset: Offset(0, y - 8),
        maxWidth: leftPadding - 8,
        color: _labelColor,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        textAlign: TextAlign.right,
      );
    }

    final incomePoints = _pointsFor(
      chartRect: chartRect,
      maxValue: maxValue,
      valueBuilder: (item) => item.incomes,
    );

    final expensePoints = _pointsFor(
      chartRect: chartRect,
      maxValue: maxValue,
      valueBuilder: (item) => item.expenses,
    );

    _drawLine(
      canvas: canvas,
      points: incomePoints,
      color: _incomeColor,
    );

    _drawLine(
      canvas: canvas,
      points: expensePoints,
      color: _expenseColor,
    );

    _drawPoints(
      canvas: canvas,
      points: incomePoints,
      color: _incomeColor,
    );

    _drawPoints(
      canvas: canvas,
      points: expensePoints,
      color: _expenseColor,
    );

    for (int i = 0; i < summaries.length; i++) {
      final x = summaries.length == 1
          ? chartRect.center.dx
          : chartRect.left + (chartRect.width / (summaries.length - 1)) * i;

      _drawText(
        canvas: canvas,
        text: summaries[i].shortMonthLabel.toUpperCase(),
        offset: Offset(x - 22, chartRect.bottom + 12),
        maxWidth: 44,
        color: _labelColor,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        textAlign: TextAlign.center,
      );
    }
  }

  List<Offset> _pointsFor({
    required Rect chartRect,
    required double maxValue,
    required double Function(_MonthlySummaryItem item) valueBuilder,
  }) {
    return List.generate(summaries.length, (index) {
      final item = summaries[index];

      final x = summaries.length == 1
          ? chartRect.center.dx
          : chartRect.left +
              (chartRect.width / (summaries.length - 1)) * index;

      final normalizedValue = maxValue <= 0
          ? 0.0
          : (valueBuilder(item) / maxValue).clamp(0.0, 1.0);

      final y = chartRect.bottom - chartRect.height * normalizedValue;

      return Offset(x, y);
    });
  }

  void _drawLine({
    required Canvas canvas,
    required List<Offset> points,
    required Color color,
  }) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  void _drawPoints({
    required Canvas canvas,
    required List<Offset> points,
    required Color color,
  }) {
    final outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 5.5, outerPaint);
      canvas.drawCircle(point, 3.5, innerPaint);
    }
  }

  void _drawText({
    required Canvas canvas,
    required String text,
    required Offset offset,
    required double maxWidth,
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    TextAlign textAlign = TextAlign.left,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: textAlign,
      maxLines: 1,
      ellipsis: '…',
    );

    textPainter.layout(maxWidth: maxWidth);
    textPainter.paint(canvas, offset);
  }

  double _niceMaxValue(double value) {
    if (value <= 100) return 100;

    final magnitude = math.pow(10, value.toInt().toString().length - 1);
    final normalized = value / magnitude;

    double niceNormalized;

    if (normalized <= 1) {
      niceNormalized = 1;
    } else if (normalized <= 2) {
      niceNormalized = 2;
    } else if (normalized <= 5) {
      niceNormalized = 5;
    } else {
      niceNormalized = 10;
    }

    return niceNormalized * magnitude;
  }

  String _compactCurrency(double value) {
    if (value >= 1000000) {
      return '€${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '€${(value / 1000).toStringAsFixed(1)}k';
    }

    return currencyFormatter.format(value).replaceAll(',00', '');
  }

  @override
  bool shouldRepaint(covariant _MonthlyTrendChartPainter oldDelegate) {
    return oldDelegate.summaries != summaries;
  }
}

class _ChartLegend extends StatelessWidget {
  final String label;
  final Color color;

  const _ChartLegend({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ExpensesList extends StatelessWidget {
  final List<_ExpensePreviewItem> items;
  final NumberFormat currencyFormatter;
  final DateFormat dateFormatter;

  const _ExpensesList({
    required this.items,
    required this.currencyFormatter,
    required this.dateFormatter,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Ultime spese del mese',
      icon: Icons.receipt_long_rounded,
      child: items.isEmpty
          ? const _EmptyState(text: 'Nessuna spesa registrata questo mese.')
          : Column(
              children: items.map((item) {
                return _ListRow(
                  title: item.title,
                  subtitle:
                      '${item.subtitle} • ${dateFormatter.format(item.date)}',
                  trailing: currencyFormatter.format(item.amount),
                );
              }).toList(),
            ),
    );
  }
}

class _GoalsList extends StatelessWidget {
  final QuerySnapshot<Map<String, dynamic>>? snapshot;
  final NumberFormat currencyFormatter;
  final DateFormat dateFormatter;

  const _GoalsList({
    required this.snapshot,
    required this.currencyFormatter,
    required this.dateFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final docs = snapshot?.docs ?? [];

    return _Panel(
      title: 'Obiettivi',
      icon: Icons.flag_rounded,
      child: docs.isEmpty
          ? const _EmptyState(text: 'Nessun obiettivo inserito.')
          : Column(
              children: docs.take(6).map((doc) {
                final data = doc.data();

                final title = data['title'] ?? 'Obiettivo';

                final rawTarget = data['target_amount'];
                final target = rawTarget is int
                    ? rawTarget.toDouble()
                    : rawTarget is double
                        ? rawTarget
                        : rawTarget is num
                            ? rawTarget.toDouble()
                            : 0.0;

                final rawCurrent = data['current_amount'];
                final current = rawCurrent is int
                    ? rawCurrent.toDouble()
                    : rawCurrent is double
                        ? rawCurrent
                        : rawCurrent is num
                            ? rawCurrent.toDouble()
                            : 0.0;

                final deadlineRaw = data['deadline'];
                final deadline = deadlineRaw is Timestamp
                    ? dateFormatter.format(deadlineRaw.toDate())
                    : 'N/D';

                final progress =
                    target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ListRow(
                        title: title.toString(),
                        subtitle:
                            '${currencyFormatter.format(current)} / ${currencyFormatter.format(target)} • Scadenza $deadline',
                        trailing: '${(progress * 100).toStringAsFixed(0)}%',
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFE5ECF5),
                          color: const Color(0xFF1E88E5),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFE5ECF5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF1E88E5),
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 19 : 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF172033),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;

  const _ListRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEAF0F7),
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF172033),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    height: 1.35,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  trailing,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E88E5),
                    fontSize: 16,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF172033),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  trailing,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEAF0F7),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AddIncomeDialog extends StatefulWidget {
  final FinanceService financeService;

  const _AddIncomeDialog({
    required this.financeService,
  });

  @override
  State<_AddIncomeDialog> createState() => _AddIncomeDialogState();
}

class _AddIncomeDialogState extends State<_AddIncomeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

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

    await widget.financeService.addIncome(
      title: _titleController.text.trim(),
      amount: amount,
      date: _selectedDate,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseDialog(
      title: 'Aggiungi entrata',
      loading: _loading,
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

class _AddExpenseDialog extends StatefulWidget {
  final FinanceService financeService;

  const _AddExpenseDialog({
    required this.financeService,
  });

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Generale');

  DateTime _selectedDueDate = DateTime.now();
  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  bool _isPaid = false;
  bool _reminderEnabled = true;
  bool _loading = false;

  DashboardExpenseType _expenseType = DashboardExpenseType.standard;

  bool get _isPlanned => _expenseType == DashboardExpenseType.planned;

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

    await widget.financeService.addExpense(
      title: _titleController.text.trim(),
      amount: amount,
      dueDate: _isPlanned ? null : _selectedDueDate,
      category: _categoryController.text.trim(),
      isPaid: _isPlanned ? false : _isPaid,
      reminderEnabled: _isPlanned ? false : _reminderEnabled,
      type: _isPlanned ? 'planned' : 'standard',
      month: _isPlanned ? _selectedMonth : null,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseDialog(
      title: 'Aggiungi spesa',
      loading: _loading,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _ExpenseTypeSelector(
              selectedType: _expenseType,
              onChanged: (value) {
                setState(() {
                  _expenseType = value;

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
  final DashboardExpenseType selectedType;
  final ValueChanged<DashboardExpenseType> onChanged;

  const _ExpenseTypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isStandard = selectedType == DashboardExpenseType.standard;
    final isPlanned = selectedType == DashboardExpenseType.planned;

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
              onTap: () => onChanged(DashboardExpenseType.standard),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _TypeButton(
              label: 'Budget mensile',
              icon: Icons.account_balance_wallet_rounded,
              selected: isPlanned,
              onTap: () => onChanged(DashboardExpenseType.planned),
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

class _AddGoalDialog extends StatefulWidget {
  final FinanceService financeService;

  const _AddGoalDialog({
    required this.financeService,
  });

  @override
  State<_AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends State<_AddGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _currentController = TextEditingController(text: '0');

  DateTime _selectedDeadline = DateTime.now().add(const Duration(days: 90));
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final target = double.parse(
      _targetController.text.replaceAll(',', '.'),
    );

    final current = double.parse(
      _currentController.text.replaceAll(',', '.'),
    );

    await widget.financeService.addGoal(
      title: _titleController.text.trim(),
      targetAmount: target,
      currentAmount: current,
      deadline: _selectedDeadline,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseDialog(
      title: 'Aggiungi obiettivo',
      loading: _loading,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextInput(
              controller: _titleController,
              label: 'Titolo obiettivo',
              validatorText: 'Inserisci il titolo',
            ),
            const SizedBox(height: 12),
            _TextInput(
              controller: _targetController,
              label: 'Importo obiettivo',
              validatorText: 'Inserisci l’importo',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            _TextInput(
              controller: _currentController,
              label: 'Importo già disponibile',
              validatorText: 'Inserisci l’importo',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            _DateButton(
              label: 'Scadenza obiettivo',
              date: _selectedDeadline,
              onTap: _pickDeadline,
            ),
          ],
        ),
      ),
    );
  }
}

class _BaseDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final bool loading;
  final Future<void> Function() onSave;

  const _BaseDialog({
    required this.title,
    required this.child,
    required this.loading,
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
                              : const Text('Salva'),
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

          if (parsed < 0) {
            return 'Inserisci un importo valido';
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
    required this.onTap,
    this.displayFormat = 'dd/MM/yyyy',
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