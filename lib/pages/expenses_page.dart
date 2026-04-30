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

  double _sumExpenses(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.fold<double>(0, (sum, doc) {
      final amount = doc.data()['amount'];

      if (amount is int) return sum + amount.toDouble();
      if (amount is double) return sum + amount;

      return sum;
    });
  }

  Future<void> _showExpenseDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    await _showResponsiveSheet(
      child: _ExpenseFormDialog(
        financeService: _financeService,
        expenseDoc: doc,
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
          constraints: const BoxConstraints(maxWidth: 480),
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
          final filteredDocs = _filteredDocs(docs);

          final totalAll = _sumExpenses(docs);

          final unpaidDocs = docs.where((doc) {
            return doc.data()['is_paid'] != true;
          }).toList();

          final totalUnpaid = _sumExpenses(unpaidDocs);

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
                          totalAll: _currencyFormatter.format(totalAll),
                          totalUnpaid: _currencyFormatter.format(totalUnpaid),
                          unpaidCount: unpaidDocs.length,
                          onAddExpense: () => _showExpenseDialog(),
                        ),
                        SizedBox(height: isMobile ? 18 : 22),
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
                                deadlineLabel: _deadlineLabel(
                                  dueDate,
                                  isPaid,
                                ),
                                deadlineColor: _deadlineColor(
                                  dueDate,
                                  isPaid,
                                ),
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
          );
        },
      ),
    );
  }
}

class _ExpensesHeader extends StatelessWidget {
  final String totalAll;
  final String totalUnpaid;
  final int unpaidCount;
  final VoidCallback onAddExpense;

  const _ExpensesHeader({
    required this.totalAll,
    required this.totalUnpaid,
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
          'Controlla le spese, segna quelle pagate e tieni d’occhio le prossime scadenze.',
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
  final int unpaidCount;
  final bool isMobile;

  const _HeaderStatsGrid({
    required this.totalAll,
    required this.totalUnpaid,
    required this.unpaidCount,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _HeaderMiniStat(
        label: 'Totale',
        value: totalAll,
      ),
      _HeaderMiniStat(
        label: 'Da pagare',
        value: totalUnpaid,
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
          stats[2],
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
              fontSize: isMobile ? 20 : 21,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
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
        Row(
          children: [
            _ExpenseIcon(isPaid: isPaid),
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
                    amount,
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
        ),
        const SizedBox(height: 14),
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
                color:
                    isPaid ? const Color(0xFFE5ECF5) : const Color(0xFF16A34A),
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
    );
  }

  Widget _desktopLayout() {
    return Row(
      children: [
        _ExpenseIcon(isPaid: isPaid),
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
    );
  }
}

class _ExpenseIcon extends StatelessWidget {
  final bool isPaid;

  const _ExpenseIcon({
    required this.isPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: isPaid ? const Color(0xFFEAF8EF) : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        isPaid ? Icons.check_circle_rounded : Icons.receipt_long_rounded,
        color: isPaid ? const Color(0xFF16A34A) : const Color(0xFF1E88E5),
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
    final dueDate =
        rawDueDate is Timestamp ? rawDueDate.toDate() : DateTime.now();

    _titleController = TextEditingController(text: title.toString());

    _amountController = TextEditingController(
      text: _isEditMode ? amount.toStringAsFixed(2).replaceAll('.', ',') : '',
    );

    _categoryController = TextEditingController(text: category.toString());

    _selectedDueDate = dueDate;

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