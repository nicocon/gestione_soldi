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
  }) async {
    await _showResponsiveSheet(
      maxDesktopWidth: 480,
      child: _IncomeFormDialog(
        financeService: _financeService,
        incomeDoc: doc,
      ),
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
    required String incomeId,
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
            'Eliminare entrata?',
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
      await _financeService.deleteIncome(incomeId: incomeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _financeService.incomesStream(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final monthDocs = _docsBySelectedMonth(docs);

          final totalAll = docs.fold<double>(0, (sum, doc) {
            return sum + _extractAmount(doc.data());
          });

          final totalMonth = monthDocs.fold<double>(0, (sum, doc) {
            return sum + _extractAmount(doc.data());
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
                          totalMonth: _currencyFormatter.format(totalMonth),
                          incomeCountMonth: incomeCountMonth,
                          onAddIncome: () => _showIncomeDialog(),
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
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
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

                              return _IncomeCard(
                                title: title.toString(),
                                amount: _currencyFormatter.format(amount),
                                date: _dateFormatter.format(date),
                                onEdit: () => _showIncomeDialog(doc: doc),
                                onDelete: () => _confirmDelete(
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
      ),
    );
  }
}

class _IncomesHeader extends StatelessWidget {
  final String totalAll;
  final String totalMonth;
  final int incomeCountMonth;
  final VoidCallback onAddIncome;

  const _IncomesHeader({
    required this.totalAll,
    required this.totalMonth,
    required this.incomeCountMonth,
    required this.onAddIncome,
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
                const _IncomesHeaderText(isMobile: true),
                const SizedBox(height: 20),
                _HeaderStatsGrid(
                  totalMonth: totalMonth,
                  totalAll: totalAll,
                  incomeCountMonth: incomeCountMonth,
                  isMobile: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: onAddIncome,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nuova entrata'),
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
                  child: _IncomesHeaderText(isMobile: false),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _HeaderStatsGrid(
                      totalMonth: totalMonth,
                      totalAll: totalAll,
                      incomeCountMonth: incomeCountMonth,
                      isMobile: false,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: onAddIncome,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Nuova entrata'),
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

class _IncomesHeaderText extends StatelessWidget {
  final bool isMobile;

  const _IncomesHeaderText({
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestione entrate',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 27 : 32,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Registra stipendio, bonus, rimborsi e controlla le entrate mese per mese.',
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
  final String totalMonth;
  final String totalAll;
  final int incomeCountMonth;
  final bool isMobile;

  const _HeaderStatsGrid({
    required this.totalMonth,
    required this.totalAll,
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
      color: const Color(0xFFEAF8EF),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: const Color(0xFF16A34A),
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _IncomeCard({
    required this.title,
    required this.amount,
    required this.date,
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
                      color: Color(0xFF16A34A),
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
              text: date,
              icon: Icons.calendar_month_rounded,
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

  Widget _desktopLayout() {
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
                    text: date,
                    icon: Icons.calendar_month_rounded,
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

class _IncomeIcon extends StatelessWidget {
  const _IncomeIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8EF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.trending_up_rounded,
        color: Color(0xFF16A34A),
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

class _EmptyIncomes extends StatelessWidget {
  const _EmptyIncomes();

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
            Icons.trending_up_rounded,
            size: 44,
            color: Color(0xFF94A3B8),
          ),
          SizedBox(height: 14),
          Text(
            'Nessuna entrata trovata',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF172033),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Aggiungi stipendio, bonus, rimborsi o altre entrate per questo mese.',
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

class _IncomeFormDialog extends StatefulWidget {
  final FinanceService financeService;
  final QueryDocumentSnapshot<Map<String, dynamic>>? incomeDoc;

  const _IncomeFormDialog({
    required this.financeService,
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

    if (_isEditMode) {
      await widget.financeService.updateIncome(
        incomeId: widget.incomeDoc!.id,
        title: _titleController.text.trim(),
        amount: amount,
        date: _selectedDate,
      );
    } else {
      await widget.financeService.addIncome(
        title: _titleController.text.trim(),
        amount: amount,
        date: _selectedDate,
      );
    }

    if (mounted) Navigator.pop(context);
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