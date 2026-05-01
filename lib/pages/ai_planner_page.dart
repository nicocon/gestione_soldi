import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/finance_service.dart';

class AIPlannerPage extends StatefulWidget {
  const AIPlannerPage({super.key});

  @override
  State<AIPlannerPage> createState() => _AIPlannerPageState();
}

class _AIPlannerPageState extends State<AIPlannerPage> {
  final FinanceService _financeService = FinanceService();

  final TextEditingController _questionController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
  );

  late Future<Map<String, dynamic>> _plannerFuture;

  bool _isAsking = false;

  final List<_AIMessage> _messages = [
    const _AIMessage(
      text:
          'Ciao! Sono il tuo AI Planner. Posso aiutarti a capire quanto puoi spendere, quanto puoi risparmiare e come gestire meglio il mese.',
      isUser: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _plannerFuture = _financeService.getAIPlannerSnapshot();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshPlanner() async {
    setState(() {
      _plannerFuture = _financeService.getAIPlannerSnapshot();
    });
  }

  double _amountFrom(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0;
  }

  int _intFrom(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return 0;
  }

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return null;
  }

  String _formatMoney(dynamic value) {
    return _currencyFormatter.format(_amountFrom(value));
  }

  List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();

    if (question.isEmpty || _isAsking) return;

    setState(() {
      _messages.add(
        _AIMessage(
          text: question,
          isUser: true,
        ),
      );
      _isAsking = true;
      _questionController.clear();
    });

    _scrollChatToBottom();

    try {
      final answer = await _financeService.askAIPlannerLocally(
        question: question,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(
          _AIMessage(
            text: answer,
            isUser: false,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          const _AIMessage(
            text:
                'Non sono riuscito ad analizzare i dati in questo momento. Controlla che entrate, spese e obiettivi siano caricati correttamente.',
            isUser: false,
          ),
        );
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isAsking = false;
      });

      _scrollChatToBottom();
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;

      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _askQuickQuestion(String question) async {
    _questionController.text = question;
    await _askQuestion();
  }

  Color _moodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'ottima':
        return const Color(0xFF16A34A);
      case 'stabile':
        return const Color(0xFF1677F2);
      case 'da controllare':
        return const Color(0xFFF59E0B);
      case 'attenzione':
      case 'critica':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _moodIcon(String mood) {
    switch (mood.toLowerCase()) {
      case 'ottima':
        return Icons.verified_rounded;
      case 'stabile':
        return Icons.check_circle_rounded;
      case 'da controllare':
        return Icons.warning_amber_rounded;
      case 'attenzione':
      case 'critica':
        return Icons.error_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  String _mainInsight(Map<String, dynamic> data) {
    final mood = (data['financial_mood'] ?? 'Da configurare').toString();
    final availableBudget = _amountFrom(data['available_budget']);
    final safetyBuffer = _amountFrom(data['safety_buffer']);
    final unpaidExpenses = _amountFrom(data['unpaid_expenses']);
    final monthlyIncome = _amountFrom(data['monthly_income']);

    if (monthlyIncome <= 0) {
      return 'Inserisci almeno un’entrata per permettere all’AI Planner di costruire un piano realistico per il mese.';
    }

    if (availableBudget < 0) {
      return 'Questo mese le uscite previste superano le entrate. Ti consiglio di bloccare le spese extra e controllare quelle non ancora pagate.';
    }

    if (availableBudget <= safetyBuffer) {
      return 'La situazione è delicata: hai ancora budget disponibile, ma sei vicino al margine di sicurezza.';
    }

    if (unpaidExpenses > 0) {
      return 'Hai ancora alcune spese da pagare. Prima di aggiungere nuovi acquisti, controlla bene le prossime scadenze.';
    }

    if (mood.toLowerCase() == 'ottima') {
      return 'Questo mese sei messo bene: puoi valutare di risparmiare qualcosa o alimentare un obiettivo.';
    }

    return 'La situazione è abbastanza stabile. Puoi continuare così, mantenendo un margine di sicurezza per eventuali imprevisti.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _plannerFuture,
        builder: (context, snapshot) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 800;

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return _AIPlannerError(
                  onRetry: _refreshPlanner,
                );
              }

              final data = snapshot.data ?? {};

              final monthlyIncome = _amountFrom(data['monthly_income']);
              final paidExpenses = _amountFrom(data['paid_expenses']);
              final unpaidExpenses = _amountFrom(data['unpaid_expenses']);
              final plannedExpenses = _amountFrom(data['planned_expenses']);
              final totalExpenses = _amountFrom(data['total_expenses']);
              final availableBudget = _amountFrom(data['available_budget']);
              final safetyBuffer = _amountFrom(data['safety_buffer']);
              final spendableBudget = _amountFrom(data['spendable_budget']);
              final dailyAvailable = _amountFrom(data['daily_available']);
              final score = _intFrom(data['financial_health_score']);
              final mood = (data['financial_mood'] ?? 'Da configurare')
                  .toString();
              final topCategoryName =
                  (data['top_category_name'] ?? '').toString();
              final topCategoryAmount = _amountFrom(
                data['top_category_amount'],
              );

              final previousTotalExpenses = _amountFrom(
                data['previous_total_expenses'],
              );

              final suggestions = (data['suggestions'] is List)
                  ? List<String>.from(
                      (data['suggestions'] as List).map(
                        (item) => item.toString(),
                      ),
                    )
                  : <String>[];

              final categories = _listOfMaps(data['categories']);
              final activeGoals = _listOfMaps(data['active_goals']);
              final unpaidExpensesList = _listOfMaps(data['unpaid_expenses_list']);
              final upcomingExpenses = _listOfMaps(data['upcoming_expenses']);

              return RefreshIndicator(
                onRefresh: _refreshPlanner,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
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
                          _AIPlannerHeader(
                            mood: mood,
                            moodColor: _moodColor(mood),
                            moodIcon: _moodIcon(mood),
                            score: score,
                            insight: _mainInsight(data),
                            availableBudget: _currencyFormatter.format(
                              availableBudget,
                            ),
                            spendableBudget: _currencyFormatter.format(
                              spendableBudget,
                            ),
                            safetyBuffer: _currencyFormatter.format(
                              safetyBuffer,
                            ),
                            onRefresh: _refreshPlanner,
                          ),
                          SizedBox(height: isMobile ? 16 : 22),
                          _SummaryGrid(
                            isMobile: isMobile,
                            items: [
                              _SummaryItem(
                                label: 'Entrate mese',
                                value: _currencyFormatter.format(monthlyIncome),
                                icon: Icons.trending_up_rounded,
                                color: const Color(0xFF16A34A),
                              ),
                              _SummaryItem(
                                label: 'Spese totali',
                                value: _currencyFormatter.format(totalExpenses),
                                icon: Icons.receipt_long_rounded,
                                color: const Color(0xFFDC2626),
                              ),
                              _SummaryItem(
                                label: 'Disponibile',
                                value: _currencyFormatter.format(
                                  availableBudget,
                                ),
                                icon: Icons.account_balance_wallet_rounded,
                                color: const Color(0xFF1677F2),
                              ),
                              _SummaryItem(
                                label: 'Al giorno',
                                value: _currencyFormatter.format(
                                  dailyAvailable,
                                ),
                                icon: Icons.today_rounded,
                                color: const Color(0xFF7C3AED),
                              ),
                            ],
                          ),
                          SizedBox(height: isMobile ? 16 : 22),
                          if (isMobile)
                            Column(
                              children: [
                                _AIAdviceCard(
                                  suggestions: suggestions,
                                  topCategoryName: topCategoryName,
                                  topCategoryAmount:
                                      _currencyFormatter.format(
                                    topCategoryAmount,
                                  ),
                                  previousTotalExpenses:
                                      previousTotalExpenses,
                                  totalExpenses: totalExpenses,
                                  formatMoney: _currencyFormatter.format,
                                ),
                                const SizedBox(height: 16),
                                _AIChatCard(
                                  messages: _messages,
                                  controller: _questionController,
                                  scrollController: _chatScrollController,
                                  isAsking: _isAsking,
                                  onSend: _askQuestion,
                                  onQuickQuestion: _askQuickQuestion,
                                ),
                              ],
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _AIAdviceCard(
                                    suggestions: suggestions,
                                    topCategoryName: topCategoryName,
                                    topCategoryAmount:
                                        _currencyFormatter.format(
                                      topCategoryAmount,
                                    ),
                                    previousTotalExpenses:
                                        previousTotalExpenses,
                                    totalExpenses: totalExpenses,
                                    formatMoney: _currencyFormatter.format,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  flex: 5,
                                  child: _AIChatCard(
                                    messages: _messages,
                                    controller: _questionController,
                                    scrollController: _chatScrollController,
                                    isAsking: _isAsking,
                                    onSend: _askQuestion,
                                    onQuickQuestion: _askQuickQuestion,
                                  ),
                                ),
                              ],
                            ),
                          SizedBox(height: isMobile ? 16 : 22),
                          _BudgetBreakdownCard(
                            paidExpenses: _currencyFormatter.format(
                              paidExpenses,
                            ),
                            unpaidExpenses: _currencyFormatter.format(
                              unpaidExpenses,
                            ),
                            plannedExpenses: _currencyFormatter.format(
                              plannedExpenses,
                            ),
                            totalExpenses: _currencyFormatter.format(
                              totalExpenses,
                            ),
                            availableBudget: _currencyFormatter.format(
                              availableBudget,
                            ),
                            safetyBuffer: _currencyFormatter.format(
                              safetyBuffer,
                            ),
                            spendableBudget: _currencyFormatter.format(
                              spendableBudget,
                            ),
                            availableRaw: availableBudget,
                          ),
                          SizedBox(height: isMobile ? 16 : 22),
                          if (isMobile)
                            Column(
                              children: [
                                _CategoriesCard(
                                  categories: categories,
                                  formatMoney: _formatMoney,
                                ),
                                const SizedBox(height: 16),
                                _GoalsPlannerCard(
                                  goals: activeGoals,
                                  formatMoney: _formatMoney,
                                  dateFrom: _dateFrom,
                                ),
                              ],
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _CategoriesCard(
                                    categories: categories,
                                    formatMoney: _formatMoney,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: _GoalsPlannerCard(
                                    goals: activeGoals,
                                    formatMoney: _formatMoney,
                                    dateFrom: _dateFrom,
                                  ),
                                ),
                              ],
                            ),
                          SizedBox(height: isMobile ? 16 : 22),
                          _UpcomingCard(
                            unpaidExpenses: unpaidExpensesList,
                            upcomingExpenses: upcomingExpenses,
                            formatMoney: _formatMoney,
                            dateFrom: _dateFrom,
                          ),
                        ],
                      ),
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

class _AIMessage {
  final String text;
  final bool isUser;

  const _AIMessage({
    required this.text,
    required this.isUser,
  });
}

class _AIPlannerHeader extends StatelessWidget {
  final String mood;
  final Color moodColor;
  final IconData moodIcon;
  final int score;
  final String insight;
  final String availableBudget;
  final String spendableBudget;
  final String safetyBuffer;
  final Future<void> Function() onRefresh;

  const _AIPlannerHeader({
    required this.mood,
    required this.moodColor,
    required this.moodIcon,
    required this.score,
    required this.insight,
    required this.availableBudget,
    required this.spendableBudget,
    required this.safetyBuffer,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 800;

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
                  mood: mood,
                  moodColor: moodColor,
                  moodIcon: moodIcon,
                  insight: insight,
                  isMobile: true,
                ),
                const SizedBox(height: 18),
                _HeaderStats(
                  score: score,
                  availableBudget: availableBudget,
                  spendableBudget: spendableBudget,
                  safetyBuffer: safetyBuffer,
                  isMobile: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Aggiorna analisi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF172033),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _HeaderText(
                    mood: mood,
                    moodColor: moodColor,
                    moodIcon: moodIcon,
                    insight: insight,
                    isMobile: false,
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _HeaderStats(
                      score: score,
                      availableBudget: availableBudget,
                      spendableBudget: spendableBudget,
                      safetyBuffer: safetyBuffer,
                      isMobile: false,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Aggiorna analisi'),
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

class _HeaderText extends StatelessWidget {
  final String mood;
  final Color moodColor;
  final IconData moodIcon;
  final String insight;
  final bool isMobile;

  const _HeaderText({
    required this.mood,
    required this.moodColor,
    required this.moodIcon,
    required this.insight,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'AI Planner',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 28 : 34,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: moodColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: moodColor.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    moodIcon,
                    color: moodColor,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    mood,
                    style: TextStyle(
                      color: moodColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Il tuo assistente personale per capire cosa puoi spendere, quanto puoi risparmiare e come arrivare meglio a fine mese.',
          style: TextStyle(
            color: const Color(0xFFD7DEE9),
            fontSize: isMobile ? 15 : 16,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF93C5FD),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  insight,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderStats extends StatelessWidget {
  final int score;
  final String availableBudget;
  final String spendableBudget;
  final String safetyBuffer;
  final bool isMobile;

  const _HeaderStats({
    required this.score,
    required this.availableBudget,
    required this.spendableBudget,
    required this.safetyBuffer,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _HeaderMiniStat(
        label: 'Score AI',
        value: '$score/100',
      ),
      _HeaderMiniStat(
        label: 'Disponibile',
        value: availableBudget,
      ),
      _HeaderMiniStat(
        label: 'Spendibile',
        value: spendableBudget,
      ),
      _HeaderMiniStat(
        label: 'Sicurezza',
        value: safetyBuffer,
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
    final isMobile = width < 800;

    return Container(
      width: isMobile ? double.infinity : 150,
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

class _SummaryGrid extends StatelessWidget {
  final List<_SummaryItem> items;
  final bool isMobile;

  const _SummaryGrid({
    required this.items,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: items[0]),
              const SizedBox(width: 12),
              Expanded(child: items[1]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: items[2]),
              const SizedBox(width: 12),
              Expanded(child: items[3]),
            ],
          ),
        ],
      );
    }

    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: item == items.last ? 0 : 14,
                ),
                child: item,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 800;

    return Container(
      padding: EdgeInsets.all(isMobile ? 15 : 18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF172033),
              fontWeight: FontWeight.w900,
              fontSize: isMobile ? 18 : 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _AIAdviceCard extends StatelessWidget {
  final List<String> suggestions;
  final String topCategoryName;
  final String topCategoryAmount;
  final double previousTotalExpenses;
  final double totalExpenses;
  final String Function(double) formatMoney;

  const _AIAdviceCard({
    required this.suggestions,
    required this.topCategoryName,
    required this.topCategoryAmount,
    required this.previousTotalExpenses,
    required this.totalExpenses,
    required this.formatMoney,
  });

  String _comparisonText() {
    if (previousTotalExpenses <= 0) {
      return 'Quando avrai dati del mese precedente, qui vedrai anche il confronto automatico.';
    }

    if (totalExpenses > previousTotalExpenses) {
      return 'Questo mese stai spendendo ${formatMoney(totalExpenses - previousTotalExpenses)} in più rispetto al mese scorso.';
    }

    if (totalExpenses < previousTotalExpenses) {
      return 'Questo mese stai spendendo ${formatMoney(previousTotalExpenses - totalExpenses)} in meno rispetto al mese scorso.';
    }

    return 'Questo mese stai spendendo più o meno come il mese scorso.';
  }

  @override
  Widget build(BuildContext context) {
    final visibleSuggestions = suggestions.isEmpty
        ? [
            'Aggiungi entrate, spese e obiettivi per ricevere consigli più precisi.',
          ]
        : suggestions;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Consigli AI',
            subtitle: 'Analisi automatica basata sui tuoi dati del mese.',
            icon: Icons.psychology_alt_rounded,
          ),
          const SizedBox(height: 18),
          ...visibleSuggestions.take(4).map(
                (suggestion) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AdviceRow(
                    text: suggestion,
                  ),
                ),
              ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
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
                const Text(
                  'Confronto rapido',
                  style: TextStyle(
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _comparisonText(),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                if (topCategoryName.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoBadge(
                    text: 'Categoria più alta: $topCategoryName · $topCategoryAmount',
                    icon: Icons.pie_chart_rounded,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdviceRow extends StatelessWidget {
  final String text;

  const _AdviceRow({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 16,
            color: Color(0xFF1677F2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _AIChatCard extends StatelessWidget {
  final List<_AIMessage> messages;
  final TextEditingController controller;
  final ScrollController scrollController;
  final bool isAsking;
  final VoidCallback onSend;
  final Future<void> Function(String question) onQuickQuestion;

  const _AIChatCard({
    required this.messages,
    required this.controller,
    required this.scrollController,
    required this.isAsking,
    required this.onSend,
    required this.onQuickQuestion,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 800;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Parla con PocketPlan',
            subtitle: 'Fai domande in base alla tua situazione finanziaria.',
            icon: Icons.chat_bubble_rounded,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickQuestionChip(
                label: 'Posso spendere 100€?',
                onTap: () => onQuickQuestion('Posso spendere 100 euro?'),
              ),
              _QuickQuestionChip(
                label: 'Quanto posso risparmiare?',
                onTap: () => onQuickQuestion('Quanto posso risparmiare questo mese?'),
              ),
              _QuickQuestionChip(
                label: 'Sto spendendo troppo?',
                onTap: () => onQuickQuestion('Sto spendendo troppo questo mese?'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: isMobile ? 330 : 390,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFE),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE5ECF5),
              ),
            ),
            child: ListView.builder(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              itemCount: messages.length + (isAsking ? 1 : 0),
              itemBuilder: (context, index) {
                if (isAsking && index == messages.length) {
                  return const _TypingBubble();
                }

                final message = messages[index];

                return _ChatBubble(
                  message: message,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Chiedi qualcosa al tuo AI Planner...',
                    filled: true,
                    fillColor: const Color(0xFFF7FAFE),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFFE5ECF5),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFFE5ECF5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFF1677F2),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 52,
                height: 52,
                child: ElevatedButton(
                  onPressed: isAsking ? null : onSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1677F2),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE5ECF5),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: isAsking
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickQuestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickQuestionChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE3F2FD),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1565C0),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _AIMessage message;

  const _ChatBubble({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF1677F2) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: const Color(0xFFE5ECF5),
                ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF334155),
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: const Color(0xFFE5ECF5),
          ),
        ),
        child: const Text(
          'Sto analizzando i tuoi dati...',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _BudgetBreakdownCard extends StatelessWidget {
  final String paidExpenses;
  final String unpaidExpenses;
  final String plannedExpenses;
  final String totalExpenses;
  final String availableBudget;
  final String safetyBuffer;
  final String spendableBudget;
  final double availableRaw;

  const _BudgetBreakdownCard({
    required this.paidExpenses,
    required this.unpaidExpenses,
    required this.plannedExpenses,
    required this.totalExpenses,
    required this.availableBudget,
    required this.safetyBuffer,
    required this.spendableBudget,
    required this.availableRaw,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = availableRaw >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Piano del mese',
            subtitle: 'Come sono distribuiti entrate, spese e margine.',
            icon: Icons.account_tree_rounded,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _BreakdownTile(
                label: 'Spese pagate',
                value: paidExpenses,
                color: const Color(0xFF64748B),
                icon: Icons.check_circle_rounded,
              ),
              _BreakdownTile(
                label: 'Da pagare',
                value: unpaidExpenses,
                color: const Color(0xFFF59E0B),
                icon: Icons.schedule_rounded,
              ),
              _BreakdownTile(
                label: 'Pianificate',
                value: plannedExpenses,
                color: const Color(0xFF7C3AED),
                icon: Icons.event_note_rounded,
              ),
              _BreakdownTile(
                label: 'Totale uscite',
                value: totalExpenses,
                color: const Color(0xFFDC2626),
                icon: Icons.receipt_long_rounded,
              ),
              _BreakdownTile(
                label: 'Disponibile',
                value: availableBudget,
                color: isPositive ? const Color(0xFF1677F2) : const Color(0xFFDC2626),
                icon: Icons.account_balance_wallet_rounded,
              ),
              _BreakdownTile(
                label: 'Margine sicurezza',
                value: safetyBuffer,
                color: const Color(0xFF0F766E),
                icon: Icons.shield_rounded,
              ),
              _BreakdownTile(
                label: 'Spendibile AI',
                value: spendableBudget,
                color: const Color(0xFF16A34A),
                icon: Icons.savings_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _BreakdownTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 800;

    return Container(
      width: isMobile ? double.infinity : 250,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
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

class _CategoriesCard extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String Function(dynamic value) formatMoney;

  const _CategoriesCard({
    required this.categories,
    required this.formatMoney,
  });

  double _amountFrom(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final visibleCategories = categories.take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Categorie più pesanti',
            subtitle: 'Dove stanno andando i soldi questo mese.',
            icon: Icons.pie_chart_rounded,
          ),
          const SizedBox(height: 18),
          if (visibleCategories.isEmpty)
            const _EmptyMiniState(
              icon: Icons.pie_chart_outline_rounded,
              title: 'Nessuna categoria',
              text: 'Quando aggiungi spese, qui vedrai le categorie principali.',
            )
          else
            Column(
              children: visibleCategories.map((category) {
                final name = (category['name'] ?? 'Altro').toString();
                final amount = _amountFrom(category['amount']);
                final percentage = _amountFrom(category['percentage']);

                return _CategoryRow(
                  name: name,
                  amount: formatMoney(amount),
                  percentage: percentage,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String name;
  final String amount;
  final double percentage;

  const _CategoryRow({
    required this.name,
    required this.amount,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (percentage / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                amount,
                style: const TextStyle(
                  color: Color(0xFF172033),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: progress,
              backgroundColor: const Color(0xFFE5ECF5),
              color: const Color(0xFF1677F2),
            ),
          ),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${percentage.toStringAsFixed(0)}% delle uscite',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsPlannerCard extends StatelessWidget {
  final List<Map<String, dynamic>> goals;
  final String Function(dynamic value) formatMoney;
  final DateTime? Function(dynamic value) dateFrom;

  const _GoalsPlannerCard({
    required this.goals,
    required this.formatMoney,
    required this.dateFrom,
  });

  double _amountFrom(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final visibleGoals = goals.take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Obiettivi da seguire',
            subtitle: 'Gli obiettivi attivi più importanti per l’AI Planner.',
            icon: Icons.flag_rounded,
          ),
          const SizedBox(height: 18),
          if (visibleGoals.isEmpty)
            const _EmptyMiniState(
              icon: Icons.flag_outlined,
              title: 'Nessun obiettivo attivo',
              text: 'Crea un obiettivo per ricevere consigli di risparmio più precisi.',
            )
          else
            Column(
              children: visibleGoals.map((goal) {
                final title = (goal['title'] ?? 'Obiettivo').toString();
                final currentAmount = _amountFrom(goal['current_amount']);
                final targetAmount = _amountFrom(goal['target_amount']);
                final remainingAmount = _amountFrom(goal['remaining_amount']);
                final progress = _amountFrom(goal['progress']);
                final daysRemaining = goal['days_remaining'];

                return _GoalPlannerRow(
                  title: title,
                  currentAmount: formatMoney(currentAmount),
                  targetAmount: formatMoney(targetAmount),
                  remainingAmount: formatMoney(remainingAmount),
                  progress: progress,
                  daysRemaining: daysRemaining is int ? daysRemaining : null,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _GoalPlannerRow extends StatelessWidget {
  final String title;
  final String currentAmount;
  final String targetAmount;
  final String remainingAmount;
  final double progress;
  final int? daysRemaining;

  const _GoalPlannerRow({
    required this.title,
    required this.currentAmount,
    required this.targetAmount,
    required this.remainingAmount,
    required this.progress,
    required this.daysRemaining,
  });

  String _daysLabel() {
    if (daysRemaining == null) return 'Senza scadenza';
    if (daysRemaining! < 0) return 'Scaduto';
    if (daysRemaining == 0) return 'Scade oggi';
    if (daysRemaining == 1) return 'Scade domani';

    return '$daysRemaining gg rimasti';
  }

  @override
  Widget build(BuildContext context) {
    final value = (progress / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
          Row(
            children: [
              const Icon(
                Icons.flag_rounded,
                color: Color(0xFF1677F2),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _ColoredBadge(
                text: _daysLabel(),
                color: const Color(0xFF1677F2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: value,
              backgroundColor: const Color(0xFFE5ECF5),
              color: const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoBadge(
                text: 'Risparmiato: $currentAmount',
                icon: Icons.savings_rounded,
              ),
              _InfoBadge(
                text: 'Target: $targetAmount',
                icon: Icons.flag_rounded,
              ),
              _InfoBadge(
                text: 'Mancano: $remainingAmount',
                icon: Icons.timelapse_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final List<Map<String, dynamic>> unpaidExpenses;
  final List<Map<String, dynamic>> upcomingExpenses;
  final String Function(dynamic value) formatMoney;
  final DateTime? Function(dynamic value) dateFrom;

  const _UpcomingCard({
    required this.unpaidExpenses,
    required this.upcomingExpenses,
    required this.formatMoney,
    required this.dateFrom,
  });

  @override
  Widget build(BuildContext context) {
    final items = unpaidExpenses.isNotEmpty ? unpaidExpenses : upcomingExpenses;
    final title = unpaidExpenses.isNotEmpty
        ? 'Spese ancora da pagare'
        : 'Prossime spese';
    final subtitle = unpaidExpenses.isNotEmpty
        ? 'Controlla queste voci prima di fare nuove spese.'
        : 'Le prossime uscite previste dal tuo piano.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: title,
            subtitle: subtitle,
            icon: Icons.event_available_rounded,
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            const _EmptyMiniState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Nessuna scadenza critica',
              text: 'Non risultano spese imminenti o non pagate per questo mese.',
            )
          else
            Column(
              children: items.take(6).map((item) {
                final title = (item['title'] ?? 'Spesa').toString();
                final category = (item['category'] ?? 'Altro').toString();
                final amount = formatMoney(item['amount']);
                final date = dateFrom(item['due_date'] ?? item['date']);

                return _UpcomingExpenseRow(
                  title: title,
                  category: category,
                  amount: amount,
                  date: date,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _UpcomingExpenseRow extends StatelessWidget {
  final String title;
  final String category;
  final String amount;
  final DateTime? date;

  const _UpcomingExpenseRow({
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = date == null
        ? 'Data non indicata'
        : DateFormat('dd/MM/yyyy', 'it_IT').format(date!);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5ECF5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$category · $formattedDate',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: const TextStyle(
              color: Color(0xFF172033),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF1677F2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF172033),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
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
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
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

class _EmptyMiniState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _EmptyMiniState({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5ECF5),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF94A3B8),
            size: 38,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF172033),
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _AIPlannerError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _AIPlannerError({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(28),
          decoration: _cardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFDC2626),
                size: 48,
              ),
              const SizedBox(height: 14),
              const Text(
                'Analisi non disponibile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF172033),
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Non sono riuscito a leggere i dati finanziari. Riprova tra poco oppure controlla entrate, spese e obiettivi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Riprova'),
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
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(26),
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
  );
}