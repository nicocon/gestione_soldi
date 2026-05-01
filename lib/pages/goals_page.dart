import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/finance_service.dart';

enum GoalFilter {
  all,
  active,
  completed,
  expired,
}

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final FinanceService _financeService = FinanceService();

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
  );

  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy', 'it_IT');

  GoalFilter _selectedFilter = GoalFilter.all;

  double _amountFrom(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0;
  }

  DateTime _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return DateTime.now();
  }

  double _progress({
    required double currentAmount,
    required double targetAmount,
  }) {
    if (targetAmount <= 0) return 0;

    return (currentAmount / targetAmount).clamp(0, 1);
  }

  int _remainingDays(DateTime deadline) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(deadline.year, deadline.month, deadline.day);

    return target.difference(today).inDays;
  }

  bool _isCompleted({
    required double currentAmount,
    required double targetAmount,
  }) {
    return targetAmount > 0 && currentAmount >= targetAmount;
  }

  bool _isExpired({
    required DateTime deadline,
    required bool completed,
  }) {
    return _remainingDays(deadline) < 0 && !completed;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (_selectedFilter == GoalFilter.all) {
      return docs;
    }

    return docs.where((doc) {
      final data = doc.data();

      final targetAmount = _amountFrom(data['target_amount']);
      final currentAmount = _amountFrom(data['current_amount']);
      final deadline = _dateFrom(data['deadline']);

      final completed = _isCompleted(
        currentAmount: currentAmount,
        targetAmount: targetAmount,
      );

      final expired = _isExpired(
        deadline: deadline,
        completed: completed,
      );

      if (_selectedFilter == GoalFilter.completed) {
        return completed;
      }

      if (_selectedFilter == GoalFilter.expired) {
        return expired;
      }

      return !completed && !expired;
    }).toList();
  }

  double _sumTarget(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.fold<double>(0, (sum, doc) {
      return sum + _amountFrom(doc.data()['target_amount']);
    });
  }

  double _sumSaved(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.fold<double>(0, (sum, doc) {
      return sum + _amountFrom(doc.data()['current_amount']);
    });
  }

  int _completedCount(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();

      return _isCompleted(
        currentAmount: _amountFrom(data['current_amount']),
        targetAmount: _amountFrom(data['target_amount']),
      );
    }).length;
  }

  int _expiredCount(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();

      final completed = _isCompleted(
        currentAmount: _amountFrom(data['current_amount']),
        targetAmount: _amountFrom(data['target_amount']),
      );

      return _isExpired(
        deadline: _dateFrom(data['deadline']),
        completed: completed,
      );
    }).length;
  }

  Future<void> _showGoalDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    await _showResponsiveSheet(
      maxDesktopWidth: 520,
      child: _GoalFormDialog(
        financeService: _financeService,
        goalDoc: doc,
      ),
    );
  }

  Future<void> _showAddSavingDialog({
    required String goalId,
    required String title,
    required double remainingAmount,
  }) async {
    await _showResponsiveSheet(
      maxDesktopWidth: 480,
      child: _GoalSavingDialog(
        title: title,
        remainingAmount: remainingAmount,
        financeService: _financeService,
        goalId: goalId,
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
    required String goalId,
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
            'Eliminare obiettivo?',
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
      await _financeService.deleteGoal(goalId: goalId);
    }
  }

  String _deadlineLabel({
    required DateTime deadline,
    required bool completed,
  }) {
    if (completed) return 'Raggiunto';

    final diff = _remainingDays(deadline);

    if (diff < 0) {
      return 'Scaduto da ${diff.abs()} gg';
    }

    if (diff == 0) {
      return 'Scade oggi';
    }

    if (diff == 1) {
      return 'Scade domani';
    }

    return '$diff gg rimasti';
  }

  Color _deadlineColor({
    required DateTime deadline,
    required bool completed,
  }) {
    if (completed) return const Color(0xFF16A34A);

    final diff = _remainingDays(deadline);

    if (diff < 0) return const Color(0xFFDC2626);
    if (diff <= 7) return const Color(0xFFF59E0B);

    return const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _financeService.goalsStream(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final filteredDocs = _filteredDocs(docs);

          final totalTarget = _sumTarget(docs);
          final totalSaved = _sumSaved(docs);
          final totalRemaining = (totalTarget - totalSaved).clamp(0, totalTarget);
          final completedCount = _completedCount(docs);
          final expiredCount = _expiredCount(docs);

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
                        _GoalsHeader(
                          totalTarget: _currencyFormatter.format(totalTarget),
                          totalSaved: _currencyFormatter.format(totalSaved),
                          totalRemaining: _currencyFormatter.format(
                            totalRemaining,
                          ),
                          completedCount: completedCount,
                          totalGoals: docs.length,
                          onAddGoal: () => _showGoalDialog(),
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
                          _EmptyGoals(
                            selectedFilter: _selectedFilter,
                          )
                        else
                          Column(
                            children: filteredDocs.map((doc) {
                              final data = doc.data();

                              final title = data['title'] ?? 'Obiettivo';
                              final targetAmount = _amountFrom(
                                data['target_amount'],
                              );
                              final currentAmount = _amountFrom(
                                data['current_amount'],
                              );
                              final deadline = _dateFrom(data['deadline']);

                              final completed = _isCompleted(
                                currentAmount: currentAmount,
                                targetAmount: targetAmount,
                              );

                              final remainingAmount =
                                  (targetAmount - currentAmount).clamp(
                                0,
                                targetAmount,
                              );

                              final progress = _progress(
                                currentAmount: currentAmount,
                                targetAmount: targetAmount,
                              );

                              return _GoalCard(
                                title: title.toString(),
                                targetAmount: _currencyFormatter.format(
                                  targetAmount,
                                ),
                                currentAmount: _currencyFormatter.format(
                                  currentAmount,
                                ),
                                remainingAmount: _currencyFormatter.format(
                                  remainingAmount,
                                ),
                                rawRemainingAmount: remainingAmount.toDouble(),
                                deadline: _dateFormatter.format(deadline),
                                deadlineLabel: _deadlineLabel(
                                  deadline: deadline,
                                  completed: completed,
                                ),
                                deadlineColor: _deadlineColor(
                                  deadline: deadline,
                                  completed: completed,
                                ),
                                progress: progress,
                                completed: completed,
                                onAddSaving: () => _showAddSavingDialog(
                                  goalId: doc.id,
                                  title: title.toString(),
                                  remainingAmount: remainingAmount.toDouble(),
                                ),
                                onEdit: () => _showGoalDialog(doc: doc),
                                onDelete: () => _confirmDelete(
                                  goalId: doc.id,
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

class _GoalsHeader extends StatelessWidget {
  final String totalTarget;
  final String totalSaved;
  final String totalRemaining;
  final int completedCount;
  final int totalGoals;
  final VoidCallback onAddGoal;

  const _GoalsHeader({
    required this.totalTarget,
    required this.totalSaved,
    required this.totalRemaining,
    required this.completedCount,
    required this.totalGoals,
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
                const _GoalsHeaderText(isMobile: true),
                const SizedBox(height: 20),
                _HeaderStatsGrid(
                  totalTarget: totalTarget,
                  totalSaved: totalSaved,
                  totalRemaining: totalRemaining,
                  completedCount: completedCount,
                  totalGoals: totalGoals,
                  isMobile: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: onAddGoal,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nuovo obiettivo'),
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
                  child: _GoalsHeaderText(isMobile: false),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _HeaderStatsGrid(
                      totalTarget: totalTarget,
                      totalSaved: totalSaved,
                      totalRemaining: totalRemaining,
                      completedCount: completedCount,
                      totalGoals: totalGoals,
                      isMobile: false,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: onAddGoal,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Nuovo obiettivo'),
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

class _GoalsHeaderText extends StatelessWidget {
  final bool isMobile;

  const _GoalsHeaderText({
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Obiettivi',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 27 : 32,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Crea traguardi di risparmio, monitora quanto hai già messo da parte e capisci quanto manca per arrivare al risultato.',
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
  final String totalTarget;
  final String totalSaved;
  final String totalRemaining;
  final int completedCount;
  final int totalGoals;
  final bool isMobile;

  const _HeaderStatsGrid({
    required this.totalTarget,
    required this.totalSaved,
    required this.totalRemaining,
    required this.completedCount,
    required this.totalGoals,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _HeaderMiniStat(
        label: 'Da raggiungere',
        value: totalTarget,
      ),
      _HeaderMiniStat(
        label: 'Risparmiato',
        value: totalSaved,
      ),
      _HeaderMiniStat(
        label: 'Mancante',
        value: totalRemaining,
      ),
      _HeaderMiniStat(
        label: 'Raggiunti',
        value: '$completedCount/$totalGoals',
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

class _FilterBar extends StatelessWidget {
  final GoalFilter selectedFilter;
  final ValueChanged<GoalFilter> onChanged;

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
                        label: 'Tutti',
                        selected: selectedFilter == GoalFilter.all,
                        onTap: () => onChanged(GoalFilter.all),
                      ),
                    ),
                    Expanded(
                      child: _FilterChipButton(
                        label: 'Attivi',
                        selected: selectedFilter == GoalFilter.active,
                        onTap: () => onChanged(GoalFilter.active),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _FilterChipButton(
                        label: 'Raggiunti',
                        selected: selectedFilter == GoalFilter.completed,
                        onTap: () => onChanged(GoalFilter.completed),
                      ),
                    ),
                    Expanded(
                      child: _FilterChipButton(
                        label: 'Scaduti',
                        selected: selectedFilter == GoalFilter.expired,
                        onTap: () => onChanged(GoalFilter.expired),
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
                    label: 'Tutti',
                    selected: selectedFilter == GoalFilter.all,
                    onTap: () => onChanged(GoalFilter.all),
                  ),
                ),
                Expanded(
                  child: _FilterChipButton(
                    label: 'Attivi',
                    selected: selectedFilter == GoalFilter.active,
                    onTap: () => onChanged(GoalFilter.active),
                  ),
                ),
                Expanded(
                  child: _FilterChipButton(
                    label: 'Raggiunti',
                    selected: selectedFilter == GoalFilter.completed,
                    onTap: () => onChanged(GoalFilter.completed),
                  ),
                ),
                Expanded(
                  child: _FilterChipButton(
                    label: 'Scaduti',
                    selected: selectedFilter == GoalFilter.expired,
                    onTap: () => onChanged(GoalFilter.expired),
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

class _GoalCard extends StatelessWidget {
  final String title;
  final String targetAmount;
  final String currentAmount;
  final String remainingAmount;
  final double rawRemainingAmount;
  final String deadline;
  final String deadlineLabel;
  final Color deadlineColor;
  final double progress;
  final bool completed;
  final VoidCallback onAddSaving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.remainingAmount,
    required this.rawRemainingAmount,
    required this.deadline,
    required this.deadlineLabel,
    required this.deadlineColor,
    required this.progress,
    required this.completed,
    required this.onAddSaving,
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
        _topMobile(),
        const SizedBox(height: 14),
        _goalInfo(),
        const SizedBox(height: 14),
        _goalProgress(),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: completed ? null : onAddSaving,
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('Aggiungi risparmio'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1677F2),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE5ECF5),
              disabledForegroundColor: const Color(0xFF94A3B8),
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
    );
  }

  Widget _desktopLayout() {
    return Column(
      children: [
        Row(
          children: [
            _GoalIcon(
              completed: completed,
              deadlineColor: deadlineColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _desktopContent(),
            ),
            const SizedBox(width: 14),
            _actionsDesktop(),
          ],
        ),
        const SizedBox(height: 16),
        _goalProgress(),
      ],
    );
  }

  Widget _topMobile() {
    return Row(
      children: [
        _GoalIcon(
          completed: completed,
          deadlineColor: deadlineColor,
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
                currentAmount,
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

  Widget _desktopContent() {
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
              currentAmount,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF172033),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _goalInfo(),
      ],
    );
  }

  Widget _goalInfo() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InfoBadge(
          text: 'Target: $targetAmount',
          icon: Icons.flag_rounded,
        ),
        _InfoBadge(
          text: 'Mancano: $remainingAmount',
          icon: Icons.savings_rounded,
        ),
        _InfoBadge(
          text: deadline,
          icon: Icons.calendar_month_rounded,
        ),
        _ColoredBadge(
          text: deadlineLabel,
          color: deadlineColor,
        ),
      ],
    );
  }

  Widget _actionsDesktop() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: completed ? null : onAddSaving,
          icon: const Icon(Icons.add_card_rounded),
          label: const Text('Aggiungi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1677F2),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFE5ECF5),
            disabledForegroundColor: const Color(0xFF94A3B8),
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

  Widget _goalProgress() {
    final percent = (progress * 100).round();

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
                child: _GoalMiniValue(
                  label: 'Risparmiato',
                  value: currentAmount,
                ),
              ),
              Expanded(
                child: _GoalMiniValue(
                  label: 'Obiettivo',
                  value: targetAmount,
                ),
              ),
              Expanded(
                child: _GoalMiniValue(
                  label: 'Progresso',
                  value: '$percent%',
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
              color:
                  completed ? const Color(0xFF16A34A) : const Color(0xFF1677F2),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalMiniValue extends StatelessWidget {
  final String label;
  final String value;

  const _GoalMiniValue({
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

class _GoalIcon extends StatelessWidget {
  final bool completed;
  final Color deadlineColor;

  const _GoalIcon({
    required this.completed,
    required this.deadlineColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = completed
        ? const Color(0xFFEAF8EF)
        : deadlineColor == const Color(0xFFDC2626)
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFE3F2FD);

    final iconColor = completed ? const Color(0xFF16A34A) : deadlineColor;

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        completed ? Icons.check_circle_rounded : Icons.flag_rounded,
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

class _EmptyGoals extends StatelessWidget {
  final GoalFilter selectedFilter;

  const _EmptyGoals({
    required this.selectedFilter,
  });

  @override
  Widget build(BuildContext context) {
    final message = selectedFilter == GoalFilter.all
        ? 'Crea il tuo primo obiettivo e inizia a monitorare quanto ti manca per raggiungerlo.'
        : 'Non ci sono obiettivi con questo filtro. Prova a cambiarlo oppure crea un nuovo obiettivo.';

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
      child: Column(
        children: [
          const Icon(
            Icons.flag_rounded,
            size: 44,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 14),
          const Text(
            'Nessun obiettivo trovato',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF172033),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalFormDialog extends StatefulWidget {
  final FinanceService financeService;
  final QueryDocumentSnapshot<Map<String, dynamic>>? goalDoc;

  const _GoalFormDialog({
    required this.financeService,
    this.goalDoc,
  });

  @override
  State<_GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends State<_GoalFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _targetAmountController;
  late final TextEditingController _currentAmountController;

  late DateTime _selectedDeadline;

  bool _loading = false;

  bool get _isEditMode => widget.goalDoc != null;

  @override
  void initState() {
    super.initState();

    final data = widget.goalDoc?.data();

    final title = data?['title'] ?? '';

    final rawTargetAmount = data?['target_amount'];
    final targetAmount = _amountFrom(rawTargetAmount);

    final rawCurrentAmount = data?['current_amount'];
    final currentAmount = _amountFrom(rawCurrentAmount);

    final rawDeadline = data?['deadline'];
    final deadline = rawDeadline is Timestamp
        ? rawDeadline.toDate()
        : DateTime.now().add(const Duration(days: 90));

    _titleController = TextEditingController(text: title.toString());

    _targetAmountController = TextEditingController(
      text: _isEditMode
          ? targetAmount.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );

    _currentAmountController = TextEditingController(
      text: _isEditMode
          ? currentAmount.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );

    _selectedDeadline = deadline;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    super.dispose();
  }

  double _amountFrom(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0;
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline,
      firstDate: DateTime(2020),
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

    final targetAmount = double.parse(
      _targetAmountController.text.replaceAll(',', '.'),
    );

    final currentAmount = double.parse(
      _currentAmountController.text.replaceAll(',', '.'),
    );

    if (_isEditMode) {
      await widget.financeService.updateGoal(
        goalId: widget.goalDoc!.id,
        title: _titleController.text.trim(),
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        deadline: _selectedDeadline,
      );
    } else {
      await widget.financeService.addGoal(
        title: _titleController.text.trim(),
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        deadline: _selectedDeadline,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditMode ? 'Modifica obiettivo' : 'Nuovo obiettivo';

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
              label: 'Nome obiettivo',
              validatorText: 'Inserisci il nome dell’obiettivo',
            ),
            const SizedBox(height: 12),
            _TextInput(
              controller: _targetAmountController,
              label: 'Importo da raggiungere',
              validatorText: 'Inserisci l’importo da raggiungere',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            _TextInput(
              controller: _currentAmountController,
              label: 'Importo già risparmiato',
              validatorText: 'Inserisci l’importo già risparmiato',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              allowZero: true,
            ),
            const SizedBox(height: 12),
            _DateButton(
              label: 'Scadenza obiettivo',
              date: _selectedDeadline,
              displayFormat: 'dd/MM/yyyy',
              onTap: _pickDeadline,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalSavingDialog extends StatefulWidget {
  final String title;
  final double remainingAmount;
  final FinanceService financeService;
  final String goalId;

  const _GoalSavingDialog({
    required this.title,
    required this.remainingAmount,
    required this.financeService,
    required this.goalId,
  });

  @override
  State<_GoalSavingDialog> createState() => _GoalSavingDialogState();
}

class _GoalSavingDialogState extends State<_GoalSavingDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _amountController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final amount = double.parse(
      _amountController.text.replaceAll(',', '.'),
    );

    await widget.financeService.addGoalSaving(
      goalId: widget.goalId,
      amount: amount,
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
      title: 'Aggiungi risparmio',
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
                '${widget.title}\nMancante attuale: $formattedRemaining',
                style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w900,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _TextInput(
              controller: _amountController,
              label: 'Importo risparmiato',
              validatorText: 'Inserisci l’importo risparmiato',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
  final bool allowZero;

  const _TextInput({
    required this.controller,
    required this.label,
    required this.validatorText,
    this.keyboardType,
    this.allowZero = false,
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

          if (allowZero) {
            if (parsed < 0) {
              return 'Inserisci un importo valido';
            }
          } else {
            if (parsed <= 0) {
              return 'Inserisci un importo maggiore di zero';
            }
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