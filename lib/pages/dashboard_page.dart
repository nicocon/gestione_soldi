import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/finance_service.dart';

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

  bool _isCurrentMonth(Timestamp? timestamp) {
    if (timestamp == null) return false;

    final date = timestamp.toDate();
    final now = DateTime.now();

    return date.year == now.year && date.month == now.month;
  }

  double _sumCurrentMonth(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String dateField,
  ) {
    double total = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data[dateField];

      if (timestamp is Timestamp && _isCurrentMonth(timestamp)) {
        final amount = data['amount'];

        if (amount is int) {
          total += amount.toDouble();
        } else if (amount is double) {
          total += amount;
        }
      }
    }

    return total;
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
          constraints: const BoxConstraints(maxWidth: 460),
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

                      final totalIncomes = incomesDocs == null
                          ? 0.0
                          : _sumCurrentMonth(incomesDocs, 'date');

                      final totalExpenses = expensesDocs == null
                          ? 0.0
                          : _sumCurrentMonth(expensesDocs, 'due_date');

                      final balance = totalIncomes - totalExpenses;
                      final activeGoals = goalsDocs?.docs.length ?? 0;

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
                                constraints:
                                    const BoxConstraints(maxWidth: 1200),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _HeaderSection(
                                      name: name.toString(),
                                      onAddIncome: _showAddIncomeDialog,
                                      onAddExpense: _showAddExpenseDialog,
                                      onAddGoal: _showAddGoalDialog,
                                    ),
                                    SizedBox(height: isMobile ? 18 : 24),
                                    _SummaryGrid(
                                      totalIncomes: totalIncomes,
                                      totalExpenses: totalExpenses,
                                      balance: balance,
                                      activeGoals: activeGoals,
                                      currencyFormatter: _currencyFormatter,
                                    ),
                                    SizedBox(height: isMobile ? 20 : 28),
                                    if (constraints.maxWidth >= 900)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _ExpensesList(
                                              snapshot: expensesDocs,
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
                                            snapshot: expensesDocs,
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

class _HeaderSection extends StatelessWidget {
  final String name;
  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;
  final VoidCallback onAddGoal;

  const _HeaderSection({
    required this.name,
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
                _HeaderText(name: name, isMobile: true),
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
                  child: _HeaderText(name: name, isMobile: false),
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
  final bool isMobile;

  const _HeaderText({
    required this.name,
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
          'Ecco il riepilogo del tuo mese. Aggiungi entrate, spese e obiettivi per iniziare a costruire il tuo piano.',
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

class _SummaryGrid extends StatelessWidget {
  final double totalIncomes;
  final double totalExpenses;
  final double balance;
  final int activeGoals;
  final NumberFormat currencyFormatter;

  const _SummaryGrid({
    required this.totalIncomes,
    required this.totalExpenses,
    required this.balance,
    required this.activeGoals,
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
        value: currencyFormatter.format(totalIncomes),
        subtitle: 'Totale entrate registrate',
      ),
      _SummaryCard(
        icon: Icons.trending_down_rounded,
        title: 'Spese mese',
        value: currencyFormatter.format(totalExpenses),
        subtitle: 'Totale spese del mese',
      ),
      _SummaryCard(
        icon: Icons.account_balance_wallet_rounded,
        title: 'Saldo previsto',
        value: currencyFormatter.format(balance),
        subtitle: balance >= 0 ? 'Situazione positiva' : 'Saldo negativo',
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

class _ExpensesList extends StatelessWidget {
  final QuerySnapshot<Map<String, dynamic>>? snapshot;
  final NumberFormat currencyFormatter;
  final DateFormat dateFormatter;

  const _ExpensesList({
    required this.snapshot,
    required this.currencyFormatter,
    required this.dateFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final docs = snapshot?.docs ?? [];

    return _Panel(
      title: 'Ultime spese',
      icon: Icons.receipt_long_rounded,
      child: docs.isEmpty
          ? const _EmptyState(text: 'Nessuna spesa inserita.')
          : Column(
              children: docs.take(6).map((doc) {
                final data = doc.data();

                final title = data['title'] ?? 'Spesa';
                final category = data['category'] ?? 'Generale';

                final rawAmount = data['amount'];
                final amount = rawAmount is int
                    ? rawAmount.toDouble()
                    : rawAmount is double
                        ? rawAmount
                        : 0.0;

                final isPaid = data['is_paid'] == true;
                final reminderEnabled = data['reminder_enabled'] == true;

                final dueDateRaw = data['due_date'];
                final dueDate = dueDateRaw is Timestamp
                    ? dateFormatter.format(dueDateRaw.toDate())
                    : 'N/D';

                return _ListRow(
                  title: title.toString(),
                  subtitle:
                      '${category.toString()} • Scadenza $dueDate • ${isPaid ? 'Pagata' : 'Da pagare'}${reminderEnabled ? ' • Promemoria' : ''}',
                  trailing: currencyFormatter.format(amount),
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
                        : 0.0;

                final rawCurrent = data['current_amount'];
                final current = rawCurrent is int
                    ? rawCurrent.toDouble()
                    : rawCurrent is double
                        ? rawCurrent
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
  bool _isPaid = false;
  bool _reminderEnabled = true;
  bool _loading = false;

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final amount = double.parse(
      _amountController.text.replaceAll(',', '.'),
    );

    await widget.financeService.addExpense(
      title: _titleController.text.trim(),
      amount: amount,
      dueDate: _selectedDueDate,
      category: _categoryController.text.trim(),
      isPaid: _isPaid,
      reminderEnabled: _reminderEnabled,
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
            _TextInput(
              controller: _categoryController,
              label: 'Categoria',
              validatorText: 'Inserisci la categoria',
            ),
            const SizedBox(height: 12),
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
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd/MM/yyyy', 'it_IT').format(date);

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