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
    await showDialog(
      context: context,
      builder: (_) => _AddIncomeDialog(
        financeService: _financeService,
      ),
    );
  }

  Future<void> _showAddExpenseDialog() async {
    await showDialog(
      context: context,
      builder: (_) => _AddExpenseDialog(
        financeService: _financeService,
      ),
    );
  }

  Future<void> _showAddGoalDialog() async {
    await showDialog(
      context: context,
      builder: (_) => _AddGoalDialog(
        financeService: _financeService,
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
      appBar: AppBar(
        title: const Text(
          'Gestione Soldi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
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

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _HeaderSection(
                                  name: name.toString(),
                                  onAddIncome: _showAddIncomeDialog,
                                  onAddExpense: _showAddExpenseDialog,
                                  onAddGoal: _showAddGoalDialog,
                                ),
                                const SizedBox(height: 24),
                                Wrap(
                                  spacing: 18,
                                  runSpacing: 18,
                                  children: [
                                    _SummaryCard(
                                      icon: Icons.trending_up_rounded,
                                      title: 'Entrate mese',
                                      value: _currencyFormatter.format(
                                        totalIncomes,
                                      ),
                                      subtitle: 'Totale entrate registrate',
                                    ),
                                    _SummaryCard(
                                      icon: Icons.trending_down_rounded,
                                      title: 'Spese mese',
                                      value: _currencyFormatter.format(
                                        totalExpenses,
                                      ),
                                      subtitle: 'Totale spese del mese',
                                    ),
                                    _SummaryCard(
                                      icon: Icons.account_balance_wallet_rounded,
                                      title: 'Saldo previsto',
                                      value: _currencyFormatter.format(balance),
                                      subtitle: balance >= 0
                                          ? 'Situazione positiva'
                                          : 'Attenzione: saldo negativo',
                                    ),
                                    _SummaryCard(
                                      icon: Icons.flag_rounded,
                                      title: 'Obiettivi attivi',
                                      value: activeGoals.toString(),
                                      subtitle: 'Obiettivi di risparmio',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isWide = constraints.maxWidth >= 900;

                                    if (isWide) {
                                      return Row(
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
                                      );
                                    }

                                    return Column(
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
                                    );
                                  },
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
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xFF172033),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ciao $name 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ecco il riepilogo del tuo mese. Aggiungi entrate, spese e obiettivi per iniziare a costruire il tuo piano.',
                  style: TextStyle(
                    color: Color(0xFFD7DEE9),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: onAddIncome,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Entrata'),
              ),
              ElevatedButton.icon(
                onPressed: onAddExpense,
                icon: const Icon(Icons.remove_rounded),
                label: const Text('Spesa'),
              ),
              ElevatedButton.icon(
                onPressed: onAddGoal,
                icon: const Icon(Icons.flag_rounded),
                label: const Text('Obiettivo'),
              ),
            ],
          ),
        ],
      ),
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
    return SizedBox(
      width: 280,
      child: Container(
        padding: const EdgeInsets.all(22),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: const Color(0xFF1E88E5),
              size: 34,
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: Color(0xFF172033),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF7C8798),
              ),
            ),
          ],
        ),
      ),
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
                      '${category.toString()} • Scadenza $dueDate • ${isPaid ? 'Pagata' : 'Da pagare'}${reminderEnabled ? ' • Promemoria attivo' : ''}',
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
                      LinearProgressIndicator(value: progress),
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
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFE5ECF5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1E88E5)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
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
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF6B7280),
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
              keyboardType: TextInputType.number,
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
              keyboardType: TextInputType.number,
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
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _isPaid,
              onChanged: (value) {
                setState(() {
                  _isPaid = value ?? false;
                });
              },
              contentPadding: EdgeInsets.zero,
              title: const Text('Spesa già pagata'),
            ),
            CheckboxListTile(
              value: _reminderEnabled,
              onChanged: (value) {
                setState(() {
                  _reminderEnabled = value ?? true;
                });
              },
              contentPadding: EdgeInsets.zero,
              title: const Text('Promemoria attivo'),
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
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _TextInput(
              controller: _currentController,
              label: 'Importo già disponibile',
              validatorText: 'Inserisci l’importo',
              keyboardType: TextInputType.number,
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
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: child,
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: loading ? null : onSave,
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salva'),
        ),
      ],
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
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return validatorText;
        }

        if (keyboardType == TextInputType.number) {
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
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_month_rounded),
        ).copyWith(
          labelText: label,
        ),
        child: Text(formattedDate),
      ),
    );
  }
}