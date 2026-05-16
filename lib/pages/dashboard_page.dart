import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

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

  double _sumPaidPlannedMovementsForMonth(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
    DateTime month,
  ) {
    if (snapshot == null) return 0;

    double total = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      if (!_isPlannedExpense(data)) continue;

      final splitItems = _splitItemsFrom(data['split_items']);

      for (final item in splitItems) {
        final rawPaidAt = item['paid_at'];

        if (rawPaidAt is! Timestamp) continue;

        final paidAt = rawPaidAt.toDate();

        if (_sameMonth(paidAt, month)) {
          total += _amountFrom(item['amount']);
        }
      }
    }

    return total;
  }

  double _sumUnpaidStandardExpensesForMonth(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
    DateTime month,
  ) {
    if (snapshot == null) return 0;

    double total = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      if (_isPlannedExpense(data)) continue;

      final rawDueDate = data['due_date'];

      if (rawDueDate is! Timestamp) continue;

      final dueDate = rawDueDate.toDate();

      if (!_sameMonth(dueDate, month)) continue;

      if (data['is_paid'] != true) {
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

  double _sumBankAccounts(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    if (snapshot == null) return 0;

    double total = 0;

    for (final doc in snapshot.docs) {
      total += _amountFrom(doc.data()['balance']);
    }

    return total;
  }

  int _countActiveGoals(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    if (snapshot == null) return 0;

    int total = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final target = _amountFrom(data['target_amount']);
      final current = _amountFrom(data['current_amount']);

      if (target > 0 && current < target) {
        total++;
      }
    }

    return total;
  }

  List<_BankAccountDashboardItem> _bankAccountItems(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    if (snapshot == null) return [];

    final items = snapshot.docs.map((doc) {
      final data = doc.data();

      return _BankAccountDashboardItem(
        id: doc.id,
        name: (data['name'] ?? 'Conto').toString(),
        balance: _amountFrom(data['balance']),
      );
    }).toList();

    items.sort(
      (a, b) => a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          ),
    );

    return items;
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

  List<_CalendarDayMovementItem> _calendarMovementItemsForCurrentMonth(
    QuerySnapshot<Map<String, dynamic>>? incomesSnapshot,
    QuerySnapshot<Map<String, dynamic>>? expensesSnapshot,
  ) {
    final List<_CalendarDayMovementItem> items = [];

    for (final doc in incomesSnapshot?.docs ?? []) {
      final data = doc.data();

      final rawDate = data['date'];

      if (rawDate is! Timestamp) continue;

      final date = rawDate.toDate();

      if (!_sameMonth(date, _currentMonth)) continue;

      items.add(
        _CalendarDayMovementItem(
          day: date.day,
          title: (data['title'] ?? 'Entrata').toString(),
          category: (data['bank_account_name'] ??
                  data['bankAccountName'] ??
                  data['bank_account_label'] ??
                  'Entrata')
              .toString(),
          amount: _amountFrom(data['amount']),
          date: date,
          isPaid: true,
          type: _CalendarMovementType.income,
        ),
      );
    }

    for (final doc in expensesSnapshot?.docs ?? []) {
      final data = doc.data();

      if (_isPlannedExpense(data)) continue;

      final rawDueDate = data['due_date'];

      if (rawDueDate is! Timestamp) continue;

      final dueDate = rawDueDate.toDate();

      if (!_sameMonth(dueDate, _currentMonth)) continue;

      items.add(
        _CalendarDayMovementItem(
          day: dueDate.day,
          title: (data['title'] ?? 'Spesa').toString(),
          category: (data['category'] ?? 'Generale').toString(),
          amount: _amountFrom(data['amount']),
          date: dueDate,
          isPaid: data['is_paid'] == true,
          type: _CalendarMovementType.expense,
        ),
      );
    }

    items.sort((a, b) => a.date.compareTo(b.date));

    return items;
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

  Future<void> _showAddIncomeDialog({
    required List<_BankAccountDashboardItem> bankAccounts,
  }) async {
    await _showResponsiveSheet(
      child: _AddIncomeDialog(
        financeService: _financeService,
        bankAccounts: bankAccounts,
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

  Future<void> _exportFinancialExcel({
    required QuerySnapshot<Map<String, dynamic>>? incomesSnapshot,
    required QuerySnapshot<Map<String, dynamic>>? expensesSnapshot,
    required QuerySnapshot<Map<String, dynamic>>? goalsSnapshot,
    required QuerySnapshot<Map<String, dynamic>>? bankAccountsSnapshot,
    required List<_MonthlySummaryItem> monthlySummaries,
    required DateTime currentMonth,
    required double currentMonthIncomes,
    required double currentMonthExpenses,
    required double currentMonthBalance,
    required double totalBankBalance,
    required double currentMonthBudgetExpected,
  }) async {
    try {
      final excel = Excel.createExcel();

      final summarySheet = excel['Riepilogo'];
      final incomesSheet = excel['Entrate'];
      final expensesSheet = excel['Uscite'];
      final goalsSheet = excel['Obiettivi'];
      final accountsSheet = excel['Conti'];
      final trendSheet = excel['Andamento'];
      final calendarSheet = excel['Calendario'];

      excel.setDefaultSheet('Riepilogo');

      final defaultSheet = excel.getDefaultSheet();

      if (defaultSheet != null && defaultSheet != 'Riepilogo') {
        excel.delete(defaultSheet);
      }

      void setCell(
        Sheet sheet,
        int row,
        int column,
        CellValue? value,
      ) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: column,
                rowIndex: row,
              ),
            )
            .value = value;
      }

      void setText(
        Sheet sheet,
        int row,
        int column,
        String value,
      ) {
        setCell(sheet, row, column, TextCellValue(value));
      }

      void setNumber(
        Sheet sheet,
        int row,
        int column,
        double value,
      ) {
        setCell(sheet, row, column, DoubleCellValue(value));
      }

      void setHeader(
        Sheet sheet,
        int row,
        List<String> values,
      ) {
        for (int i = 0; i < values.length; i++) {
          setText(sheet, row, i, values[i]);
        }
      }

      String formatDate(DateTime date) {
        return DateFormat('dd/MM/yyyy', 'it_IT').format(date);
      }

      String formatMonth(DateTime date) {
        return DateFormat('MMMM yyyy', 'it_IT').format(date);
      }

      DateTime? timestampToDate(dynamic value) {
        if (value is Timestamp) return value.toDate();

        return null;
      }

      String bankAccountNameFrom(Map<String, dynamic> data) {
        return (data['bank_account_name'] ??
                data['bankAccountName'] ??
                data['bank_account_label'] ??
                data['bankAccountLabel'] ??
                '')
            .toString();
      }

      final incomesRows = <Map<String, dynamic>>[];
      final expensesRows = <Map<String, dynamic>>[];
      final calendarRows = <Map<String, dynamic>>[];

      double totalIncomesAll = 0;
      double totalExpensesAll = 0;
      double totalBudgetExpectedAll = 0;
      double totalPaidBudgetMovementsAll = 0;

      // =========================
      // PREPARA ENTRATE
      // =========================
      for (final doc in incomesSnapshot?.docs ?? []) {
        final data = doc.data();
        final date = timestampToDate(data['date']);
        final amount = _amountFrom(data['amount']);

        totalIncomesAll += amount;

        incomesRows.add({
          'date': date,
          'title': (data['title'] ?? 'Entrata').toString(),
          'amount': amount,
          'account': bankAccountNameFrom(data),
        });

        if (date != null && _sameMonth(date, currentMonth)) {
          calendarRows.add({
            'date': date,
            'type': 'Entrata',
            'title': (data['title'] ?? 'Entrata').toString(),
            'category': bankAccountNameFrom(data).isEmpty
                ? 'Entrata'
                : bankAccountNameFrom(data),
            'income': amount,
            'expense': 0.0,
            'status': 'Incassata',
          });
        }
      }

      incomesRows.sort((a, b) {
        final first = a['date'] as DateTime?;
        final second = b['date'] as DateTime?;

        return (first ?? DateTime(1900)).compareTo(
          second ?? DateTime(1900),
        );
      });

      // =========================
      // PREPARA USCITE
      // =========================
      for (final doc in expensesSnapshot?.docs ?? []) {
        final data = doc.data();

        if (_isPlannedExpense(data)) {
          final month = timestampToDate(data['month']);
          final amount = _amountFrom(data['amount']);
          final title = (data['title'] ?? 'Budget').toString();
          final category = (data['category'] ?? 'Generale').toString();

          totalBudgetExpectedAll += amount;

          expensesRows.add({
            'date': month,
            'title': title,
            'category': category,
            'type': 'Budget mensile',
            'amount': amount,
            'status': 'Previsto',
            'notes': 'Budget pianificato',
          });

          final splitItems = _splitItemsFrom(data['split_items']);

          for (final item in splitItems) {
            final paidAt = timestampToDate(item['paid_at']);
            final splitAmount = _amountFrom(item['amount']);
            final splitTitle = (item['title'] ?? '').toString().trim();

            totalPaidBudgetMovementsAll += splitAmount;
            totalExpensesAll += splitAmount;

            expensesRows.add({
              'date': paidAt,
              'title': splitTitle.isEmpty ? title : splitTitle,
              'category': category,
              'type': 'Movimento budget',
              'amount': splitAmount,
              'status': 'Pagato',
              'notes': 'Collegato al budget: $title',
            });

            if (paidAt != null && _sameMonth(paidAt, currentMonth)) {
              calendarRows.add({
                'date': paidAt,
                'type': 'Uscita',
                'title': splitTitle.isEmpty ? title : splitTitle,
                'category': category,
                'income': 0.0,
                'expense': splitAmount,
                'status': 'Pagata',
              });
            }
          }

          continue;
        }

        final dueDate = timestampToDate(data['due_date']);
        final amount = _amountFrom(data['amount']);
        final title = (data['title'] ?? 'Spesa').toString();
        final category = (data['category'] ?? 'Generale').toString();
        final isPaid = data['is_paid'] == true;

        totalExpensesAll += amount;

        expensesRows.add({
          'date': dueDate,
          'title': title,
          'category': category,
          'type': 'Spesa normale',
          'amount': amount,
          'status': isPaid ? 'Pagata' : 'Da pagare',
          'notes': '',
        });

        if (dueDate != null && _sameMonth(dueDate, currentMonth)) {
          calendarRows.add({
            'date': dueDate,
            'type': 'Uscita',
            'title': title,
            'category': category,
            'income': 0.0,
            'expense': amount,
            'status': isPaid ? 'Pagata' : 'Da pagare',
          });
        }
      }

      expensesRows.sort((a, b) {
        final first = a['date'] as DateTime?;
        final second = b['date'] as DateTime?;

        return (first ?? DateTime(1900)).compareTo(
          second ?? DateTime(1900),
        );
      });

      calendarRows.sort((a, b) {
        final first = a['date'] as DateTime?;
        final second = b['date'] as DateTime?;

        return (first ?? DateTime(1900)).compareTo(
          second ?? DateTime(1900),
        );
      });

      final activeGoals = _countActiveGoals(goalsSnapshot);
      final totalGoals = goalsSnapshot?.docs.length ?? 0;
      final completedGoals = totalGoals - activeGoals;

      final currentMonthName = formatMonth(currentMonth);
      final generatedAt = DateFormat('dd/MM/yyyy HH:mm', 'it_IT').format(
        DateTime.now(),
      );

      // =========================
      // RIEPILOGO
      // =========================
      setText(summarySheet, 0, 0, 'PocketPlan - Report finanziario');
      setText(summarySheet, 1, 0, 'Generato il');
      setText(summarySheet, 1, 1, generatedAt);

      setText(summarySheet, 3, 0, 'Mese analizzato');
      setText(summarySheet, 3, 1, currentMonthName);

      setText(summarySheet, 5, 0, 'Entrate mese');
      setNumber(summarySheet, 5, 1, currentMonthIncomes);

      setText(summarySheet, 6, 0, 'Uscite mese');
      setNumber(summarySheet, 6, 1, currentMonthExpenses);

      setText(summarySheet, 7, 0, 'Saldo mese');
      setNumber(summarySheet, 7, 1, currentMonthBalance);

      setText(summarySheet, 8, 0, 'Budget previsti mese');
      setNumber(summarySheet, 8, 1, currentMonthBudgetExpected);

      setText(summarySheet, 9, 0, 'Totale conti');
      setNumber(summarySheet, 9, 1, totalBankBalance);

      setText(summarySheet, 11, 0, 'Entrate totali registrate');
      setNumber(summarySheet, 11, 1, totalIncomesAll);

      setText(summarySheet, 12, 0, 'Uscite totali registrate');
      setNumber(summarySheet, 12, 1, totalExpensesAll);

      setText(summarySheet, 13, 0, 'Saldo totale movimenti');
      setNumber(summarySheet, 13, 1, totalIncomesAll - totalExpensesAll);

      setText(summarySheet, 14, 0, 'Budget totali pianificati');
      setNumber(summarySheet, 14, 1, totalBudgetExpectedAll);

      setText(summarySheet, 15, 0, 'Movimenti budget pagati');
      setNumber(summarySheet, 15, 1, totalPaidBudgetMovementsAll);

      setText(summarySheet, 17, 0, 'Obiettivi totali');
      setNumber(summarySheet, 17, 1, totalGoals.toDouble());

      setText(summarySheet, 18, 0, 'Obiettivi attivi');
      setNumber(summarySheet, 18, 1, activeGoals.toDouble());

      setText(summarySheet, 19, 0, 'Obiettivi completati');
      setNumber(summarySheet, 19, 1, completedGoals.toDouble());

      setText(summarySheet, 21, 0, 'Lettura veloce');

      String quickMessage;

      if (currentMonthBalance > 0) {
        quickMessage =
            'Il mese è positivo: le entrate superano le uscite registrate.';
      } else if (currentMonthBalance < 0) {
        quickMessage =
            'Attenzione: nel mese le uscite superano le entrate registrate.';
      } else {
        quickMessage =
            'Il mese è in pareggio: entrate e uscite registrate si equivalgono.';
      }

      setText(summarySheet, 22, 0, quickMessage);

      // =========================
      // ENTRATE
      // =========================
      setHeader(incomesSheet, 0, [
        'Data',
        'Titolo',
        'Importo',
        'Conto',
      ]);

      int incomeRow = 1;

      for (final item in incomesRows) {
        final date = item['date'] as DateTime?;

        setText(incomesSheet, incomeRow, 0, date == null ? '' : formatDate(date));
        setText(incomesSheet, incomeRow, 1, item['title'].toString());
        setNumber(incomesSheet, incomeRow, 2, _amountFrom(item['amount']));
        setText(incomesSheet, incomeRow, 3, item['account'].toString());

        incomeRow++;
      }

      if (incomeRow == 1) {
        setText(incomesSheet, 1, 0, 'Nessuna entrata trovata');
      } else {
        incomeRow++;
        setText(incomesSheet, incomeRow, 1, 'Totale entrate');
        setNumber(incomesSheet, incomeRow, 2, totalIncomesAll);
      }

      // =========================
      // USCITE
      // =========================
      setHeader(expensesSheet, 0, [
        'Data',
        'Titolo',
        'Categoria',
        'Tipo',
        'Importo',
        'Stato',
        'Note',
      ]);

      int expenseRow = 1;

      for (final item in expensesRows) {
        final date = item['date'] as DateTime?;

        setText(expensesSheet, expenseRow, 0, date == null ? '' : formatDate(date));
        setText(expensesSheet, expenseRow, 1, item['title'].toString());
        setText(expensesSheet, expenseRow, 2, item['category'].toString());
        setText(expensesSheet, expenseRow, 3, item['type'].toString());
        setNumber(expensesSheet, expenseRow, 4, _amountFrom(item['amount']));
        setText(expensesSheet, expenseRow, 5, item['status'].toString());
        setText(expensesSheet, expenseRow, 6, item['notes'].toString());

        expenseRow++;
      }

      if (expenseRow == 1) {
        setText(expensesSheet, 1, 0, 'Nessuna uscita trovata');
      } else {
        expenseRow++;
        setText(expensesSheet, expenseRow, 3, 'Totale uscite effettive');
        setNumber(expensesSheet, expenseRow, 4, totalExpensesAll);

        expenseRow++;
        setText(expensesSheet, expenseRow, 3, 'Totale budget pianificati');
        setNumber(expensesSheet, expenseRow, 4, totalBudgetExpectedAll);
      }

      // =========================
      // OBIETTIVI
      // =========================
      setHeader(goalsSheet, 0, [
        'Titolo',
        'Importo attuale',
        'Importo obiettivo',
        'Mancano',
        'Progresso %',
        'Scadenza',
        'Stato',
      ]);

      int goalRow = 1;

      for (final doc in goalsSnapshot?.docs ?? []) {
        final data = doc.data();

        final target = _amountFrom(data['target_amount']);
        final current = _amountFrom(data['current_amount']);
        final missing = math.max(0, target - current);
        final progress = target <= 0 ? 0 : (current / target) * 100;

        final deadline = timestampToDate(data['deadline']);
        final isCompleted = target > 0 && current >= target;

        setText(goalsSheet, goalRow, 0, (data['title'] ?? 'Obiettivo').toString());
        setNumber(goalsSheet, goalRow, 1, current);
        setNumber(goalsSheet, goalRow, 2, target);
        setNumber(goalsSheet, goalRow, 3, missing.toDouble());
        setNumber(goalsSheet, goalRow, 4, progress.toDouble());
        setText(goalsSheet, goalRow, 5, deadline == null ? '' : formatDate(deadline));
        setText(goalsSheet, goalRow, 6, isCompleted ? 'Completato' : 'Attivo');

        goalRow++;
      }

      if (goalRow == 1) {
        setText(goalsSheet, 1, 0, 'Nessun obiettivo trovato');
      }

      // =========================
      // CONTI
      // =========================
      setHeader(accountsSheet, 0, [
        'Nome conto',
        'Saldo',
      ]);

      int accountRow = 1;

      for (final doc in bankAccountsSnapshot?.docs ?? []) {
        final data = doc.data();

        setText(accountsSheet, accountRow, 0, (data['name'] ?? 'Conto').toString());
        setNumber(accountsSheet, accountRow, 1, _amountFrom(data['balance']));

        accountRow++;
      }

      if (accountRow == 1) {
        setText(accountsSheet, 1, 0, 'Nessun conto trovato');
      } else {
        accountRow++;
        setText(accountsSheet, accountRow, 0, 'Totale conti');
        setNumber(accountsSheet, accountRow, 1, totalBankBalance);
      }

      // =========================
      // ANDAMENTO
      // =========================
      setHeader(trendSheet, 0, [
        'Mese',
        'Entrate',
        'Uscite',
        'Saldo',
      ]);

      for (int i = 0; i < monthlySummaries.length; i++) {
        final item = monthlySummaries[i];
        final row = i + 1;

        setText(trendSheet, row, 0, item.monthLabel);
        setNumber(trendSheet, row, 1, item.incomes);
        setNumber(trendSheet, row, 2, item.expenses);
        setNumber(trendSheet, row, 3, item.balance);
      }

      // =========================
      // CALENDARIO
      // =========================
      setHeader(calendarSheet, 0, [
        'Data',
        'Tipo',
        'Titolo',
        'Categoria / Conto',
        'Entrata',
        'Uscita',
        'Saldo movimento',
        'Stato',
      ]);

      int calendarRow = 1;

      for (final item in calendarRows) {
        final date = item['date'] as DateTime?;
        final income = _amountFrom(item['income']);
        final expense = _amountFrom(item['expense']);

        setText(calendarSheet, calendarRow, 0, date == null ? '' : formatDate(date));
        setText(calendarSheet, calendarRow, 1, item['type'].toString());
        setText(calendarSheet, calendarRow, 2, item['title'].toString());
        setText(calendarSheet, calendarRow, 3, item['category'].toString());
        setNumber(calendarSheet, calendarRow, 4, income);
        setNumber(calendarSheet, calendarRow, 5, expense);
        setNumber(calendarSheet, calendarRow, 6, income - expense);
        setText(calendarSheet, calendarRow, 7, item['status'].toString());

        calendarRow++;
      }

      if (calendarRow == 1) {
        setText(
          calendarSheet,
          1,
          0,
          'Nessun movimento nel mese corrente',
        );
      } else {
        calendarRow++;
        setText(calendarSheet, calendarRow, 3, 'Totale mese');
        setNumber(calendarSheet, calendarRow, 4, currentMonthIncomes);
        setNumber(calendarSheet, calendarRow, 5, currentMonthExpenses);
        setNumber(calendarSheet, calendarRow, 6, currentMonthBalance);
      }

      final fileName =
          'pocketplan_report_${DateFormat('yyyy_MM_dd_HH_mm').format(DateTime.now())}.xlsx';

      if (kIsWeb) {
        await excel.save(fileName: fileName);
      } else {
        final bytes = excel.encode();

        if (bytes == null || bytes.isEmpty) {
          throw Exception('File Excel non generato');
        }

        await Share.shareXFiles(
          [
            XFile.fromData(
              Uint8List.fromList(bytes),
              name: fileName,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          subject: 'Report finanziario PocketPlan',
          text: 'Esportazione report finanziario PocketPlan',
        );
      }
    } catch (e) {
      debugPrint('ERRORE EXPORT EXCEL: $e');

      if (!mounted) return;

      _showDashboardError(
        context,
        'Non sono riuscito a esportare l’Excel. Riprova tra poco.',
      );
    }
  }

  Future<void> _showResponsiveSheet({
    required Widget child,
  }) async {
    final colors = _DashboardColors.of(context);
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
          constraints: const BoxConstraints(maxWidth: 500),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _DashboardColors.of(context);
    final user = _authService.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: colors.scaffold,
        body: Center(
          child: Text(
            'Utente non trovato',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.scaffold,
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
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _financeService.bankAccountsStream(),
                        builder: (context, bankAccountsSnapshot) {
                          final incomesDocs = incomesSnapshot.data;
                          final expensesDocs = expensesSnapshot.data;
                          final goalsDocs = goalsSnapshot.data;
                          final bankAccountsDocs = bankAccountsSnapshot.data;

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

                          final currentMonthPaidPlannedMovements =
                              _sumPaidPlannedMovementsForMonth(
                            expensesDocs,
                            currentMonth,
                          );

                          final currentMonthUnpaidStandardExpenses =
                              _sumUnpaidStandardExpensesForMonth(
                            expensesDocs,
                            currentMonth,
                          );

                          final currentMonthStandardExpenses =
                              math.max(
                            0,
                            currentMonthExpenses -
                                currentMonthPaidPlannedMovements,
                          );

                          final currentMonthProjectedExpenses =
                              currentMonthStandardExpenses +
                                  math.max(
                                    currentMonthBudgetExpected,
                                    currentMonthPaidPlannedMovements,
                                  );

                          final currentMonthProjectedBalance =
                              currentMonthIncomes -
                                  currentMonthProjectedExpenses;

                          final currentMonthRemainingToPay =
                              currentMonthUnpaidStandardExpenses +
                                  math.max(
                                    0,
                                    currentMonthBudgetExpected -
                                        currentMonthPaidPlannedMovements,
                                  );

                          final currentMonthBalance =
                              currentMonthIncomes - currentMonthExpenses;

                          final previousMonthBalance =
                              previousMonthIncomes - previousMonthExpenses;

                          final totalBankBalance = _sumBankAccounts(
                            bankAccountsDocs,
                          );

                          final bankAccounts = _bankAccountItems(
                            bankAccountsDocs,
                          );

                          final expensesDifference =
                              currentMonthExpenses - previousMonthExpenses;

                          final expensesDifferencePercent =
                              previousMonthExpenses <= 0
                                  ? null
                                  : (expensesDifference /
                                          previousMonthExpenses) *
                                      100;

                          final activeGoals = _countActiveGoals(goalsDocs);

                          final expenseCountCurrentMonth =
                              _countMonthlyExpenses(
                            expensesDocs,
                            currentMonth,
                          );

                          final currentMonthExpenseItems =
                              _expensePreviewItemsForCurrentMonth(expensesDocs);

                          final calendarMovementItems =
                              _calendarMovementItemsForCurrentMonth(
                            incomesDocs,
                            expensesDocs,
                          );

                          final isLoading = incomesSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              expensesSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              goalsSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              bankAccountsSnapshot.connectionState ==
                                  ConnectionState.waiting;

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
                                          currentMonthLabel: _monthFormatter.format(currentMonth),
                                          onAddIncome: () => _showAddIncomeDialog(
                                            bankAccounts: bankAccounts,
                                          ),
                                          onAddExpense: _showAddExpenseDialog,
                                          onAddGoal: _showAddGoalDialog,
                                          onExportExcel: () => _exportFinancialExcel(
                                            incomesSnapshot: incomesDocs,
                                            expensesSnapshot: expensesDocs,
                                            goalsSnapshot: goalsDocs,
                                            bankAccountsSnapshot: bankAccountsDocs,
                                            monthlySummaries: monthlySummaries,
                                            currentMonth: currentMonth,
                                            currentMonthIncomes: currentMonthIncomes,
                                            currentMonthExpenses: currentMonthExpenses,
                                            currentMonthBalance: currentMonthBalance,
                                            totalBankBalance: totalBankBalance,
                                            currentMonthBudgetExpected: currentMonthBudgetExpected,
                                          ),
                                        ),
                                        SizedBox(height: isMobile ? 18 : 24),
                                        if (isLoading) const _DashboardLoadingCard(),

                                        if (isWide)
                                          Column(
                                            children: [
                                              SizedBox(
                                                height: 700,
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    Expanded(
                                                      flex: 7,
                                                      child: _ModernFinanceOverviewCard(
                                                        currentMonthLabel: _monthFormatter.format(currentMonth),
                                                        currentMonthIncomes: currentMonthIncomes,
                                                        currentMonthExpenses: currentMonthExpenses,
                                                        currentMonthBalance: currentMonthBalance,
                                                        currentMonthProjectedBalance: currentMonthProjectedBalance,
                                                        currentMonthRemainingToPay: currentMonthRemainingToPay,
                                                        totalBankBalance: totalBankBalance,
                                                        activeGoals: activeGoals,
                                                        expenseCountCurrentMonth: expenseCountCurrentMonth,
                                                        currencyFormatter: _currencyFormatter,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 18),
                                                    Expanded(
                                                      flex: 4,
                                                      child: _DashboardCalendarCard(
                                                        month: currentMonth,
                                                        movements: calendarMovementItems,
                                                        currencyFormatter: _currencyFormatter,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 18),
                                              _MonthlyTrendChart(
                                                summaries: monthlySummaries,
                                                currencyFormatter: _currencyFormatter,
                                              ),
                                            ],
                                          )
                                        else
                                          Column(
                                            children: [
                                              _ModernFinanceOverviewCard(
                                                currentMonthLabel: _monthFormatter.format(currentMonth),
                                                currentMonthIncomes: currentMonthIncomes,
                                                currentMonthExpenses: currentMonthExpenses,
                                                currentMonthBalance: currentMonthBalance,
                                                currentMonthProjectedBalance: currentMonthProjectedBalance,
                                                currentMonthRemainingToPay: currentMonthRemainingToPay,
                                                totalBankBalance: totalBankBalance,
                                                activeGoals: activeGoals,
                                                expenseCountCurrentMonth: expenseCountCurrentMonth,
                                                currencyFormatter: _currencyFormatter,
                                              ),
                                              const SizedBox(height: 18),
                                              _DashboardCalendarCard(
                                                month: currentMonth,
                                                movements: calendarMovementItems,
                                                currencyFormatter: _currencyFormatter,
                                              ),
                                              const SizedBox(height: 18),
                                              _MonthlyTrendChart(
                                                summaries: monthlySummaries,
                                                currencyFormatter: _currencyFormatter,
                                              ),
                                            ],
                                          ),

                                        SizedBox(height: isMobile ? 20 : 28),

                                        _MonthlyInsightCard(
                                          currentMonthLabel: _monthFormatter.format(currentMonth),
                                          previousMonthLabel: _monthFormatter.format(previousMonth),
                                          currentMonthExpenses: currentMonthExpenses,
                                          previousMonthExpenses: previousMonthExpenses,
                                          averagePastExpenses: averagePastExpenses,
                                          expensesDifference: expensesDifference,
                                          expensesDifferencePercent: expensesDifferencePercent,
                                          currentMonthBalance: currentMonthBalance,
                                          previousMonthBalance: previousMonthBalance,
                                          currentMonthBudgetExpected: currentMonthBudgetExpected,
                                          totalBankBalance: totalBankBalance,
                                          currencyFormatter: _currencyFormatter,
                                        ),

                                        SizedBox(height: isMobile ? 20 : 28),

                                        if (isWide)
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: _BankAccountsDashboardPanel(
                                                  bankAccounts: bankAccounts,
                                                  totalBankBalance: totalBankBalance,
                                                  currencyFormatter: _currencyFormatter,
                                                ),
                                              ),
                                              const SizedBox(width: 18),
                                              Expanded(
                                                child: _GoalsList(
                                                  snapshot: goalsDocs,
                                                  currencyFormatter: _currencyFormatter,
                                                  dateFormatter: _dateFormatter,
                                                ),
                                              ),
                                            ],
                                          )
                                        else
                                          Column(
                                            children: [
                                              _BankAccountsDashboardPanel(
                                                bankAccounts: bankAccounts,
                                                totalBankBalance: totalBankBalance,
                                                currencyFormatter: _currencyFormatter,
                                              ),
                                              const SizedBox(height: 18),
                                              _GoalsList(
                                                snapshot: goalsDocs,
                                                currencyFormatter: _currencyFormatter,
                                                dateFormatter: _dateFormatter,
                                              ),
                                            ],
                                          ),

                                        SizedBox(height: isMobile ? 20 : 28),

                                        _ExpensesList(
                                          items: currentMonthExpenseItems,
                                          currencyFormatter: _currencyFormatter,
                                          dateFormatter: _dateFormatter,
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
          );
        },
      ),
    );
  }
}

class _DashboardColors {
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

  const _DashboardColors({
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

  factory _DashboardColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return const _DashboardColors(
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

    return const _DashboardColors(
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

BoxDecoration _dashboardCardDecoration(BuildContext context) {
  final colors = _DashboardColors.of(context);

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
        offset: const Offset(0, 10),
      ),
    ],
  );
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

class _BankAccountDashboardItem {
  final String id;
  final String name;
  final double balance;

  const _BankAccountDashboardItem({
    required this.id,
    required this.name,
    required this.balance,
  });
}

enum _CalendarMovementType {
  income,
  expense,
}

class _CalendarDayMovementItem {
  final int day;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final bool isPaid;
  final _CalendarMovementType type;

  const _CalendarDayMovementItem({
    required this.day,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.isPaid,
    required this.type,
  });
}

class _HeaderSection extends StatelessWidget {
  final String name;
  final String currentMonthLabel;
  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;
  final VoidCallback onAddGoal;
  final VoidCallback onExportExcel;

  const _HeaderSection({
    required this.name,
    required this.currentMonthLabel,
    required this.onAddIncome,
    required this.onAddExpense,
    required this.onAddGoal,
    required this.onExportExcel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _DashboardColors.of(context);
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
                  onExportExcel: onExportExcel,
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
                  onExportExcel: onExportExcel,
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
    final colors = _DashboardColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ciao $name 👋',
          style: TextStyle(
            color: colors.headerText,
            fontSize: isMobile ? 26 : 32,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Riepilogo di ${currentMonthLabel.toUpperCase()}: controlla entrate, spese, conti bancari e andamento degli ultimi mesi.',
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

class _HeaderActions extends StatelessWidget {
  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;
  final VoidCallback onAddGoal;
  final VoidCallback onExportExcel;
  final bool isMobile;

  const _HeaderActions({
    required this.onAddIncome,
    required this.onAddExpense,
    required this.onAddGoal,
    required this.onExportExcel,
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
          _ActionButton(
            label: 'Esporta Excel',
            icon: Icons.file_download_rounded,
            onPressed: onExportExcel,
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
        _ActionButton(
          label: 'Excel',
          icon: Icons.file_download_rounded,
          onPressed: onExportExcel,
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
    final colors = _DashboardColors.of(context);

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.isDark ? colors.primary : Colors.white,
          foregroundColor:
              colors.isDark ? const Color(0xFF0F172A) : const Color(0xFF172033),
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

class _ModernFinanceOverviewCard extends StatelessWidget {
  final String currentMonthLabel;
  final double currentMonthIncomes;
  final double currentMonthExpenses;
  final double currentMonthBalance;
  final double currentMonthProjectedBalance;
  final double currentMonthRemainingToPay;
  final double totalBankBalance;
  final int activeGoals;
  final int expenseCountCurrentMonth;
  final NumberFormat currencyFormatter;

  const _ModernFinanceOverviewCard({
    required this.currentMonthLabel,
    required this.currentMonthIncomes,
    required this.currentMonthExpenses,
    required this.currentMonthBalance,
    required this.currentMonthProjectedBalance,
    required this.currentMonthRemainingToPay,
    required this.totalBankBalance,
    required this.activeGoals,
    required this.expenseCountCurrentMonth,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _DashboardColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    final spentRatio = currentMonthIncomes <= 0
        ? 0.0
        : (currentMonthExpenses / currentMonthIncomes).clamp(0.0, 1.0);

    final balancePositive = currentMonthBalance >= 0;
    final projectedBalancePositive = currentMonthProjectedBalance >= 0;

    String forecastMessage;

    if (currentMonthIncomes <= 0) {
      forecastMessage =
          'Aggiungi le entrate del mese per calcolare una previsione più precisa.';
    } else if (currentMonthRemainingToPay <= 0 && projectedBalancePositive) {
      forecastMessage =
          'Hai già coperto le spese principali: se non aggiungi nuove uscite, il mese può chiudersi bene.';
    } else if (projectedBalancePositive) {
      forecastMessage =
          'Hai ancora ${currencyFormatter.format(currentMonthRemainingToPay)} da coprire, ma la previsione resta positiva.';
    } else {
      forecastMessage =
          'Attenzione: considerando le spese previste, il mese potrebbe chiudersi in negativo.';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: _dashboardCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.space_dashboard_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Panoramica finanziaria',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: isMobile ? 20 : 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentMonthLabel.toUpperCase(),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: balancePositive
                      ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                      : const Color(0xFFDC2626).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  balancePositive ? 'POSITIVO' : 'ATTENZIONE',
                  style: TextStyle(
                    color: balancePositive
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 20 : 24),
          Text(
            currencyFormatter.format(currentMonthBalance),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: isMobile ? 36 : 44,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Saldo del mese: entrate meno spese registrate',
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: spentRatio,
              minHeight: 10,
              backgroundColor: colors.cardSofter,
              color: balancePositive
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            currentMonthIncomes <= 0
                ? 'Aggiungi le entrate del mese per calcolare il consumo.'
                : 'Hai usato il ${(spentRatio * 100).toStringAsFixed(0)}% delle entrate mensili.',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 18),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 15 : 16),
            decoration: BoxDecoration(
              color: projectedBalancePositive
                  ? const Color(0xFF16A34A).withValues(
                      alpha: colors.isDark ? 0.18 : 0.10,
                    )
                  : const Color(0xFFDC2626).withValues(
                      alpha: colors.isDark ? 0.18 : 0.10,
                    ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: projectedBalancePositive
                    ? const Color(0xFF16A34A).withValues(alpha: 0.28)
                    : const Color(0xFFDC2626).withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.card.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    projectedBalancePositive
                        ? Icons.insights_rounded
                        : Icons.warning_amber_rounded,
                    color: projectedBalancePositive
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Previsione fine mese',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        currencyFormatter.format(currentMonthProjectedBalance),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: projectedBalancePositive
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                          fontSize: isMobile ? 24 : 26,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        forecastMessage,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile) const Spacer(),
          SizedBox(height: isMobile ? 18 : 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 560;

              final cards = [
                _ModernOverviewMiniCard(
                  icon: Icons.trending_up_rounded,
                  title: 'Entrate',
                  value: currencyFormatter.format(currentMonthIncomes),
                  accentColor: const Color(0xFF16A34A),
                ),
                _ModernOverviewMiniCard(
                  icon: Icons.trending_down_rounded,
                  title: 'Spese',
                  value: currencyFormatter.format(currentMonthExpenses),
                  accentColor: const Color(0xFFDC2626),
                ),
                _ModernOverviewMiniCard(
                  icon: Icons.account_balance_rounded,
                  title: 'Totale conti',
                  value: currencyFormatter.format(totalBankBalance),
                  accentColor: colors.primary,
                ),
                _ModernOverviewMiniCard(
                  icon: Icons.flag_rounded,
                  title: 'Obiettivi',
                  value: activeGoals.toString(),
                  accentColor: const Color(0xFFF59E0B),
                ),
              ];

              if (!twoColumns) {
                return Column(
                  children: cards
                      .map(
                        (card) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: card,
                        ),
                      )
                      .toList(),
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards
                    .map(
                      (card) => SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: card,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModernOverviewMiniCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color accentColor;

  const _ModernOverviewMiniCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _DashboardColors.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: colors.isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCalendarCard extends StatelessWidget {
  final DateTime month;
  final List<_CalendarDayMovementItem> movements;
  final NumberFormat currencyFormatter;

  const _DashboardCalendarCard({
    required this.month,
    required this.movements,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _DashboardColors.of(context);

    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startOffset = firstDay.weekday - 1;

    final today = DateTime.now();
    final isCurrentMonth = today.year == month.year && today.month == month.month;

    final movementsByDay = <int, List<_CalendarDayMovementItem>>{};

    for (final item in movements) {
      movementsByDay.putIfAbsent(item.day, () => []).add(item);
    }

    final totalIncome = movements.fold<double>(
      0,
      (sum, item) {
        if (item.type != _CalendarMovementType.income) return sum;

        return sum + item.amount;
      },
    );

    final totalToPay = movements.fold<double>(
      0,
      (sum, item) {
        if (item.type != _CalendarMovementType.expense) return sum;
        if (item.isPaid) return sum;

        return sum + item.amount;
      },
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _dashboardCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Calendario finanziario',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('MMMM yyyy', 'it_IT').format(month).toUpperCase(),
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CalendarInfoPill(
                  label: 'Entrate',
                  value: currencyFormatter.format(totalIncome),
                  color: const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CalendarInfoPill(
                  label: 'Da pagare',
                  value: currencyFormatter.format(totalToPay),
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _CalendarInfoPill(
                  label: 'Movimenti',
                  value: movements.length.toString(),
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CalendarInfoPill(
                  label: 'Saldo mese',
                  value: currencyFormatter.format(totalIncome - totalToPay),
                  color: totalIncome - totalToPay >= 0
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              _WeekDayLabel('LUN'),
              _WeekDayLabel('MAR'),
              _WeekDayLabel('MER'),
              _WeekDayLabel('GIO'),
              _WeekDayLabel('VEN'),
              _WeekDayLabel('SAB'),
              _WeekDayLabel('DOM'),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: startOffset + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              if (index < startOffset) {
                return const SizedBox.shrink();
              }

              final day = index - startOffset + 1;
              final dayMovements = movementsByDay[day] ?? [];

              final hasMovements = dayMovements.isNotEmpty;
              final hasUnpaid = dayMovements.any((item) {
                return item.type == _CalendarMovementType.expense && !item.isPaid;
              });
              final hasIncome = dayMovements.any((item) {
                return item.type == _CalendarMovementType.income;
              });
              final hasPaidExpenses = dayMovements.any((item) {
                return item.type == _CalendarMovementType.expense && item.isPaid;
              });

              final isToday = isCurrentMonth && today.day == day;

              return _CalendarDayCell(
                day: day,
                isToday: isToday,
                hasMovements: hasMovements,
                hasUnpaid: hasUnpaid,
                hasIncome: hasIncome,
                hasPaidExpenses: hasPaidExpenses,
                onTap: () {
                  _showCalendarDayDetails(
                    context: context,
                    date: DateTime(month.year, month.month, day),
                    items: dayMovements,
                    currencyFormatter: currencyFormatter,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _showCalendarDayDetails({
  required BuildContext context,
  required DateTime date,
  required List<_CalendarDayMovementItem> items,
  required NumberFormat currencyFormatter,
}) async {
  final colors = _DashboardColors.of(context);
  final dateFormatter = DateFormat('dd/MM/yyyy', 'it_IT');

  final totalIncome = items.fold<double>(
    0,
    (sum, item) {
      if (item.type != _CalendarMovementType.income) return sum;

      return sum + item.amount;
    },
  );

  final totalExpenses = items.fold<double>(
    0,
    (sum, item) {
      if (item.type != _CalendarMovementType.expense) return sum;

      return sum + item.amount;
    },
  );

  final totalToPay = items.fold<double>(
    0,
    (sum, item) {
      if (item.type != _CalendarMovementType.expense) return sum;
      if (item.isPaid) return sum;

      return sum + item.amount;
    },
  );

  final dailyBalance = totalIncome - totalExpenses;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dateFormatter.format(date),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _CalendarInfoPill(
                      label: 'Entrate',
                      value: currencyFormatter.format(totalIncome),
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CalendarInfoPill(
                      label: 'Uscite',
                      value: currencyFormatter.format(totalExpenses),
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _CalendarInfoPill(
                      label: 'Da pagare',
                      value: currencyFormatter.format(totalToPay),
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CalendarInfoPill(
                      label: 'Saldo giorno',
                      value: currencyFormatter.format(dailyBalance),
                      color: dailyBalance >= 0
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const _EmptyState(
                  text:
                      'Nessun movimento registrato per questo giorno.',
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: items.map((item) {
                        final isIncome =
                            item.type == _CalendarMovementType.income;

                        return _ListRow(
                          title: item.title,
                          subtitle: isIncome
                              ? 'Entrata • ${item.category}'
                              : '${item.category} • ${item.isPaid ? 'Pagata' : 'Da pagare'}',
                          trailing:
                              '${isIncome ? '+' : '-'}${currencyFormatter.format(item.amount)}',
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _CalendarInfoPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CalendarInfoPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _DashboardColors.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: colors.isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekDayLabel extends StatelessWidget {
  final String label;

  const _WeekDayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final colors = _DashboardColors.of(context);

    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool hasMovements;
  final bool hasUnpaid;
  final bool hasIncome;
  final bool hasPaidExpenses;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.day,
    required this.isToday,
    required this.hasMovements,
    required this.hasUnpaid,
    required this.hasIncome,
    required this.hasPaidExpenses,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _DashboardColors.of(context);

    final Color movementColor;

    if (hasUnpaid) {
      movementColor = const Color(0xFFDC2626);
    } else if (hasIncome) {
      movementColor = const Color(0xFF16A34A);
    } else if (hasPaidExpenses) {
      movementColor = colors.primary;
    } else {
      movementColor = colors.textSecondary;
    }

    final backgroundColor = isToday
        ? colors.primary
        : hasMovements
            ? movementColor.withValues(alpha: colors.isDark ? 0.24 : 0.10)
            : colors.cardSoft;

    final textColor = isToday
        ? Colors.white
        : hasMovements
            ? movementColor
            : colors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isToday ? colors.primary : colors.border,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                day.toString(),
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              if (hasMovements)
                Positioned(
                  bottom: 6,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isToday ? Colors.white : movementColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
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
  final double totalBankBalance;
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
    required this.totalBankBalance,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _DashboardColors.of(context);
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

    if (currentMonthBalance < 0 && totalBankBalance > 0) {
      comparisonText +=
          ' Il saldo del mese è negativo, ma hai ${currencyFormatter.format(totalBankBalance)} nei conti registrati: puoi coprire la differenza, però stai usando liquidità già disponibile.';
    }

    final percentText = expensesDifferencePercent == null
        ? 'N/D'
        : '${expensesDifferencePercent!.abs().toStringAsFixed(1)}%';

    final balanceDifference = currentMonthBalance - previousMonthBalance;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: _dashboardCardDecoration(context),
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
                  style: TextStyle(
                    color: colors.textPrimary,
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
                  totalBankBalance: totalBankBalance,
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
                        style: TextStyle(
                          color: colors.textPrimary,
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
                    totalBankBalance: totalBankBalance,
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
    final colors = _DashboardColors.of(context);

    final color = isSpendingMore
        ? const Color(0xFFDC2626)
        : isSpendingLess
            ? const Color(0xFF16A34A)
            : colors.primary;

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
            color: color.withValues(alpha: colors.isDark ? 0.18 : 0.10),
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
            style: TextStyle(
              color: colors.textPrimary,
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
  final double totalBankBalance;
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
    required this.totalBankBalance,
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
        label: 'Totale conti',
        value: currencyFormatter.format(totalBankBalance),
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
    final colors = _DashboardColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: isMobile ? double.infinity : 145,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.cardSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
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
  final double totalBankBalance;
  final int activeGoals;
  final int expenseCountCurrentMonth;
  final NumberFormat currencyFormatter;

  const _SummaryGrid({
    required this.currentMonthIncomes,
    required this.currentMonthExpenses,
    required this.currentMonthBalance,
    required this.totalBankBalance,
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
        icon: Icons.account_balance_rounded,
        title: 'Totale conti',
        value: currencyFormatter.format(totalBankBalance),
        subtitle: 'Soldi disponibili in banca',
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
        decoration: _dashboardCardDecoration(context),
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
    final colors = _DashboardColors.of(context);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        icon,
        color: colors.primary,
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
    final colors = _DashboardColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.textSecondary,
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
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _BankAccountsDashboardPanel extends StatelessWidget {
  final List<_BankAccountDashboardItem> bankAccounts;
  final double totalBankBalance;
  final NumberFormat currencyFormatter;

  const _BankAccountsDashboardPanel({
    required this.bankAccounts,
    required this.totalBankBalance,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _DashboardColors.of(context);

    return _Panel(
      title: 'I tuoi conti',
      icon: Icons.account_balance_rounded,
      child: bankAccounts.isEmpty
          ? const _EmptyState(
              text:
                  'Nessun conto inserito. Vai nella pagina Entrate e aggiungi il saldo che hai già in banca.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
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
                          color: colors.isDark
                              ? const Color(0xFF052E16)
                              : const Color(0xFFEAF8EF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.savings_rounded,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Totale disponibile',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormatter.format(totalBankBalance),
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: bankAccounts.map((account) {
                    return _BankAccountMiniCard(
                      account: account,
                      currencyFormatter: currencyFormatter,
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}

class _BankAccountMiniCard extends StatelessWidget {
  final _BankAccountDashboardItem account;
  final NumberFormat currencyFormatter;

  const _BankAccountMiniCard({
    required this.account,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _DashboardColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: isMobile ? double.infinity : 250,
      padding: const EdgeInsets.all(15),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormatter.format(account.balance),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final colors = _DashboardColors.of(context);
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
              color: colors.textSecondary,
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
                isDark: colors.isDark,
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
  final bool isDark;

  _MonthlyTrendChartPainter({
    required this.summaries,
    required this.currencyFormatter,
    required this.isDark,
  });

  Color get _axisColor => isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
  Color get _gridColor => isDark ? const Color(0xFF334155) : const Color(0xFFEAF0F7);
  Color get _labelColor => isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);

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
          : chartRect.left + (chartRect.width / (summaries.length - 1)) * index;

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
      ..color = isDark ? const Color(0xFF172033) : Colors.white
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
    return oldDelegate.summaries != summaries || oldDelegate.isDark != isDark;
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
    final colors = _DashboardColors.of(context);

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
          style: TextStyle(
            color: colors.textSecondary,
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
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

  double _amountFrom(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = _DashboardColors.of(context);
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
                final target = _amountFrom(data['target_amount']);
                final current = _amountFrom(data['current_amount']);

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
                          backgroundColor: colors.border,
                          color: colors.primary,
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
    final colors = _DashboardColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: _dashboardCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: colors.primary,
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
                    color: colors.textPrimary,
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
    final colors = _DashboardColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 18 : 16),
      decoration: BoxDecoration(
        color: colors.cardSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.border,
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    height: 1.35,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  trailing,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: colors.primary,
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
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  trailing,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
    );
  }
}

class _DashboardLoadingCard extends StatelessWidget {
  const _DashboardLoadingCard();

  @override
  Widget build(BuildContext context) {
    final colors = _DashboardColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      margin: const EdgeInsets.only(bottom: 22),
      decoration: _dashboardCardDecoration(context),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Sto aggiornando la tua situazione finanziaria...',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
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
    final colors = _DashboardColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.cardSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.border,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AddIncomeDialog extends StatefulWidget {
  final FinanceService financeService;
  final List<_BankAccountDashboardItem> bankAccounts;

  const _AddIncomeDialog({
    required this.financeService,
    required this.bankAccounts,
  });

  @override
  State<_AddIncomeDialog> createState() => _AddIncomeDialogState();
}

class _AddIncomeDialogState extends State<_AddIncomeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

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
    final colors = _DashboardColors.of(context);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
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
      final amount = _parseDashboardAmount(_amountController.text);

      await widget.financeService.addIncome(
        title: _titleController.text.trim(),
        amount: amount,
        date: _selectedDate,
        bankAccountId: _selectedBankAccountId,
        bankAccountName: _selectedBankAccountName(),
      );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      _showDashboardError(
        context,
        'Non sono riuscito a salvare l’entrata. Riprova tra poco.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
              allowZero: false,
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

class _BankAccountDropdown extends StatelessWidget {
  final List<_BankAccountDashboardItem> bankAccounts;
  final String? selectedBankAccountId;
  final ValueChanged<String?> onChanged;

  const _BankAccountDropdown({
    required this.bankAccounts,
    required this.selectedBankAccountId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _DashboardColors.of(context);
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
      decoration: _inputDecoration(
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
    final picked = await _showDashboardDatePicker(
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
    final picked = await _showDashboardDatePicker(
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

    try {
      final amount = _parseDashboardAmount(_amountController.text);

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

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      _showDashboardError(
        context,
        'Non sono riuscito a salvare la spesa. Riprova tra poco.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
              allowZero: false,
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
    final colors = _DashboardColors.of(context);
    final isStandard = selectedType == DashboardExpenseType.standard;
    final isPlanned = selectedType == DashboardExpenseType.planned;

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
    final colors = _DashboardColors.of(context);

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
    final picked = await _showDashboardDatePicker(
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

    try {
      final target = _parseDashboardAmount(_targetController.text);
      final current = _parseDashboardAmount(_currentController.text);

      await widget.financeService.addGoal(
        title: _titleController.text.trim(),
        targetAmount: target,
        currentAmount: current,
        deadline: _selectedDeadline,
      );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      _showDashboardError(
        context,
        'Non sono riuscito a salvare l’obiettivo. Riprova tra poco.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
              allowZero: false,
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
    final colors = _DashboardColors.of(context);
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
  final bool allowZero;

  const _TextInput({
    required this.controller,
    required this.label,
    required this.validatorText,
    this.keyboardType,
    this.allowZero = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _DashboardColors.of(context);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: _inputDecoration(
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
          final parsed = double.tryParse(
            value.trim().replaceAll(',', '.'),
          );

          if (parsed == null) {
            return 'Inserisci un numero valido';
          }

          if (parsed < 0 || (!allowZero && parsed == 0)) {
            return allowZero
                ? 'Inserisci un importo valido'
                : 'Inserisci un importo maggiore di zero';
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
    final colors = _DashboardColors.of(context);
    final formattedDate = DateFormat(displayFormat, 'it_IT').format(date);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: _inputDecoration(
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
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _DashboardColors.of(context);

    return Container(
      padding: const EdgeInsets.only(left: 14, right: 8),
      decoration: BoxDecoration(
        color: colors.cardSoft,
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
            color: colors.textPrimary,
          ),
        ),
        activeColor: colors.primary,
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required BuildContext context,
  required String label,
  IconData? suffixIcon,
}) {
  final colors = _DashboardColors.of(context);

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

Future<DateTime?> _showDashboardDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) async {
  final colors = _DashboardColors.of(context);

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

double _parseDashboardAmount(String value) {
  return double.parse(
    value.trim().replaceAll(',', '.'),
  );
}

void _showDashboardError(
  BuildContext context,
  String message,
) {
  final colors = _DashboardColors.of(context);

  ScaffoldMessenger.of(context).clearSnackBars();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.isDark
          ? const Color(0xFF7F1D1D)
          : const Color(0xFFDC2626),
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}