import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AchievementsPage extends StatelessWidget {
  final VoidCallback? onOpenGoals;

  const AchievementsPage({
    super.key,
    this.onOpenGoals,
  });

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _userCollection(String name) {
    return _db.collection('users').doc(_uid).collection(name);
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    if (uid == null) {
      return const _AchievementsAuthRequired();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _userCollection('goals').snapshots(),
      builder: (context, goalsSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _userCollection('expenses').snapshots(),
          builder: (context, expensesSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _userCollection('incomes').snapshots(),
              builder: (context, incomesSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _userCollection('ai_insights').snapshots(),
                  builder: (context, aiSnapshot) {
                    final isLoading =
                        goalsSnapshot.connectionState ==
                                ConnectionState.waiting ||
                            expensesSnapshot.connectionState ==
                                ConnectionState.waiting ||
                            incomesSnapshot.connectionState ==
                                ConnectionState.waiting ||
                            aiSnapshot.connectionState ==
                                ConnectionState.waiting;

                    final goals = goalsSnapshot.data?.docs ?? [];
                    final expenses = expensesSnapshot.data?.docs ?? [];
                    final incomes = incomesSnapshot.data?.docs ?? [];
                    final aiInsights = aiSnapshot.data?.docs ?? [];

                    final stats = _AchievementStats.fromSnapshots(
                      goals: goals,
                      expenses: expenses,
                      incomes: incomes,
                      aiInsights: aiInsights,
                    );

                    return _AchievementsContent(
                      stats: stats,
                      isLoading: isLoading,
                      onOpenGoals: onOpenGoals,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AchievementsContent extends StatelessWidget {
  final _AchievementStats stats;
  final bool isLoading;
  final VoidCallback? onOpenGoals;

  const _AchievementsContent({
    required this.stats,
    required this.isLoading,
    required this.onOpenGoals,
  });

  void _openGoals(BuildContext context) {
    if (onOpenGoals != null) {
      onOpenGoals!.call();
      return;
    }

    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          'Non riesco a tornare agli obiettivi da questa schermata.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _AchievementsTheme.fromContext(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    final allAchievements = _AchievementItem.buildAll(stats);
    final levelProgress = _LevelProgress.fromAchievements(allAchievements);

    final currentLevelAchievements = allAchievements
        .where((item) => item.levelRequired == levelProgress.currentLevel)
        .toList();

    return Material(
      color: theme.scaffold,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMobile)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _MobileAchievementsSectionTabs(
                  selectedSection: _MobileAchievementsSection.achievements,
                  theme: theme,
                  onOpenGoals: () => _openGoals(context),
                ),
              ),
            Expanded(
              child: isLoading
                  ? _AchievementsLoading(theme: theme)
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 16 : 22,
                        isMobile ? 18 : 22,
                        isMobile ? 16 : 22,
                        isMobile ? 120 : 28,
                      ),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Achievements',
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: isMobile ? 27 : 30,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (!isMobile)
                              _SmallActionButton(
                                label: 'Vai agli obiettivi',
                                icon: Icons.flag_rounded,
                                theme: theme,
                                onTap: () => _openGoals(context),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Completa i traguardi del livello attuale per sbloccare quelli successivi.',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _LevelHeroCard(
                          progress: levelProgress,
                          theme: theme,
                        ),
                        const SizedBox(height: 16),
                        _StatsGrid(
                          stats: stats,
                          progress: levelProgress,
                          theme: theme,
                        ),
                        const SizedBox(height: 18),
                        _CurrentLevelHeader(
                          progress: levelProgress,
                          currentLevelAchievements:
                              currentLevelAchievements.length,
                          theme: theme,
                        ),
                        const SizedBox(height: 10),
                        ...currentLevelAchievements.map(
                          (achievement) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _AchievementCard(
                              item: achievement,
                              theme: theme,
                            ),
                          ),
                        ),
                        if (levelProgress.currentLevel <
                            levelProgress.maxLevel) ...[
                          const SizedBox(height: 4),
                          _LockedNextLevelCard(
                            nextLevel: levelProgress.currentLevel + 1,
                            theme: theme,
                          ),
                        ] else if (levelProgress.isLastLevelCompleted) ...[
                          const SizedBox(height: 4),
                          _AllCompletedCard(theme: theme),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementsAuthRequired extends StatelessWidget {
  const _AchievementsAuthRequired();

  @override
  Widget build(BuildContext context) {
    final theme = _AchievementsTheme.fromContext(context);

    return Material(
      color: theme.scaffold,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: theme.border),
          ),
          child: Text(
            'Devi effettuare l’accesso per vedere i tuoi achievements.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementsLoading extends StatelessWidget {
  final _AchievementsTheme theme;

  const _AchievementsLoading({
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: theme.primary,
      ),
    );
  }
}

class _AchievementStats {
  final int totalGoals;
  final int completedGoals;
  final int activeGoals;
  final int expensesCount;
  final int incomesCount;
  final int aiInsightsCount;

  const _AchievementStats({
    required this.totalGoals,
    required this.completedGoals,
    required this.activeGoals,
    required this.expensesCount,
    required this.incomesCount,
    required this.aiInsightsCount,
  });

  factory _AchievementStats.fromSnapshots({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> goals,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> expenses,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> incomes,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> aiInsights,
  }) {
    final totalGoals = goals.length;

    final completedGoals = goals.where((goal) {
      return _goalIsCompleted(goal.data());
    }).length;

    final activeGoals = math.max(0, totalGoals - completedGoals);

    return _AchievementStats(
      totalGoals: totalGoals,
      completedGoals: completedGoals,
      activeGoals: activeGoals,
      expensesCount: expenses.length,
      incomesCount: incomes.length,
      aiInsightsCount: aiInsights.length,
    );
  }

  static bool _goalIsCompleted(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase().trim();

    final boolFields = [
      data['is_completed'],
      data['completed'],
      data['isCompleted'],
    ];

    final hasCompletedBool = boolFields.any((value) => value == true);

    final hasCompletedStatus = status == 'completed' ||
        status == 'completato' ||
        status == 'complete' ||
        status == 'done' ||
        status == 'closed';

    final hasCompletedDate =
        data['completed_at'] != null || data['completedAt'] != null;

    final targetAmount = _amountFromAny([
      data['target_amount'],
      data['targetAmount'],
      data['amount'],
      data['goal_amount'],
      data['goalAmount'],
    ]);

    final currentAmount = _amountFromAny([
      data['current_amount'],
      data['currentAmount'],
      data['saved_amount'],
      data['savedAmount'],
      data['progress_amount'],
      data['progressAmount'],
      data['collected_amount'],
      data['collectedAmount'],
    ]);

    final reachedByAmount = targetAmount > 0 && currentAmount >= targetAmount;

    return hasCompletedBool ||
        hasCompletedStatus ||
        hasCompletedDate ||
        reachedByAmount;
  }

  static double _amountFromAny(List<dynamic> values) {
    for (final value in values) {
      final parsed = _amountFrom(value);
      if (parsed > 0) return parsed;
    }

    return 0;
  }

  static double _amountFrom(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    if (value is String) {
      final normalized = value.replaceAll(',', '.').trim();
      return double.tryParse(normalized) ?? 0;
    }

    return 0;
  }
}

class _LevelProgress {
  final int currentLevel;
  final int maxLevel;
  final int totalPoints;
  final int unlockedAchievements;
  final int totalAchievements;
  final int currentLevelUnlocked;
  final int currentLevelTotal;
  final double currentLevelProgress;
  final bool isLastLevelCompleted;

  const _LevelProgress({
    required this.currentLevel,
    required this.maxLevel,
    required this.totalPoints,
    required this.unlockedAchievements,
    required this.totalAchievements,
    required this.currentLevelUnlocked,
    required this.currentLevelTotal,
    required this.currentLevelProgress,
    required this.isLastLevelCompleted,
  });

  factory _LevelProgress.fromAchievements(List<_AchievementItem> achievements) {
    final maxLevel = achievements.fold<int>(
      1,
      (previous, item) => math.max(previous, item.levelRequired),
    );

    var currentLevel = 1;

    for (var level = 1; level <= maxLevel; level++) {
      final levelItems =
          achievements.where((item) => item.levelRequired == level).toList();

      if (levelItems.isEmpty) {
        continue;
      }

      final completed = levelItems.every((item) => item.isUnlocked);

      if (completed && level < maxLevel) {
        currentLevel = level + 1;
      } else {
        currentLevel = level;
        break;
      }
    }

    final currentItems = achievements
        .where((item) => item.levelRequired == currentLevel)
        .toList();

    final currentUnlocked =
        currentItems.where((item) => item.isUnlocked).length;

    final currentTotal = currentItems.length;

    final currentProgress = currentTotal == 0
        ? 0.0
        : (currentUnlocked / currentTotal).clamp(0.0, 1.0);

    final unlockedAchievements =
        achievements.where((item) => item.isUnlocked).length;

    final totalPoints = achievements
        .where((item) => item.isUnlocked)
        .fold<int>(0, (sum, item) => sum + item.rewardPoints);

    final lastLevelItems =
        achievements.where((item) => item.levelRequired == maxLevel).toList();

    final isLastLevelCompleted = currentLevel == maxLevel &&
        lastLevelItems.isNotEmpty &&
        lastLevelItems.every((item) => item.isUnlocked);

    return _LevelProgress(
      currentLevel: currentLevel,
      maxLevel: maxLevel,
      totalPoints: totalPoints,
      unlockedAchievements: unlockedAchievements,
      totalAchievements: achievements.length,
      currentLevelUnlocked: currentUnlocked,
      currentLevelTotal: currentTotal,
      currentLevelProgress: currentProgress,
      isLastLevelCompleted: isLastLevelCompleted,
    );
  }

  String get levelTitle {
    switch (currentLevel) {
      case 1:
        return 'Nuovo risparmiatore';
      case 2:
        return 'Prime abitudini';
      case 3:
        return 'Pianificatore in crescita';
      case 4:
        return 'Controllo spese';
      case 5:
        return 'Risparmiatore esperto';
      case 6:
        return 'Stratega finanziario';
      case 7:
        return 'Maestro del budget';
      case 8:
        return 'Pianificatore avanzato';
      case 9:
        return 'Mentalità finanziaria';
      case 10:
        return 'PocketPlan Master';
      default:
        return 'PocketPlan Master';
    }
  }
}

class _AchievementItem {
  final int levelRequired;
  final IconData icon;
  final String title;
  final String description;
  final String howToUnlock;
  final int current;
  final int target;
  final int rewardPoints;

  const _AchievementItem({
    required this.levelRequired,
    required this.icon,
    required this.title,
    required this.description,
    required this.howToUnlock,
    required this.current,
    required this.target,
    required this.rewardPoints,
  });

  bool get isUnlocked => current >= target;

  double get progress {
    if (target <= 0) return 0;
    return (current / target).clamp(0.0, 1.0);
  }

  String get progressLabel {
    return '${math.min(current, target)} / $target';
  }

  static List<_AchievementItem> buildAll(_AchievementStats stats) {
    return [
      _AchievementItem(
        levelRequired: 1,
        icon: Icons.flag_rounded,
        title: 'Primo obiettivo creato',
        description: 'Inizia il tuo percorso creando il primo obiettivo.',
        howToUnlock: 'Crea almeno 1 obiettivo nella sezione Obiettivi.',
        current: stats.totalGoals,
        target: 1,
        rewardPoints: 20,
      ),
      _AchievementItem(
        levelRequired: 1,
        icon: Icons.receipt_long_rounded,
        title: 'Prima spesa registrata',
        description: 'Inizia a monitorare le tue uscite quotidiane.',
        howToUnlock: 'Registra almeno 1 spesa nella sezione Spese.',
        current: stats.expensesCount,
        target: 1,
        rewardPoints: 30,
      ),
      _AchievementItem(
        levelRequired: 1,
        icon: Icons.trending_up_rounded,
        title: 'Prima entrata registrata',
        description: 'Aggiungi la tua prima fonte di entrata.',
        howToUnlock: 'Registra almeno 1 entrata nella sezione Entrate.',
        current: stats.incomesCount,
        target: 1,
        rewardPoints: 30,
      ),
      _AchievementItem(
        levelRequired: 2,
        icon: Icons.flag_circle_rounded,
        title: 'Tre obiettivi creati',
        description: 'Comincia a pianificare più aspetti della tua vita.',
        howToUnlock: 'Crea almeno 3 obiettivi nella sezione Obiettivi.',
        current: stats.totalGoals,
        target: 3,
        rewardPoints: 60,
      ),
      _AchievementItem(
        levelRequired: 2,
        icon: Icons.format_list_numbered_rounded,
        title: 'Prime 5 spese',
        description: 'Più dati inserisci, più PocketPlan diventa utile.',
        howToUnlock: 'Registra almeno 5 spese.',
        current: stats.expensesCount,
        target: 5,
        rewardPoints: 60,
      ),
      _AchievementItem(
        levelRequired: 2,
        icon: Icons.auto_awesome_rounded,
        title: 'AI Planner attivato',
        description: 'Ricevi il primo consiglio intelligente da PocketPlan.',
        howToUnlock: 'Ricevi almeno 1 insight o consiglio dall’AI Planner.',
        current: stats.aiInsightsCount,
        target: 1,
        rewardPoints: 50,
      ),
      _AchievementItem(
        levelRequired: 3,
        icon: Icons.emoji_events_rounded,
        title: 'Primo obiettivo completato',
        description: 'Porta a termine il tuo primo vero traguardo.',
        howToUnlock:
            'Completa almeno 1 obiettivo raggiungendo l’importo previsto.',
        current: stats.completedGoals,
        target: 1,
        rewardPoints: 120,
      ),
      _AchievementItem(
        levelRequired: 3,
        icon: Icons.account_balance_wallet_rounded,
        title: 'Entrate sotto controllo',
        description:
            'Tieni traccia delle entrate per avere un quadro più preciso.',
        howToUnlock: 'Registra almeno 5 entrate.',
        current: stats.incomesCount,
        target: 5,
        rewardPoints: 90,
      ),
      _AchievementItem(
        levelRequired: 3,
        icon: Icons.assignment_turned_in_rounded,
        title: '10 spese registrate',
        description: 'Costruisci una prima base reale delle tue abitudini.',
        howToUnlock: 'Registra almeno 10 spese.',
        current: stats.expensesCount,
        target: 10,
        rewardPoints: 90,
      ),
      _AchievementItem(
        levelRequired: 4,
        icon: Icons.savings_rounded,
        title: 'Costruttore di obiettivi',
        description: 'Crea una pianificazione più completa.',
        howToUnlock: 'Crea almeno 5 obiettivi.',
        current: stats.totalGoals,
        target: 5,
        rewardPoints: 120,
      ),
      _AchievementItem(
        levelRequired: 4,
        icon: Icons.psychology_alt_rounded,
        title: 'Consulente personale',
        description: 'Usa l’AI Planner più volte per migliorare le decisioni.',
        howToUnlock: 'Ricevi almeno 5 insight o consigli dall’AI Planner.',
        current: stats.aiInsightsCount,
        target: 5,
        rewardPoints: 120,
      ),
      _AchievementItem(
        levelRequired: 4,
        icon: Icons.list_alt_rounded,
        title: '25 spese registrate',
        description: 'Inizia ad avere uno storico davvero utile delle tue uscite.',
        howToUnlock: 'Registra almeno 25 spese.',
        current: stats.expensesCount,
        target: 25,
        rewardPoints: 140,
      ),
      _AchievementItem(
        levelRequired: 5,
        icon: Icons.workspace_premium_rounded,
        title: 'Tre obiettivi completati',
        description: 'Dimostra costanza completando più obiettivi nel tempo.',
        howToUnlock: 'Completa almeno 3 obiettivi di risparmio.',
        current: stats.completedGoals,
        target: 3,
        rewardPoints: 260,
      ),
      _AchievementItem(
        levelRequired: 5,
        icon: Icons.payments_rounded,
        title: '10 entrate registrate',
        description: 'Rendi più completo il quadro delle tue entrate.',
        howToUnlock: 'Registra almeno 10 entrate.',
        current: stats.incomesCount,
        target: 10,
        rewardPoints: 150,
      ),
      _AchievementItem(
        levelRequired: 5,
        icon: Icons.insights_rounded,
        title: '10 consigli AI',
        description: 'Fatti guidare più volte dall’intelligenza di PocketPlan.',
        howToUnlock: 'Ricevi almeno 10 insight o consigli dall’AI Planner.',
        current: stats.aiInsightsCount,
        target: 10,
        rewardPoints: 180,
      ),
      _AchievementItem(
        levelRequired: 6,
        icon: Icons.military_tech_rounded,
        title: 'Cinque obiettivi completati',
        description:
            'Raggiungi un traguardo importante nella crescita finanziaria.',
        howToUnlock: 'Completa almeno 5 obiettivi di risparmio.',
        current: stats.completedGoals,
        target: 5,
        rewardPoints: 420,
      ),
      _AchievementItem(
        levelRequired: 6,
        icon: Icons.receipt_rounded,
        title: '50 spese registrate',
        description: 'Hai abbastanza dati per capire molte abitudini reali.',
        howToUnlock: 'Registra almeno 50 spese.',
        current: stats.expensesCount,
        target: 50,
        rewardPoints: 250,
      ),
      _AchievementItem(
        levelRequired: 6,
        icon: Icons.flag_rounded,
        title: '10 obiettivi creati',
        description: 'Organizza tanti traguardi diversi nel tuo percorso.',
        howToUnlock: 'Crea almeno 10 obiettivi.',
        current: stats.totalGoals,
        target: 10,
        rewardPoints: 220,
      ),
      _AchievementItem(
        levelRequired: 7,
        icon: Icons.stacked_line_chart_rounded,
        title: '75 spese registrate',
        description: 'Raggiungi uno storico avanzato delle tue uscite.',
        howToUnlock: 'Registra almeno 75 spese.',
        current: stats.expensesCount,
        target: 75,
        rewardPoints: 300,
      ),
      _AchievementItem(
        levelRequired: 7,
        icon: Icons.ssid_chart_rounded,
        title: '15 entrate registrate',
        description: 'Tieni traccia in modo costante delle tue fonti di denaro.',
        howToUnlock: 'Registra almeno 15 entrate.',
        current: stats.incomesCount,
        target: 15,
        rewardPoints: 240,
      ),
      _AchievementItem(
        levelRequired: 7,
        icon: Icons.auto_graph_rounded,
        title: '15 consigli AI',
        description: 'Usa PocketPlan come supporto ricorrente alle decisioni.',
        howToUnlock: 'Ricevi almeno 15 insight o consigli dall’AI Planner.',
        current: stats.aiInsightsCount,
        target: 15,
        rewardPoints: 260,
      ),
      _AchievementItem(
        levelRequired: 8,
        icon: Icons.workspace_premium_rounded,
        title: '8 obiettivi completati',
        description: 'Raggiungi una continuità importante nel risparmio.',
        howToUnlock: 'Completa almeno 8 obiettivi di risparmio.',
        current: stats.completedGoals,
        target: 8,
        rewardPoints: 600,
      ),
      _AchievementItem(
        levelRequired: 8,
        icon: Icons.savings_rounded,
        title: '15 obiettivi creati',
        description: 'Costruisci una pianificazione finanziaria molto completa.',
        howToUnlock: 'Crea almeno 15 obiettivi.',
        current: stats.totalGoals,
        target: 15,
        rewardPoints: 320,
      ),
      _AchievementItem(
        levelRequired: 8,
        icon: Icons.fact_check_rounded,
        title: '100 spese registrate',
        description: 'Hai uno storico solido per analizzare le tue abitudini.',
        howToUnlock: 'Registra almeno 100 spese.',
        current: stats.expensesCount,
        target: 100,
        rewardPoints: 380,
      ),
      _AchievementItem(
        levelRequired: 9,
        icon: Icons.diamond_rounded,
        title: '10 obiettivi completati',
        description:
            'Dimostra grande costanza nel raggiungere i tuoi traguardi.',
        howToUnlock: 'Completa almeno 10 obiettivi di risparmio.',
        current: stats.completedGoals,
        target: 10,
        rewardPoints: 800,
      ),
      _AchievementItem(
        levelRequired: 9,
        icon: Icons.account_balance_rounded,
        title: '25 entrate registrate',
        description: 'Rendi estremamente preciso il quadro delle tue entrate.',
        howToUnlock: 'Registra almeno 25 entrate.',
        current: stats.incomesCount,
        target: 25,
        rewardPoints: 360,
      ),
      _AchievementItem(
        levelRequired: 9,
        icon: Icons.smart_toy_rounded,
        title: '25 consigli AI',
        description: 'Sfrutta spesso l’AI per prendere decisioni migliori.',
        howToUnlock: 'Ricevi almeno 25 insight o consigli dall’AI Planner.',
        current: stats.aiInsightsCount,
        target: 25,
        rewardPoints: 420,
      ),
      _AchievementItem(
        levelRequired: 10,
        icon: Icons.emoji_events_rounded,
        title: 'PocketPlan Master',
        description: 'Raggiungi il livello massimo della prima versione.',
        howToUnlock: 'Completa almeno 15 obiettivi di risparmio.',
        current: stats.completedGoals,
        target: 15,
        rewardPoints: 1000,
      ),
      _AchievementItem(
        levelRequired: 10,
        icon: Icons.receipt_long_rounded,
        title: '150 spese registrate',
        description: 'Hai costruito uno storico molto completo delle tue uscite.',
        howToUnlock: 'Registra almeno 150 spese.',
        current: stats.expensesCount,
        target: 150,
        rewardPoints: 520,
      ),
      _AchievementItem(
        levelRequired: 10,
        icon: Icons.auto_awesome_rounded,
        title: '50 consigli AI',
        description: 'Hai usato PocketPlan come un vero assistente finanziario.',
        howToUnlock: 'Ricevi almeno 50 insight o consigli dall’AI Planner.',
        current: stats.aiInsightsCount,
        target: 50,
        rewardPoints: 650,
      ),
    ];
  }
}

class _LevelHeroCard extends StatelessWidget {
  final _LevelProgress progress;
  final _AchievementsTheme theme;

  const _LevelHeroCard({
    required this.progress,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.isDark
              ? const [
                  Color(0xFF172033),
                  Color(0xFF123456),
                ]
              : const [
                  Color(0xFFFFFFFF),
                  Color(0xFFEAF4FF),
                ],
        ),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.isDark ? 0.22 : 0.06),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LevelBadge(progress: progress, theme: theme),
                const SizedBox(height: 18),
                _LevelInfo(progress: progress, theme: theme),
              ],
            )
          : Row(
              children: [
                _LevelBadge(progress: progress, theme: theme),
                const SizedBox(width: 22),
                Expanded(
                  child: _LevelInfo(progress: progress, theme: theme),
                ),
              ],
            ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final _LevelProgress progress;
  final _AchievementsTheme theme;

  const _LevelBadge({
    required this.progress,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.primarySoft,
        border: Border.all(
          color: theme.primary.withValues(alpha: 0.26),
          width: 2,
        ),
      ),
      child: Center(
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.primary,
            boxShadow: [
              BoxShadow(
                color: theme.primary.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(height: 3),
              Text(
                'LV ${progress.currentLevel}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelInfo extends StatelessWidget {
  final _LevelProgress progress;
  final _AchievementsTheme theme;

  const _LevelInfo({
    required this.progress,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final completedText =
        '${progress.currentLevelUnlocked} / ${progress.currentLevelTotal}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          progress.levelTitle,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          progress.isLastLevelCompleted
              ? 'Hai completato tutti gli achievement disponibili.'
              : 'Completa gli achievement del livello ${progress.currentLevel} per sbloccare il livello ${progress.currentLevel + 1}.',
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.currentLevelProgress,
            minHeight: 11,
            backgroundColor: theme.primarySoft,
            valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Progresso livello: $completedText achievement • ${progress.totalPoints} punti totali',
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CurrentLevelHeader extends StatelessWidget {
  final _LevelProgress progress;
  final int currentLevelAchievements;
  final _AchievementsTheme theme;

  const _CurrentLevelHeader({
    required this.progress,
    required this.currentLevelAchievements,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Livello ${progress.currentLevel} - Achievement sbloccati',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: theme.primarySoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$currentLevelAchievements obiettivi',
            style: TextStyle(
              color: theme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final _AchievementStats stats;
  final _LevelProgress progress;
  final _AchievementsTheme theme;

  const _StatsGrid({
    required this.stats,
    required this.progress,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    final items = [
      _StatItem(
        icon: Icons.flag_rounded,
        label: 'Obiettivi',
        value: '${stats.totalGoals}',
      ),
      _StatItem(
        icon: Icons.check_circle_rounded,
        label: 'Completati',
        value: '${stats.completedGoals}',
      ),
      _StatItem(
        icon: Icons.emoji_events_rounded,
        label: 'Achievement',
        value: '${progress.unlockedAchievements}',
      ),
      _StatItem(
        icon: Icons.stars_rounded,
        label: 'Punti',
        value: '${progress.totalPoints}',
      ),
    ];

    if (isMobile) {
      return Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StatCard(
                  item: item,
                  theme: theme,
                ),
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _StatCard(
                  item: item,
                  theme: theme,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  final _AchievementsTheme theme;

  const _StatCard({
    required this.item,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.primarySoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              item.icon,
              color: theme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
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

class _AchievementCard extends StatelessWidget {
  final _AchievementItem item;
  final _AchievementsTheme theme;

  const _AchievementCard({
    required this.item,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    final foreground = item.isUnlocked ? theme.success : theme.primary;
    final soft = item.isUnlocked ? theme.successSoft : theme.primarySoft;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.all(isMobile ? 16 : 18),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: item.isUnlocked
              ? theme.success.withValues(alpha: 0.35)
              : theme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.isDark ? 0.16 : 0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: isMobile ? 54 : 58,
                height: isMobile ? 54 : 58,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Icon(
                  item.icon,
                  color: foreground,
                  size: isMobile ? 27 : 29,
                ),
              ),
              if (item.isUnlocked)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    width: 23,
                    height: 23,
                    decoration: BoxDecoration(
                      color: theme.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.card,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PointsChip(
                      points: item.rewardPoints,
                      unlocked: item.isUnlocked,
                      theme: theme,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item.description,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.32,
                  ),
                ),
                const SizedBox(height: 10),
                _AchievementLegendBox(
                  text: item.howToUnlock,
                  theme: theme,
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: item.progress,
                          minHeight: 8,
                          backgroundColor: soft,
                          valueColor: AlwaysStoppedAnimation<Color>(foreground),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      item.isUnlocked ? 'Sbloccato' : item.progressLabel,
                      style: TextStyle(
                        color: item.isUnlocked
                            ? theme.success
                            : theme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementLegendBox extends StatelessWidget {
  final String text;
  final _AchievementsTheme theme;

  const _AchievementLegendBox({
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: theme.isDark
            ? Colors.white.withValues(alpha: 0.045)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE5ECF5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: theme.primary,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Come si ottiene: ',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                    ),
                  ),
                  TextSpan(
                    text: text,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsChip extends StatelessWidget {
  final int points;
  final bool unlocked;
  final _AchievementsTheme theme;

  const _PointsChip({
    required this.points,
    required this.unlocked,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: unlocked ? theme.successSoft : theme.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '+$points pt',
        style: TextStyle(
          color: unlocked ? theme.success : theme.primary,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LockedNextLevelCard extends StatelessWidget {
  final int nextLevel;
  final _AchievementsTheme theme;

  const _LockedNextLevelCard({
    required this.nextLevel,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.lock_rounded,
              color: theme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Completa tutti gli achievement visibili per sbloccare il livello $nextLevel.',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllCompletedCard extends StatelessWidget {
  final _AchievementsTheme theme;

  const _AllCompletedCard({
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.successSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.success.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.celebration_rounded,
            color: theme.success,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Hai completato tutti gli achievement disponibili. Sei ufficialmente un PocketPlan Master!',
              style: TextStyle(
                color: theme.success,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MobileAchievementsSection {
  goals,
  achievements,
}

class _MobileAchievementsSectionTabs extends StatelessWidget {
  final _MobileAchievementsSection selectedSection;
  final _AchievementsTheme theme;
  final VoidCallback? onOpenGoals;

  const _MobileAchievementsSectionTabs({
    required this.selectedSection,
    required this.theme,
    required this.onOpenGoals,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.isDark ? 0.18 : 0.035,
            ),
            blurRadius: theme.isDark ? 22 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _MobileAchievementsSectionTabButton(
              label: 'Obiettivi',
              icon: Icons.flag_rounded,
              selected: selectedSection == _MobileAchievementsSection.goals,
              theme: theme,
              onTap: onOpenGoals ?? () {},
            ),
          ),
          Expanded(
            child: _MobileAchievementsSectionTabButton(
              label: 'Achievements',
              icon: Icons.emoji_events_rounded,
              selected:
                  selectedSection == _MobileAchievementsSection.achievements,
              theme: theme,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileAchievementsSectionTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final _AchievementsTheme theme;
  final VoidCallback onTap;

  const _MobileAchievementsSectionTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = selected ? theme.primarySoft : Colors.transparent;
    final foregroundColor = selected ? theme.primary : theme.textSecondary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 44,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: foregroundColor,
                size: 18,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
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

class _SmallActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final _AchievementsTheme theme;
  final VoidCallback? onTap;

  const _SmallActionButton({
    required this.label,
    required this.icon,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.primary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 11,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementsTheme {
  final bool isDark;
  final Color scaffold;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;
  final Color primarySoft;
  final Color success;
  final Color successSoft;

  const _AchievementsTheme({
    required this.isDark,
    required this.scaffold,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.primarySoft,
    required this.success,
    required this.successSoft,
  });

  factory _AchievementsTheme.fromContext(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _AchievementsTheme(
      isDark: isDark,
      scaffold: isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F8FC),
      card: isDark ? const Color(0xFF172033) : Colors.white,
      border: isDark ? const Color(0xFF334155) : const Color(0xFFE5ECF5),
      textPrimary: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF172033),
      textSecondary: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
      primary: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1677F2),
      primarySoft: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3F2FD),
      success: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
      successSoft: isDark ? const Color(0xFF123B2A) : const Color(0xFFE8F8EF),
    );
  }
}