import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'watch_sync_service.dart';

class FinanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final WatchSyncService _watchSyncService = WatchSyncService();

  String get _uid {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Utente non autenticato');
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get incomesRef {
    return _db.collection('users').doc(_uid).collection('incomes');
  }

  CollectionReference<Map<String, dynamic>> get expensesRef {
    return _db.collection('users').doc(_uid).collection('expenses');
  }

  CollectionReference<Map<String, dynamic>> get goalsRef {
    return _db.collection('users').doc(_uid).collection('goals');
  }

  CollectionReference<Map<String, dynamic>> get watchSummaryRef {
    return _db.collection('users').doc(_uid).collection('watch_summary');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> incomesStream() {
    return incomesRef.orderBy('date', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> expensesStream() {
    return expensesRef.orderBy('created_at', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> goalsStream() {
    return goalsRef.orderBy('deadline', descending: false).snapshots();
  }

  Future<void> addIncome({
    required String title,
    required double amount,
    required DateTime date,
  }) async {
    await incomesRef.add({
      'title': title.trim(),
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _refreshWatchSummarySafely();
  }

  Future<void> updateIncome({
    required String incomeId,
    required String title,
    required double amount,
    required DateTime date,
  }) async {
    await incomesRef.doc(incomeId).update({
      'title': title.trim(),
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _refreshWatchSummarySafely();
  }

  Future<void> deleteIncome({
    required String incomeId,
  }) async {
    await incomesRef.doc(incomeId).delete();

    await _refreshWatchSummarySafely();
  }

  Future<void> addExpense({
    required String title,
    required double amount,
    required DateTime? dueDate,
    required String category,
    required bool isPaid,
    required bool reminderEnabled,
    String type = 'standard',
    DateTime? month,
    bool repeatMonthly = false,
    DateTime? repeatUntilDate,
    String? repeatGroupId,
    int? repeatIndex,
    int? repeatTotal,
  }) async {
    final isPlanned = type == 'planned';

    await expensesRef.add({
      'title': title.trim(),
      'amount': amount,
      'category': category.trim(),
      'type': isPlanned ? 'planned' : 'standard',
      'due_date': isPlanned || dueDate == null
          ? null
          : Timestamp.fromDate(dueDate),
      'month': isPlanned && month != null
          ? Timestamp.fromDate(DateTime(month.year, month.month))
          : null,
      'is_paid': isPlanned ? false : isPaid,
      'reminder_enabled': isPlanned ? false : reminderEnabled,
      'split_items': <Map<String, dynamic>>[],
      'repeat_monthly': isPlanned ? false : repeatMonthly,
      'repeat_until_date': !isPlanned && repeatUntilDate != null
          ? Timestamp.fromDate(repeatUntilDate)
          : null,
      'repeat_group_id': !isPlanned ? repeatGroupId : null,
      'repeat_index': !isPlanned ? repeatIndex : null,
      'repeat_total': !isPlanned ? repeatTotal : null,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _refreshWatchSummarySafely();
  }

  Future<void> addRecurringMonthlyExpense({
    required String title,
    required double amount,
    required DateTime firstDueDate,
    required DateTime repeatUntilDate,
    required String category,
    required bool reminderEnabled,
  }) async {
    if (repeatUntilDate.isBefore(firstDueDate)) {
      throw Exception(
        'La data di fine rata deve essere successiva alla prima scadenza',
      );
    }

    final dueDates = _monthlyDueDates(
      startDate: firstDueDate,
      endDate: repeatUntilDate,
    );

    if (dueDates.isEmpty) {
      throw Exception('Nessuna rata mensile da creare');
    }

    final repeatGroupId = expensesRef.doc().id;
    final batch = _db.batch();

    for (var i = 0; i < dueDates.length; i++) {
      final docRef = expensesRef.doc();
      final dueDate = dueDates[i];

      batch.set(docRef, {
        'title': title.trim(),
        'amount': amount,
        'category': category.trim(),
        'type': 'standard',
        'due_date': Timestamp.fromDate(dueDate),
        'month': null,
        'is_paid': false,
        'reminder_enabled': reminderEnabled,
        'split_items': <Map<String, dynamic>>[],
        'repeat_monthly': true,
        'repeat_until_date': Timestamp.fromDate(repeatUntilDate),
        'repeat_group_id': repeatGroupId,
        'repeat_index': i + 1,
        'repeat_total': dueDates.length,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    await _refreshWatchSummarySafely();
  }

  Future<void> updateExpense({
    required String expenseId,
    required String title,
    required double amount,
    required DateTime? dueDate,
    required String category,
    required bool isPaid,
    required bool reminderEnabled,
    String type = 'standard',
    DateTime? month,
    bool repeatMonthly = false,
    DateTime? repeatUntilDate,
    String? repeatGroupId,
    int? repeatIndex,
    int? repeatTotal,
  }) async {
    final isPlanned = type == 'planned';

    await expensesRef.doc(expenseId).update({
      'title': title.trim(),
      'amount': amount,
      'category': category.trim(),
      'type': isPlanned ? 'planned' : 'standard',
      'due_date': isPlanned || dueDate == null
          ? null
          : Timestamp.fromDate(dueDate),
      'month': isPlanned && month != null
          ? Timestamp.fromDate(DateTime(month.year, month.month))
          : null,
      'is_paid': isPlanned ? false : isPaid,
      'reminder_enabled': isPlanned ? false : reminderEnabled,
      'repeat_monthly': isPlanned ? false : repeatMonthly,
      'repeat_until_date': !isPlanned && repeatUntilDate != null
          ? Timestamp.fromDate(repeatUntilDate)
          : null,
      'repeat_group_id': !isPlanned ? repeatGroupId : null,
      'repeat_index': !isPlanned ? repeatIndex : null,
      'repeat_total': !isPlanned ? repeatTotal : null,
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _refreshWatchSummarySafely();
  }

  Future<void> updateExpensePaid({
    required String expenseId,
    required bool isPaid,
  }) async {
    await expensesRef.doc(expenseId).update({
      'is_paid': isPaid,
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _refreshWatchSummarySafely();
  }

  Future<void> addExpenseSplitPayment({
    required String expenseId,
    required String title,
    required double amount,
    required DateTime paidAt,
  }) async {
    final docRef = expensesRef.doc(expenseId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception('Spesa non trovata');
      }

      final data = snapshot.data() ?? {};
      final rawItems = data['split_items'];

      final List<Map<String, dynamic>> currentItems = rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      currentItems.add({
        'title': title.trim(),
        'amount': amount,
        'paid_at': Timestamp.fromDate(paidAt),
        'created_at': Timestamp.now(),
      });

      transaction.update(docRef, {
        'split_items': currentItems,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });

    await _refreshWatchSummarySafely();
  }

  Future<void> updateExpenseSplitItems({
    required String expenseId,
    required List<Map<String, dynamic>> splitItems,
  }) async {
    final cleanedItems = splitItems.map((item) {
      final rawPaidAt = item['paid_at'];
      final rawCreatedAt = item['created_at'];

      return {
        'title': (item['title'] ?? '').toString().trim(),
        'amount': _toDouble(item['amount']),
        'paid_at': rawPaidAt is Timestamp
            ? rawPaidAt
            : rawPaidAt is DateTime
                ? Timestamp.fromDate(rawPaidAt)
                : Timestamp.now(),
        'created_at': rawCreatedAt is Timestamp
            ? rawCreatedAt
            : rawCreatedAt is DateTime
                ? Timestamp.fromDate(rawCreatedAt)
                : Timestamp.now(),
      };
    }).toList();

    await expensesRef.doc(expenseId).update({
      'split_items': cleanedItems,
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _refreshWatchSummarySafely();
  }

  Future<void> deleteExpense({
    required String expenseId,
  }) async {
    await expensesRef.doc(expenseId).delete();

    await _refreshWatchSummarySafely();
  }

  Future<void> deleteRecurringExpenseGroup({
    required String repeatGroupId,
  }) async {
    final snapshot = await expensesRef
        .where('repeat_group_id', isEqualTo: repeatGroupId)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _db.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();

    await _refreshWatchSummarySafely();
  }

  Future<void> addGoal({
    required String title,
    required double targetAmount,
    required double currentAmount,
    required DateTime deadline,
  }) async {
    await goalsRef.add({
      'title': title.trim(),
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'deadline': Timestamp.fromDate(deadline),
      'status': currentAmount >= targetAmount ? 'completed' : 'active',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _refreshWatchSummarySafely();
  }

  Future<void> updateGoal({
    required String goalId,
    required String title,
    required double targetAmount,
    required double currentAmount,
    required DateTime deadline,
  }) async {
    await goalsRef.doc(goalId).update({
      'title': title.trim(),
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'deadline': Timestamp.fromDate(deadline),
      'status': currentAmount >= targetAmount ? 'completed' : 'active',
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _refreshWatchSummarySafely();
  }

  Future<void> addGoalSaving({
    required String goalId,
    required double amount,
  }) async {
    final docRef = goalsRef.doc(goalId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception('Obiettivo non trovato');
      }

      final data = snapshot.data() ?? {};
      final targetAmount = _toDouble(data['target_amount']);
      final currentAmount = _toDouble(data['current_amount']);

      final newAmount = currentAmount + amount;

      transaction.update(docRef, {
        'current_amount': newAmount,
        'status': newAmount >= targetAmount ? 'completed' : 'active',
        'updated_at': FieldValue.serverTimestamp(),
      });
    });

    await _refreshWatchSummarySafely();
  }

  Future<void> deleteGoal({
    required String goalId,
  }) async {
    await goalsRef.doc(goalId).delete();

    await _refreshWatchSummarySafely();
  }

  Future<Map<String, dynamic>> getWatchSummary() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final nextMonthStart = DateTime(now.year, now.month + 1);

    final incomesSnapshot = await incomesRef
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
        )
        .where(
          'date',
          isLessThan: Timestamp.fromDate(nextMonthStart),
        )
        .get();

    final expensesSnapshot = await expensesRef.get();

    final goalsSnapshot =
        await goalsRef.where('status', isEqualTo: 'active').get();

    double monthlyIncome = 0.0;
    double monthlyExpenses = 0.0;
    double monthlyPlannedExpenses = 0.0;

    for (final doc in incomesSnapshot.docs) {
      monthlyIncome += _toDouble(doc.data()['amount']);
    }

    for (final doc in expensesSnapshot.docs) {
      final data = doc.data();
      final type = (data['type'] ?? 'standard').toString();

      if (type == 'planned') {
        final rawMonth = data['month'];

        if (rawMonth is Timestamp) {
          final expenseMonth = rawMonth.toDate();

          if (expenseMonth.year == now.year &&
              expenseMonth.month == now.month) {
            monthlyPlannedExpenses += _toDouble(data['amount']);
          }
        }

        continue;
      }

      final rawSplitItems = data['split_items'];

      if (rawSplitItems is List && rawSplitItems.isNotEmpty) {
        for (final item in rawSplitItems) {
          if (item is! Map) continue;

          final paidAt = item['paid_at'];

          if (paidAt is Timestamp) {
            final paidDate = paidAt.toDate();

            if (paidDate.year == now.year && paidDate.month == now.month) {
              monthlyExpenses += _toDouble(item['amount']);
            }
          }
        }

        continue;
      }

      final expenseDate = _extractExpenseDate(data);

      if (expenseDate != null &&
          expenseDate.year == now.year &&
          expenseDate.month == now.month) {
        monthlyExpenses += _toDouble(data['amount']);
      }
    }

    final activeGoals = goalsSnapshot.docs.length;

    String mainGoalTitle = '';
    double mainGoalTargetAmount = 0.0;
    double mainGoalCurrentAmount = 0.0;
    double mainGoalRemainingAmount = 0.0;
    double mainGoalProgress = 0.0;
    DateTime? mainGoalDeadline;

    final activeGoalDocs = goalsSnapshot.docs.toList();

    activeGoalDocs.sort((a, b) {
      final aDeadline = _toDate(a.data()['deadline']);
      final bDeadline = _toDate(b.data()['deadline']);

      if (aDeadline == null && bDeadline == null) return 0;
      if (aDeadline == null) return 1;
      if (bDeadline == null) return -1;

      return aDeadline.compareTo(bDeadline);
    });

    if (activeGoalDocs.isNotEmpty) {
      final goal = activeGoalDocs.first.data();

      mainGoalTitle = (goal['title'] ?? '').toString();
      mainGoalTargetAmount = _toDouble(goal['target_amount']);
      mainGoalCurrentAmount = _toDouble(goal['current_amount']);
      mainGoalRemainingAmount =
          mainGoalTargetAmount - mainGoalCurrentAmount;

      if (mainGoalRemainingAmount < 0) {
        mainGoalRemainingAmount = 0.0;
      }

      if (mainGoalTargetAmount > 0) {
        mainGoalProgress =
            ((mainGoalCurrentAmount / mainGoalTargetAmount) * 100)
                .clamp(0.0, 100.0)
                .toDouble();
      }

      mainGoalDeadline = _toDate(goal['deadline']);
    }

    final double totalExpenses = monthlyExpenses + monthlyPlannedExpenses;
    final double remainingBudget = monthlyIncome - totalExpenses;

    return {
      'monthly_income': monthlyIncome,
      'monthly_expenses': monthlyExpenses,
      'monthly_planned_expenses': monthlyPlannedExpenses,
      'total_monthly_expenses': totalExpenses,
      'remaining_budget': remainingBudget,
      'active_goals': activeGoals,
      'main_goal_title': mainGoalTitle,
      'main_goal_target_amount': mainGoalTargetAmount,
      'main_goal_current_amount': mainGoalCurrentAmount,
      'main_goal_remaining_amount': mainGoalRemainingAmount,
      'main_goal_progress': mainGoalProgress,
      'main_goal_deadline':
          mainGoalDeadline == null ? null : Timestamp.fromDate(mainGoalDeadline),
      'month': Timestamp.fromDate(monthStart),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  Future<Map<String, dynamic>> getAIPlannerSnapshot() async {
    final now = DateTime.now();

    final currentMonthStart = DateTime(now.year, now.month);
    final nextMonthStart = DateTime(now.year, now.month + 1);
    final previousMonthStart = DateTime(now.year, now.month - 1);
    final currentDay = now.day;
    final daysInCurrentMonth = _daysInMonth(now.year, now.month);
    final remainingDaysInMonth = daysInCurrentMonth - currentDay;

    final currentIncomesSnapshot = await incomesRef
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(currentMonthStart),
        )
        .where(
          'date',
          isLessThan: Timestamp.fromDate(nextMonthStart),
        )
        .get();

    final previousIncomesSnapshot = await incomesRef
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(previousMonthStart),
        )
        .where(
          'date',
          isLessThan: Timestamp.fromDate(currentMonthStart),
        )
        .get();

    final expensesSnapshot = await expensesRef.get();
    final goalsSnapshot = await goalsRef.get();

    double monthlyIncome = 0.0;
    double previousMonthlyIncome = 0.0;

    for (final doc in currentIncomesSnapshot.docs) {
      monthlyIncome += _toDouble(doc.data()['amount']);
    }

    for (final doc in previousIncomesSnapshot.docs) {
      previousMonthlyIncome += _toDouble(doc.data()['amount']);
    }

    double paidExpenses = 0.0;
    double unpaidExpenses = 0.0;
    double plannedExpenses = 0.0;

    double previousPaidExpenses = 0.0;
    double previousUnpaidExpenses = 0.0;
    double previousPlannedExpenses = 0.0;

    final Map<String, double> categoryTotals = {};
    final List<Map<String, dynamic>> upcomingExpenses = [];
    final List<Map<String, dynamic>> unpaidExpensesList = [];

    for (final doc in expensesSnapshot.docs) {
      final data = doc.data();

      final title = (data['title'] ?? '').toString();
      final category = (data['category'] ?? 'Altro').toString().trim().isEmpty
          ? 'Altro'
          : (data['category'] ?? 'Altro').toString().trim();

      final amount = _toDouble(data['amount']);
      final type = (data['type'] ?? 'standard').toString();

      if (type == 'planned') {
        final rawMonth = data['month'];
        final plannedMonth = rawMonth is Timestamp ? rawMonth.toDate() : null;

        if (plannedMonth != null &&
            plannedMonth.year == now.year &&
            plannedMonth.month == now.month) {
          plannedExpenses += amount;
          categoryTotals[category] = (categoryTotals[category] ?? 0.0) + amount;

          upcomingExpenses.add({
            'id': doc.id,
            'title': title,
            'amount': amount,
            'category': category,
            'type': 'planned',
            'date': Timestamp.fromDate(DateTime(now.year, now.month)),
          });
        }

        if (plannedMonth != null &&
            plannedMonth.year == previousMonthStart.year &&
            plannedMonth.month == previousMonthStart.month) {
          previousPlannedExpenses += amount;
        }

        continue;
      }

      final dueDate = _extractExpenseDate(data);
      final isPaid = data['is_paid'] == true;
      final rawSplitItems = data['split_items'];

      if (rawSplitItems is List && rawSplitItems.isNotEmpty) {
        double paidThisMonth = 0.0;
        double paidPreviousMonth = 0.0;
        double totalPaidAllTime = 0.0;

        for (final item in rawSplitItems) {
          if (item is! Map) continue;

          final splitAmount = _toDouble(item['amount']);
          final paidAt = item['paid_at'];

          totalPaidAllTime += splitAmount;

          if (paidAt is Timestamp) {
            final paidDate = paidAt.toDate();

            if (paidDate.year == now.year && paidDate.month == now.month) {
              paidThisMonth += splitAmount;
            }

            if (paidDate.year == previousMonthStart.year &&
                paidDate.month == previousMonthStart.month) {
              paidPreviousMonth += splitAmount;
            }
          }
        }

        if (paidThisMonth > 0) {
          paidExpenses += paidThisMonth;
          categoryTotals[category] =
              (categoryTotals[category] ?? 0.0) + paidThisMonth;
        }

        if (paidPreviousMonth > 0) {
          previousPaidExpenses += paidPreviousMonth;
        }

        double remainingAmount = amount - totalPaidAllTime;

        if (remainingAmount < 0) {
          remainingAmount = 0.0;
        }

        if (remainingAmount > 0 &&
            dueDate != null &&
            dueDate.year == now.year &&
            dueDate.month == now.month) {
          unpaidExpenses += remainingAmount;
          categoryTotals[category] =
              (categoryTotals[category] ?? 0.0) + remainingAmount;

          unpaidExpensesList.add({
            'id': doc.id,
            'title': title,
            'amount': remainingAmount,
            'category': category,
            'due_date': Timestamp.fromDate(dueDate),
          });
        }

        continue;
      }

      if (dueDate == null) continue;

      if (dueDate.year == now.year && dueDate.month == now.month) {
        if (isPaid) {
          paidExpenses += amount;
        } else {
          unpaidExpenses += amount;

          unpaidExpensesList.add({
            'id': doc.id,
            'title': title,
            'amount': amount,
            'category': category,
            'due_date': Timestamp.fromDate(dueDate),
          });
        }

        categoryTotals[category] = (categoryTotals[category] ?? 0.0) + amount;

        if (!isPaid &&
            !dueDate.isBefore(DateTime(now.year, now.month, now.day))) {
          upcomingExpenses.add({
            'id': doc.id,
            'title': title,
            'amount': amount,
            'category': category,
            'type': 'standard',
            'date': Timestamp.fromDate(dueDate),
          });
        }
      }

      if (dueDate.year == previousMonthStart.year &&
          dueDate.month == previousMonthStart.month) {
        if (isPaid) {
          previousPaidExpenses += amount;
        } else {
          previousUnpaidExpenses += amount;
        }
      }
    }

    final double totalExpenses =
        paidExpenses + unpaidExpenses + plannedExpenses;

    final double previousTotalExpenses = previousPaidExpenses +
        previousUnpaidExpenses +
        previousPlannedExpenses;

    final double availableBudget = monthlyIncome - totalExpenses;

    final double safetyBuffer = monthlyIncome > 0 ? monthlyIncome * 0.10 : 0.0;
    final double spendableBudget = availableBudget - safetyBuffer;

    final double dailyAvailable = remainingDaysInMonth > 0
        ? availableBudget / remainingDaysInMonth
        : availableBudget;

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final String topCategoryName =
        sortedCategories.isNotEmpty ? sortedCategories.first.key : '';

    final double topCategoryAmount =
        sortedCategories.isNotEmpty ? sortedCategories.first.value : 0.0;

    final List<Map<String, dynamic>> categories = sortedCategories.map((entry) {
      final double percentage = totalExpenses > 0
          ? ((entry.value / totalExpenses) * 100).clamp(0.0, 100.0).toDouble()
          : 0.0;

      return {
        'name': entry.key,
        'amount': entry.value,
        'percentage': percentage,
      };
    }).toList();

    final List<Map<String, dynamic>> activeGoals = [];

    for (final doc in goalsSnapshot.docs) {
      final data = doc.data();

      final status = (data['status'] ?? 'active').toString();

      if (status != 'active') continue;

      final title = (data['title'] ?? '').toString();
      final targetAmount = _toDouble(data['target_amount']);
      final currentAmount = _toDouble(data['current_amount']);

      double remainingAmount = targetAmount - currentAmount;

      if (remainingAmount < 0) {
        remainingAmount = 0.0;
      }

      final deadline = _toDate(data['deadline']);

      final double progress = targetAmount > 0
          ? ((currentAmount / targetAmount) * 100).clamp(0.0, 100.0).toDouble()
          : 0.0;

      int? daysRemaining;

      if (deadline != null) {
        daysRemaining =
            deadline.difference(DateTime(now.year, now.month, now.day)).inDays;
      }

      activeGoals.add({
        'id': doc.id,
        'title': title,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'remaining_amount': remainingAmount,
        'progress': progress,
        'deadline': deadline == null ? null : Timestamp.fromDate(deadline),
        'days_remaining': daysRemaining,
      });
    }

    activeGoals.sort((a, b) {
      final aDays = a['days_remaining'];
      final bDays = b['days_remaining'];

      if (aDays is! int && bDays is! int) return 0;
      if (aDays is! int) return 1;
      if (bDays is! int) return -1;

      return aDays.compareTo(bDays);
    });

    final Map<String, dynamic>? mainGoal =
        activeGoals.isNotEmpty ? activeGoals.first : null;

    final suggestions = _buildAIPlannerSuggestions(
      monthlyIncome: monthlyIncome,
      paidExpenses: paidExpenses,
      unpaidExpenses: unpaidExpenses,
      plannedExpenses: plannedExpenses,
      availableBudget: availableBudget,
      safetyBuffer: safetyBuffer,
      spendableBudget: spendableBudget,
      previousTotalExpenses: previousTotalExpenses,
      currentTotalExpenses: totalExpenses,
      topCategoryName: topCategoryName,
      topCategoryAmount: topCategoryAmount,
      mainGoal: mainGoal,
    );

    final financialHealthScore = _calculateFinancialHealthScore(
      monthlyIncome: monthlyIncome,
      totalExpenses: totalExpenses,
      unpaidExpenses: unpaidExpenses,
      availableBudget: availableBudget,
      activeGoals: activeGoals.length,
    );

    final mood = _financialMood(
      score: financialHealthScore,
      availableBudget: availableBudget,
      monthlyIncome: monthlyIncome,
    );

    return {
      'month': Timestamp.fromDate(currentMonthStart),
      'monthly_income': monthlyIncome,
      'previous_monthly_income': previousMonthlyIncome,
      'paid_expenses': paidExpenses,
      'unpaid_expenses': unpaidExpenses,
      'planned_expenses': plannedExpenses,
      'total_expenses': totalExpenses,
      'previous_paid_expenses': previousPaidExpenses,
      'previous_unpaid_expenses': previousUnpaidExpenses,
      'previous_planned_expenses': previousPlannedExpenses,
      'previous_total_expenses': previousTotalExpenses,
      'available_budget': availableBudget,
      'safety_buffer': safetyBuffer,
      'spendable_budget': spendableBudget < 0 ? 0.0 : spendableBudget,
      'daily_available': dailyAvailable,
      'days_in_month': daysInCurrentMonth,
      'current_day': currentDay,
      'remaining_days_in_month': remainingDaysInMonth,
      'top_category_name': topCategoryName,
      'top_category_amount': topCategoryAmount,
      'categories': categories,
      'active_goals': activeGoals,
      'main_goal': mainGoal,
      'upcoming_expenses': upcomingExpenses,
      'unpaid_expenses_list': unpaidExpensesList,
      'suggestions': suggestions,
      'financial_health_score': financialHealthScore,
      'financial_mood': mood,
      'updated_at': Timestamp.now(),
    };
  }

  Future<String> askAIPlannerLocally({
    required String question,
  }) async {
    final cleanedQuestion = question.trim();

    if (cleanedQuestion.isEmpty) {
      return 'Scrivimi una domanda e ti aiuto a capire meglio la tua situazione finanziaria.';
    }

    final snapshot = await getAIPlannerSnapshot();

    return _buildLocalAIPlannerAnswer(
      question: cleanedQuestion,
      snapshot: snapshot,
    );
  }

  Future<void> updateWatchSummary() async {
    final summary = await getWatchSummary();

    await watchSummaryRef.doc('current').set(
      summary,
      SetOptions(merge: true),
    );

    await _watchSyncService.sendSummaryToWatch(
      _cleanSummaryForWatch(summary),
    );
  }

  Future<void> _refreshWatchSummarySafely() async {
    try {
      await updateWatchSummary();
    } catch (_) {
      // Evita che un errore nel riepilogo Watch blocchi
      // il salvataggio principale di entrate, spese o obiettivi.
    }
  }

  List<String> _buildAIPlannerSuggestions({
    required double monthlyIncome,
    required double paidExpenses,
    required double unpaidExpenses,
    required double plannedExpenses,
    required double availableBudget,
    required double safetyBuffer,
    required double spendableBudget,
    required double previousTotalExpenses,
    required double currentTotalExpenses,
    required String topCategoryName,
    required double topCategoryAmount,
    required Map<String, dynamic>? mainGoal,
  }) {
    final suggestions = <String>[];

    if (monthlyIncome <= 0) {
      suggestions.add(
        'Non hai ancora registrato entrate per questo mese. Inseriscile per ricevere consigli più precisi.',
      );

      return suggestions;
    }

    if (availableBudget < 0) {
      suggestions.add(
        'Questo mese le uscite superano le entrate. Prima di fare nuove spese, prova a ridurre o rimandare quelle non urgenti.',
      );
    } else if (availableBudget <= safetyBuffer) {
      suggestions.add(
        'Hai ancora budget disponibile, ma sei vicino al margine di sicurezza. Ti consiglio di evitare spese extra non necessarie.',
      );
    } else {
      suggestions.add(
        'La situazione del mese è sotto controllo. Puoi gestire le prossime spese mantenendo comunque un margine di sicurezza.',
      );
    }

    if (unpaidExpenses > 0) {
      suggestions.add(
        'Hai ancora spese da pagare. Prima di destinare soldi agli obiettivi, controlla quelle in scadenza.',
      );
    }

    if (plannedExpenses > 0) {
      suggestions.add(
        'Hai spese pianificate questo mese. Considerale come soldi già impegnati, anche se non sono ancora uscite reali.',
      );
    }

    if (previousTotalExpenses > 0 &&
        currentTotalExpenses > previousTotalExpenses) {
      final difference = currentTotalExpenses - previousTotalExpenses;

      suggestions.add(
        'Questo mese stai spendendo più del mese scorso di circa ${_formatMoneyText(difference)}. Tieni d’occhio le categorie più pesanti.',
      );
    } else if (previousTotalExpenses > 0 &&
        currentTotalExpenses < previousTotalExpenses) {
      final difference = previousTotalExpenses - currentTotalExpenses;

      suggestions.add(
        'Rispetto al mese scorso stai spendendo circa ${_formatMoneyText(difference)} in meno. Ottimo segnale.',
      );
    }

    if (topCategoryName.isNotEmpty && topCategoryAmount > 0) {
      suggestions.add(
        'La categoria che pesa di più questo mese è "$topCategoryName" con ${_formatMoneyText(topCategoryAmount)}.',
      );
    }

    if (mainGoal != null) {
      final goalTitle = (mainGoal['title'] ?? '').toString();
      final remainingAmount = _toDouble(mainGoal['remaining_amount']);
      final daysRemaining = mainGoal['days_remaining'];

      if (goalTitle.isNotEmpty && remainingAmount > 0) {
        if (spendableBudget > 0) {
          final suggestedSaving = _suggestedGoalSaving(
            spendableBudget: spendableBudget,
            remainingGoalAmount: remainingAmount,
          );

          suggestions.add(
            'Per l’obiettivo "$goalTitle", potresti mettere da parte circa ${_formatMoneyText(suggestedSaving)} questo mese senza toccare il margine di sicurezza.',
          );
        } else {
          suggestions.add(
            'Hai un obiettivo attivo, "$goalTitle", ma per ora non ti consiglio di aggiungere soldi finché non aumenta il margine disponibile.',
          );
        }

        if (daysRemaining is int && daysRemaining >= 0 && daysRemaining <= 30) {
          suggestions.add(
            'L’obiettivo "$goalTitle" è vicino alla scadenza. Mancano circa $daysRemaining giorni.',
          );
        }
      }
    }

    return suggestions;
  }

  int _calculateFinancialHealthScore({
    required double monthlyIncome,
    required double totalExpenses,
    required double unpaidExpenses,
    required double availableBudget,
    required int activeGoals,
  }) {
    if (monthlyIncome <= 0) return 35;

    int score = 70;

    final double expenseRatio = totalExpenses / monthlyIncome;

    if (expenseRatio <= 0.50) {
      score += 15;
    } else if (expenseRatio <= 0.75) {
      score += 5;
    } else if (expenseRatio <= 0.90) {
      score -= 8;
    } else {
      score -= 18;
    }

    if (availableBudget < 0) {
      score -= 25;
    } else if (availableBudget >= monthlyIncome * 0.20) {
      score += 10;
    }

    if (unpaidExpenses > monthlyIncome * 0.35) {
      score -= 10;
    }

    if (activeGoals > 0 && availableBudget > 0) {
      score += 5;
    }

    return score.clamp(0, 100).toInt();
  }

  String _financialMood({
    required int score,
    required double availableBudget,
    required double monthlyIncome,
  }) {
    if (monthlyIncome <= 0) {
      return 'Da configurare';
    }

    if (availableBudget < 0) {
      return 'Attenzione';
    }

    if (score >= 80) {
      return 'Ottima';
    }

    if (score >= 65) {
      return 'Stabile';
    }

    if (score >= 45) {
      return 'Da controllare';
    }

    return 'Critica';
  }

  String _buildLocalAIPlannerAnswer({
    required String question,
    required Map<String, dynamic> snapshot,
  }) {
    final lowerQuestion = question.toLowerCase();

    final monthlyIncome = _toDouble(snapshot['monthly_income']);
    final paidExpenses = _toDouble(snapshot['paid_expenses']);
    final unpaidExpenses = _toDouble(snapshot['unpaid_expenses']);
    final plannedExpenses = _toDouble(snapshot['planned_expenses']);
    final totalExpenses = _toDouble(snapshot['total_expenses']);
    final previousTotalExpenses = _toDouble(snapshot['previous_total_expenses']);
    final availableBudget = _toDouble(snapshot['available_budget']);
    final safetyBuffer = _toDouble(snapshot['safety_buffer']);
    final spendableBudget = _toDouble(snapshot['spendable_budget']);
    final dailyAvailable = _toDouble(snapshot['daily_available']);
    final topCategoryName = (snapshot['top_category_name'] ?? '').toString();
    final topCategoryAmount = _toDouble(snapshot['top_category_amount']);
    final mood = (snapshot['financial_mood'] ?? '').toString();
    final score = snapshot['financial_health_score'];
    final mainGoal = snapshot['main_goal'];

    final askedAboutAffordability = lowerQuestion.contains('posso') ||
        lowerQuestion.contains('permettermi') ||
        lowerQuestion.contains('comprare') ||
        lowerQuestion.contains('spendere') ||
        lowerQuestion.contains('acquistare');

    final askedAboutSaving = lowerQuestion.contains('risparmiare') ||
        lowerQuestion.contains('mettere da parte') ||
        lowerQuestion.contains('accantonare') ||
        lowerQuestion.contains('obiettivo') ||
        lowerQuestion.contains('obiettivi');

    final askedAboutSituation = lowerQuestion.contains('come sto') ||
        lowerQuestion.contains('situazione') ||
        lowerQuestion.contains('andamento') ||
        lowerQuestion.contains('budget') ||
        lowerQuestion.contains('mese');

    final askedAboutExpenses = lowerQuestion.contains('spese') ||
        lowerQuestion.contains('spendendo') ||
        lowerQuestion.contains('categoria') ||
        lowerQuestion.contains('uscite');

    final amountInQuestion = _extractFirstAmountFromText(lowerQuestion);

    if (monthlyIncome <= 0) {
      return 'Per risponderti bene ho bisogno che tu inserisca almeno un’entrata per questo mese. Al momento non vedo entrate registrate, quindi non posso calcolare un budget realistico.';
    }

    if (askedAboutAffordability) {
      if (amountInQuestion != null && amountInQuestion > 0) {
        final double remainingAfterPurchase =
            availableBudget - amountInQuestion;

        final double remainingAfterSafety =
            remainingAfterPurchase - safetyBuffer;

        if (remainingAfterPurchase < 0) {
          return 'Guardando i tuoi dati, non te lo consiglio. Hai ${_formatMoneyText(availableBudget)} disponibili, ma questa spesa sarebbe di ${_formatMoneyText(amountInQuestion)}. Andresti sotto di circa ${_formatMoneyText(remainingAfterPurchase.abs())}. Prima conviene ridurre qualche spesa o aspettare una nuova entrata.';
        }

        if (remainingAfterSafety < 0) {
          return 'Tecnicamente puoi farlo, perché hai ${_formatMoneyText(availableBudget)} disponibili. Però dopo una spesa da ${_formatMoneyText(amountInQuestion)} ti resterebbero ${_formatMoneyText(remainingAfterPurchase)}, andando sotto il margine di sicurezza consigliato di ${_formatMoneyText(safetyBuffer)}. Io ti direi: fallo solo se è davvero necessario.';
        }

        return 'Sì, puoi permettertelo. Hai ${_formatMoneyText(availableBudget)} disponibili e dopo una spesa da ${_formatMoneyText(amountInQuestion)} ti resterebbero circa ${_formatMoneyText(remainingAfterPurchase)}. Resti anche sopra il margine di sicurezza consigliato.';
      }

      if (spendableBudget <= 0) {
        return 'In questo momento non ti consiglio nuove spese extra. Hai ${_formatMoneyText(availableBudget)} disponibili, ma il margine realmente spendibile è basso perché sarebbe meglio tenere circa ${_formatMoneyText(safetyBuffer)} come sicurezza.';
      }

      return 'In questo momento puoi spendere circa ${_formatMoneyText(spendableBudget)} senza intaccare il margine di sicurezza. Oltre quella cifra, meglio valutare con attenzione.';
    }

    if (askedAboutSaving) {
      if (spendableBudget <= 0) {
        return 'Per ora non ti consiglio di mettere soldi da parte: hai ${_formatMoneyText(availableBudget)} disponibili, ma il margine di sicurezza consigliato è circa ${_formatMoneyText(safetyBuffer)}. Prima sistemerei le spese del mese.';
      }

      if (mainGoal is Map<String, dynamic>) {
        final goalTitle = (mainGoal['title'] ?? '').toString();
        final remainingAmount = _toDouble(mainGoal['remaining_amount']);
        final suggestedSaving = _suggestedGoalSaving(
          spendableBudget: spendableBudget,
          remainingGoalAmount: remainingAmount,
        );

        if (goalTitle.isNotEmpty) {
          return 'Secondo me questo mese puoi mettere da parte circa ${_formatMoneyText(suggestedSaving)} per "$goalTitle". Hai ${_formatMoneyText(availableBudget)} disponibili, ma terrei comunque ${_formatMoneyText(safetyBuffer)} come margine di sicurezza.';
        }
      }

      final double suggestedSaving = spendableBudget * 0.50;

      return 'Questo mese puoi provare a mettere da parte circa ${_formatMoneyText(suggestedSaving)}. È una cifra prudente perché lascia comunque un margine per eventuali imprevisti.';
    }

    if (askedAboutExpenses) {
      if (topCategoryName.isEmpty || topCategoryAmount <= 0) {
        return 'Al momento non vedo una categoria dominante nelle spese di questo mese. Appena aggiungi più movimenti, potrò dirti dove stai spendendo di più.';
      }

      final comparisonText = previousTotalExpenses > 0
          ? currentVsPreviousSentence(
              currentTotalExpenses: totalExpenses,
              previousTotalExpenses: previousTotalExpenses,
            )
          : '';

      return 'La categoria che pesa di più questo mese è "$topCategoryName", con ${_formatMoneyText(topCategoryAmount)}. Le tue spese totali del mese sono ${_formatMoneyText(totalExpenses)}. $comparisonText';
    }

    if (askedAboutSituation) {
      return 'La tua situazione attuale è "$mood". Hai entrate per ${_formatMoneyText(monthlyIncome)}, spese già pagate per ${_formatMoneyText(paidExpenses)}, spese ancora da pagare per ${_formatMoneyText(unpaidExpenses)} e spese pianificate per ${_formatMoneyText(plannedExpenses)}. Il budget disponibile stimato è ${_formatMoneyText(availableBudget)}. Ti consiglio di non scendere sotto ${_formatMoneyText(safetyBuffer)} di margine.';
    }

    return 'Guardando la tua situazione, hai ${_formatMoneyText(monthlyIncome)} di entrate e ${_formatMoneyText(totalExpenses)} di uscite totali previste questo mese. Il budget disponibile stimato è ${_formatMoneyText(availableBudget)}. Il tuo stato è "$mood"${score is int ? ' con un punteggio di $score/100' : ''}. Puoi usare circa ${_formatMoneyText(dailyAvailable)} al giorno per il resto del mese, ma ti consiglio di mantenere un margine di sicurezza di almeno ${_formatMoneyText(safetyBuffer)}.';
  }

  String currentVsPreviousSentence({
    required double currentTotalExpenses,
    required double previousTotalExpenses,
  }) {
    if (previousTotalExpenses <= 0) {
      return '';
    }

    if (currentTotalExpenses > previousTotalExpenses) {
      final double difference = currentTotalExpenses - previousTotalExpenses;

      return 'Rispetto al mese scorso stai spendendo circa ${_formatMoneyText(difference)} in più.';
    }

    if (currentTotalExpenses < previousTotalExpenses) {
      final double difference = previousTotalExpenses - currentTotalExpenses;

      return 'Rispetto al mese scorso stai spendendo circa ${_formatMoneyText(difference)} in meno.';
    }

    return 'Stai spendendo più o meno come il mese scorso.';
  }

  double _suggestedGoalSaving({
    required double spendableBudget,
    required double remainingGoalAmount,
  }) {
    if (spendableBudget <= 0) return 0.0;

    if (remainingGoalAmount <= 0) {
      return spendableBudget * 0.25;
    }

    final double suggested = spendableBudget * 0.45;

    if (suggested > remainingGoalAmount) {
      return remainingGoalAmount;
    }

    return suggested;
  }

  double? _extractFirstAmountFromText(String text) {
    final regex = RegExp(r'(\d+[,.]?\d*)');
    final match = regex.firstMatch(text);

    if (match == null) return null;

    final rawValue = match.group(1);

    if (rawValue == null) return null;

    return double.tryParse(rawValue.replaceAll(',', '.'));
  }

  String _formatMoneyText(double value) {
    final double normalized = value.abs() < 0.005 ? 0.0 : value;
    final fixed = normalized.toStringAsFixed(2).replaceAll('.', ',');

    return '$fixed €';
  }

  Map<String, dynamic> _cleanSummaryForWatch(Map<String, dynamic> summary) {
    final cleaned = <String, dynamic>{};

    for (final entry in summary.entries) {
      final value = entry.value;

      if (value is Timestamp) {
        cleaned[entry.key] = value.toDate().toIso8601String();
      } else if (value is FieldValue) {
        cleaned[entry.key] = DateTime.now().toIso8601String();
      } else if (value == null) {
        cleaned[entry.key] = '';
      } else {
        cleaned[entry.key] = value;
      }
    }

    return cleaned;
  }

  DateTime? _extractExpenseDate(Map<String, dynamic> data) {
    final dueDate = data['due_date'];
    final createdAt = data['created_at'];
    final month = data['month'];

    if (dueDate is Timestamp) return dueDate.toDate();
    if (createdAt is Timestamp) return createdAt.toDate();
    if (month is Timestamp) return month.toDate();

    return null;
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  DateTime _safeMonthlyDate({
    required int year,
    required int month,
    required int preferredDay,
  }) {
    final lastDay = _daysInMonth(year, month);
    final day = preferredDay > lastDay ? lastDay : preferredDay;

    return DateTime(year, month, day);
  }

  List<DateTime> _monthlyDueDates({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final dates = <DateTime>[];
    final preferredDay = startDate.day;

    var cursor = DateTime(startDate.year, startDate.month);

    while (!cursor.isAfter(DateTime(endDate.year, endDate.month))) {
      final dueDate = _safeMonthlyDate(
        year: cursor.year,
        month: cursor.month,
        preferredDay: preferredDay,
      );

      if (!dueDate.isBefore(startDate) && !dueDate.isAfter(endDate)) {
        dates.add(dueDate);
      }

      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    return dates;
  }

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return null;
  }

  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0.0;
  }
}