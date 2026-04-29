import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/finance_service.dart';

enum ExpenseFilter {
  all,
  unpaid,
  paid,
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

  ExpenseFilter _selectedFilter = ExpenseFilter.all;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (_selectedFilter == ExpenseFilter.all) {
      return docs;
    }

    if (_selectedFilter == ExpenseFilter.paid) {
      return docs.where((doc) => doc.data()['is_paid'] == true).toList();
    }

    return docs.where((doc) => doc.data()['is_paid'] != true).toList();
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

  Future<void> _showExpenseDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => _ExpenseFormDialog(
        financeService: _financeService,
        expenseDoc: doc,
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
          title: const Text('Eliminare spesa?'),
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
      appBar: AppBar(
        title: const Text(
          'Spese',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _financeService.expensesStream(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final filteredDocs = _filteredDocs(docs);

          final totalAll = docs.fold<double>(0, (sum, doc) {
            final amount = doc.data()['amount'];

            if (amount is int) return sum + amount.toDouble();
            if (amount is double) return sum + amount;

            return sum;
          });

          final totalUnpaid = docs.where((doc) {
            return doc.data()['is_paid'] != true;
          }).fold<double>(0, (sum, doc) {
            final amount = doc.data()['amount'];

            if (amount is int) return sum + amount.toDouble();
            if (amount is double) return sum + amount;

            return sum;
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ExpensesHeader(
                      totalAll: _currencyFormatter.format(totalAll),
                      totalUnpaid: _currencyFormatter.format(totalUnpaid),
                      onAddExpense: () => _showExpenseDialog(),
                    ),
                    const SizedBox(height: 22),
                    _FilterBar(
                      selectedFilter: _selectedFilter,
                      onChanged: (filter) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                    ),
                    const SizedBox(height: 22),
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

                          final rawAmount = data['amount'];
                          final amount = rawAmount is int
                              ? rawAmount.toDouble()
                              : rawAmount is double
                                  ? rawAmount
                                  : 0.0;

                          final isPaid = data['is_paid'] == true;
                          final reminderEnabled =
                              data['reminder_enabled'] == true;

                          final dueDateRaw = data['due_date'];
                          final dueDate = dueDateRaw is Timestamp
                              ? dueDateRaw.toDate()
                              : DateTime.now();

                          return _ExpenseCard(
                            title: title.toString(),
                            category: category.toString(),
                            amount: _currencyFormatter.format(amount),
                            dueDate: _dateFormatter.format(dueDate),
                            deadlineLabel: _deadlineLabel(dueDate, isPaid),
                            deadlineColor: _deadlineColor(dueDate, isPaid),
                            isPaid: isPaid,
                            reminderEnabled: reminderEnabled,
                            onTogglePaid: () => _togglePaid(
                              expenseId: doc.id,
                              currentValue: isPaid,
                            ),
                            onEdit: () => _showExpenseDialog(doc: doc),
                            onDelete: () => _confirmDelete(
                              expenseId: doc.id,
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
      ),
    );
  }
}

class _ExpensesHeader extends StatelessWidget {
  final String totalAll;
  final String totalUnpaid;
  final VoidCallback onAddExpense;

  const _ExpensesHeader({
    required this.totalAll,
    required this.totalUnpaid,
    required this.onAddExpense,
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestione spese',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Controlla le spese, segna quelle pagate e tieni d’occhio le prossime scadenze.',
                  style: TextStyle(
                    color: Color(0xFFD7DEE9),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _HeaderMiniStat(
                label: 'Totale spese',
                value: totalAll,
              ),
              _HeaderMiniStat(
                label: 'Da pagare',
                value: totalUnpaid,
              ),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: onAddExpense,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nuova spesa'),
                ),
              ),
            ],
          ),
        ],
      ),
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
    return Container(
      width: 180,
      padding: const EdgeInsets.all(18),
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
            style: const TextStyle(
              color: Color(0xFFD7DEE9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _FilterChipButton(
          label: 'Tutte',
          selected: selectedFilter == ExpenseFilter.all,
          onTap: () => onChanged(ExpenseFilter.all),
        ),
        _FilterChipButton(
          label: 'Da pagare',
          selected: selectedFilter == ExpenseFilter.unpaid,
          onTap: () => onChanged(ExpenseFilter.unpaid),
        ),
        _FilterChipButton(
          label: 'Pagate',
          selected: selectedFilter == ExpenseFilter.paid,
          onTap: () => onChanged(ExpenseFilter.paid),
        ),
      ],
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
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFE3F2FD),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF1565C0) : const Color(0xFF4B5563),
        fontWeight: FontWeight.w800,
      ),
      side: const BorderSide(
        color: Color(0xFFDDE6F2),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final String title;
  final String category;
  final String amount;
  final String dueDate;
  final String deadlineLabel;
  final Color deadlineColor;
  final bool isPaid;
  final bool reminderEnabled;
  final VoidCallback onTogglePaid;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseCard({
    required this.title,
    required this.category,
    required this.amount,
    required this.dueDate,
    required this.deadlineLabel,
    required this.deadlineColor,
    required this.isPaid,
    required this.reminderEnabled,
    required this.onTogglePaid,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
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
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isPaid
                  ? const Color(0xFFEAF8EF)
                  : const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isPaid
                  ? Icons.check_circle_rounded
                  : Icons.receipt_long_rounded,
              color: isPaid
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF1E88E5),
            ),
          ),
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
                Wrap(
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
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Wrap(
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
          ),
        ],
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
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Aggiungi una nuova spesa oppure cambia filtro.',
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
  late bool _isPaid;
  late bool _reminderEnabled;

  bool _loading = false;

  bool get _isEditMode => widget.expenseDoc != null;

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
            : 0.0;

    final rawDueDate = data?['due_date'];
    final dueDate = rawDueDate is Timestamp
        ? rawDueDate.toDate()
        : DateTime.now();

    _titleController = TextEditingController(text: title.toString());

    _amountController = TextEditingController(
      text: _isEditMode ? amount.toStringAsFixed(2).replaceAll('.', ',') : '',
    );

    _categoryController = TextEditingController(text: category.toString());

    _selectedDueDate = dueDate;

    _isPaid = data?['is_paid'] == true;

    _reminderEnabled = _isEditMode
        ? (data?['reminder_enabled'] == true)
        : true;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final amount = double.parse(
      _amountController.text.replaceAll(',', '.'),
    );

    if (_isEditMode) {
      await widget.financeService.updateExpense(
        expenseId: widget.expenseDoc!.id,
        title: _titleController.text.trim(),
        amount: amount,
        dueDate: _selectedDueDate,
        category: _categoryController.text.trim(),
        isPaid: _isPaid,
        reminderEnabled: _reminderEnabled,
      );
    } else {
      await widget.financeService.addExpense(
        title: _titleController.text.trim(),
        amount: amount,
        dueDate: _selectedDueDate,
        category: _categoryController.text.trim(),
        isPaid: _isPaid,
        reminderEnabled: _reminderEnabled,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditMode ? 'Modifica spesa' : 'Nuova spesa';

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditMode ? 'Aggiorna' : 'Salva'),
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