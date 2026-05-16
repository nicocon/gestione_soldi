import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';
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

  DocumentReference<Map<String, dynamic>> get userProfileRef {
    return _db.collection('users').doc(_uid);
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

  CollectionReference<Map<String, dynamic>> get bankAccountsRef {
    return _db.collection('users').doc(_uid).collection('bank_accounts');
  }

  CollectionReference<Map<String, dynamic>> get bankTransfersRef {
    return _db.collection('users').doc(_uid).collection('bank_transfers');
  }

  Future<Map<String, dynamic>> getAiPersonalProfile() async {
    final snapshot = await userProfileRef.get();
    final data = snapshot.data() ?? {};

    final rawAiProfile = data['ai_profile'];
    final rawAiLearningProfile = data['ai_learning_profile'];

    final aiProfile = rawAiProfile is Map
        ? Map<String, dynamic>.from(rawAiProfile)
        : <String, dynamic>{};

    final aiLearningProfile = rawAiLearningProfile is Map
        ? Map<String, dynamic>.from(rawAiLearningProfile)
        : <String, dynamic>{};

    return {
      'ai_profile': aiProfile,
      'ai_learning_profile': aiLearningProfile,
    };
  }

  Future<void> updateAiLearningProfile({
    String? preferredGoalFocus,
    String? spendingPattern,
    String? budgetSensitivity,
    String? responsePreference,
    String? lastFinancialMood,
    String? strongestGoalCategory,
    bool? oftenAsksBeforeSpending,
    bool? oftenAsksAboutSaving,
    bool? oftenAsksAboutGoals,
  }) async {
    final updates = <String, dynamic>{
      'ai_learning_profile.updated_at': FieldValue.serverTimestamp(),
    };

    if (preferredGoalFocus != null) {
      updates['ai_learning_profile.preferred_goal_focus'] = preferredGoalFocus;
    }

    if (spendingPattern != null) {
      updates['ai_learning_profile.spending_pattern'] = spendingPattern;
    }

    if (budgetSensitivity != null) {
      updates['ai_learning_profile.budget_sensitivity'] = budgetSensitivity;
    }

    if (responsePreference != null) {
      updates['ai_learning_profile.response_preference'] = responsePreference;
    }

    if (lastFinancialMood != null) {
      updates['ai_learning_profile.last_financial_mood'] = lastFinancialMood;
    }

    if (strongestGoalCategory != null) {
      updates['ai_learning_profile.strongest_goal_category'] =
          strongestGoalCategory;
    }

    if (oftenAsksBeforeSpending != null) {
      updates['ai_learning_profile.often_asks_before_spending'] =
          oftenAsksBeforeSpending;
    }

    if (oftenAsksAboutSaving != null) {
      updates['ai_learning_profile.often_asks_about_saving'] =
          oftenAsksAboutSaving;
    }

    if (oftenAsksAboutGoals != null) {
      updates['ai_learning_profile.often_asks_about_goals'] =
          oftenAsksAboutGoals;
    }

    await userProfileRef.set(
      updates,
      SetOptions(merge: true),
    );
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

  Stream<QuerySnapshot<Map<String, dynamic>>> bankAccountsStream() {
    return bankAccountsRef.orderBy('created_at', descending: false).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> bankTransfersStream() {
    return bankTransfersRef.orderBy('date', descending: true).snapshots();
  }

  int _stableNotificationBaseId(String value) {
    const int fnvPrime = 16777619;
    int hash = 2166136261;

    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0x7fffffff;
    }

    return 100000 + (hash % 800000000);
  }

  List<int> _expenseReminderIds(String expenseId) {
    final baseId = _stableNotificationBaseId('expense_$expenseId');

    return [
      baseId,
      baseId + 1,
      baseId + 2,
    ];
  }

  DateTime _dayAtNine(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      9,
    );
  }

  Future<void> _cancelExpenseRemindersSafely(String expenseId) async {
    try {
      for (final id in _expenseReminderIds(expenseId)) {
        await NotificationService.instance.cancelNotification(id);
      }
    } catch (_) {
      // Le notifiche non devono mai bloccare il salvataggio dei dati.
    }
  }

  Future<void> _syncExpenseReminderSafely({
    required String expenseId,
    required String title,
    required double amount,
    required DateTime? dueDate,
    required bool isPaid,
    required bool reminderEnabled,
    required bool isPlanned,
  }) async {
    try {
      await _cancelExpenseRemindersSafely(expenseId);

      if (isPlanned) return;
      if (isPaid) return;
      if (!reminderEnabled) return;
      if (dueDate == null) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

      final reminderIds = _expenseReminderIds(expenseId);

      final reminderDays = [
        dueDay.subtract(const Duration(days: 2)),
        dueDay.subtract(const Duration(days: 1)),
        dueDay,
      ];

      for (int i = 0; i < reminderDays.length; i++) {
        final reminderDay = reminderDays[i];

        DateTime scheduledDate = _dayAtNine(reminderDay);

        if (reminderDay == today && !scheduledDate.isAfter(now)) {
          scheduledDate = now.add(const Duration(minutes: 1));
        }

        if (!scheduledDate.isAfter(now)) continue;

        await NotificationService.instance.scheduleExpenseReminder(
          id: reminderIds[i],
          title: title,
          amount: amount,
          scheduledDate: scheduledDate,
        );
      }
    } catch (_) {
      // Le notifiche non devono mai bloccare il salvataggio dei dati.
    }
  }

  Future<void> _notifyAiInsightSafely({
    required String code,
    required String title,
    required String message,
    required int priority,
  }) async {
    if (priority < 80) return;

    try {
      final today = DateTime.now();
      final dayKey =
          '${today.year}_${today.month.toString().padLeft(2, '0')}_${today.day.toString().padLeft(2, '0')}';

      final id = _stableNotificationBaseId('ai_${dayKey}_$code');

      await NotificationService.instance.showAiInsightNotification(
        id: id,
        title: title,
        body: message,
      );
    } catch (_) {
      // L'AI non deve mai bloccare il flusso principale dell'app.
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Utente non autenticato');
    }

    final snapshot = await userProfileRef.get();
    final data = snapshot.data() ?? {};

    final displayName = user.displayName?.trim() ?? '';
    final displayNameParts = displayName
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .toList();

    String name = (data['name'] ?? '').toString().trim();
    String surname = (data['surname'] ?? '').toString().trim();

    if (name.isEmpty && displayNameParts.isNotEmpty) {
      name = displayNameParts.first;
    }

    if (surname.isEmpty && displayNameParts.length >= 2) {
      surname = displayNameParts.sublist(1).join(' ');
    }

    DateTime? birthDate;

    final rawBirthDate = data['birth_date'];

    if (rawBirthDate is Timestamp) {
      birthDate = rawBirthDate.toDate();
    } else if (rawBirthDate is DateTime) {
      birthDate = rawBirthDate;
    } else if (rawBirthDate is String && rawBirthDate.trim().isNotEmpty) {
      birthDate = DateTime.tryParse(rawBirthDate);
    }

    final fullName = '$name $surname'.trim();

    return {
      'uid': user.uid,
      'name': name,
      'surname': surname,
      'display_name': fullName.isNotEmpty ? fullName : displayName,
      'email': user.email ?? '',
      'country': (data['country'] ?? '').toString().trim(),
      'phone': (data['phone'] ?? '').toString().trim(),
      'birth_date': birthDate,
    };
  }

  Future<void> updateUserProfile({
    required String name,
    required String surname,
    DateTime? birthDate,
    String? country,
    String? phone,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Utente non autenticato');
    }

    final cleanedName = name.trim();
    final cleanedSurname = surname.trim();
    final cleanedCountry = country?.trim() ?? '';
    final cleanedPhone = phone?.trim() ?? '';

    if (cleanedName.isEmpty) {
      throw Exception('Il nome è obbligatorio');
    }

    final displayName = '$cleanedName $cleanedSurname'.trim();

    await user.updateDisplayName(displayName);
    await user.reload();

    await userProfileRef.set(
      {
        'name': cleanedName,
        'surname': cleanedSurname,
        'display_name': displayName,
        'email': user.email,
        'country': cleanedCountry,
        'phone': cleanedPhone,
        'birth_date': birthDate == null ? null : Timestamp.fromDate(birthDate),
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> addBankAccount({
    required String name,
    required double balance,
  }) async {
    await bankAccountsRef.add({
      'name': name.trim(),
      'balance': balance,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _refreshWatchSummarySafely();
  }

  Future<void> updateBankAccount({
    required String bankAccountId,
    required String name,
    required double balance,
  }) async {
    await bankAccountsRef.doc(bankAccountId).update({
      'name': name.trim(),
      'balance': balance,
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _refreshWatchSummarySafely();
  }

  Future<void> deleteBankAccount({
    required String bankAccountId,
  }) async {
    await bankAccountsRef.doc(bankAccountId).delete();

    await _refreshWatchSummarySafely();
  }

  Future<void> transferMoneyBetweenBankAccounts({
    required String fromBankAccountId,
    required String toBankAccountId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    if (fromBankAccountId.trim().isEmpty) {
      throw Exception('Seleziona il conto di partenza');
    }

    if (toBankAccountId.trim().isEmpty) {
      throw Exception('Seleziona il conto di destinazione');
    }

    if (fromBankAccountId == toBankAccountId) {
      throw Exception(
        'Il conto di partenza e quello di destinazione devono essere diversi',
      );
    }

    if (amount <= 0) {
      throw Exception('L’importo deve essere maggiore di zero');
    }

    final fromRef = bankAccountsRef.doc(fromBankAccountId);
    final toRef = bankAccountsRef.doc(toBankAccountId);
    final transferRef = bankTransfersRef.doc();

    await _db.runTransaction((transaction) async {
      final fromSnapshot = await transaction.get(fromRef);
      final toSnapshot = await transaction.get(toRef);

      if (!fromSnapshot.exists) {
        throw Exception('Conto di partenza non trovato');
      }

      if (!toSnapshot.exists) {
        throw Exception('Conto di destinazione non trovato');
      }

      final fromData = fromSnapshot.data() ?? {};
      final toData = toSnapshot.data() ?? {};

      final fromBalance = _toDouble(fromData['balance']);
      final toBalance = _toDouble(toData['balance']);

      if (amount > fromBalance) {
        throw Exception('Saldo insufficiente sul conto di partenza');
      }

      final fromName = (fromData['name'] ?? 'Conto partenza').toString();
      final toName = (toData['name'] ?? 'Conto destinazione').toString();

      transaction.update(fromRef, {
        'balance': fromBalance - amount,
        'updated_at': FieldValue.serverTimestamp(),
      });

      transaction.update(toRef, {
        'balance': toBalance + amount,
        'updated_at': FieldValue.serverTimestamp(),
      });

      transaction.set(transferRef, {
        'fromBankAccountId': fromBankAccountId,
        'fromBankAccountName': fromName,
        'toBankAccountId': toBankAccountId,
        'toBankAccountName': toName,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'note': note == null || note.trim().isEmpty ? null : note.trim(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    });

    await _refreshWatchSummarySafely();
  }

  Future<void> addIncome({
    required String title,
    required double amount,
    required DateTime date,
    String? bankAccountId,
    String? bankAccountName,
  }) async {
    await _db.runTransaction((transaction) async {
      final incomeRef = incomesRef.doc();

      DocumentReference<Map<String, dynamic>>? accountRef;
      DocumentSnapshot<Map<String, dynamic>>? accountSnapshot;

      if (bankAccountId != null && bankAccountId.trim().isNotEmpty) {
        accountRef = bankAccountsRef.doc(bankAccountId);
        accountSnapshot = await transaction.get(accountRef);
      }

      transaction.set(incomeRef, {
        'title': title.trim(),
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'bankAccountId': bankAccountId,
        'bankAccountName': bankAccountName,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (accountRef != null &&
          accountSnapshot != null &&
          accountSnapshot.exists) {
        final accountData = accountSnapshot.data() ?? {};
        final currentBalance = _toDouble(accountData['balance']);

        transaction.update(accountRef, {
          'balance': currentBalance + amount,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    });

    await _refreshWatchSummarySafely();
    await _generateAiInsightsSafely();
  }

  Future<void> updateIncome({
    required String incomeId,
    required String title,
    required double amount,
    required DateTime date,
    String? bankAccountId,
    String? bankAccountName,
  }) async {
    await _db.runTransaction((transaction) async {
      final incomeRef = incomesRef.doc(incomeId);
      final incomeSnapshot = await transaction.get(incomeRef);

      if (!incomeSnapshot.exists) {
        throw Exception('Entrata non trovata');
      }

      final oldData = incomeSnapshot.data() ?? {};
      final oldAmount = _toDouble(oldData['amount']);
      final oldBankAccountId = oldData['bankAccountId']?.toString();

      DocumentReference<Map<String, dynamic>>? oldAccountRef;
      DocumentSnapshot<Map<String, dynamic>>? oldAccountSnapshot;

      DocumentReference<Map<String, dynamic>>? newAccountRef;
      DocumentSnapshot<Map<String, dynamic>>? newAccountSnapshot;

      if (oldBankAccountId != null && oldBankAccountId.trim().isNotEmpty) {
        oldAccountRef = bankAccountsRef.doc(oldBankAccountId);
        oldAccountSnapshot = await transaction.get(oldAccountRef);
      }

      if (bankAccountId != null && bankAccountId.trim().isNotEmpty) {
        newAccountRef = bankAccountsRef.doc(bankAccountId);
        newAccountSnapshot = await transaction.get(newAccountRef);
      }

      transaction.update(incomeRef, {
        'title': title.trim(),
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'bankAccountId': bankAccountId,
        'bankAccountName': bankAccountName,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (oldAccountRef != null &&
          oldAccountSnapshot != null &&
          oldAccountSnapshot.exists &&
          oldBankAccountId == bankAccountId) {
        final oldAccountData = oldAccountSnapshot.data() ?? {};
        final currentBalance = _toDouble(oldAccountData['balance']);
        final difference = amount - oldAmount;

        transaction.update(oldAccountRef, {
          'balance': currentBalance + difference,
          'updated_at': FieldValue.serverTimestamp(),
        });

        return;
      }

      if (oldAccountRef != null &&
          oldAccountSnapshot != null &&
          oldAccountSnapshot.exists) {
        final oldAccountData = oldAccountSnapshot.data() ?? {};
        final currentBalance = _toDouble(oldAccountData['balance']);

        transaction.update(oldAccountRef, {
          'balance': currentBalance - oldAmount,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      if (newAccountRef != null &&
          newAccountSnapshot != null &&
          newAccountSnapshot.exists) {
        final newAccountData = newAccountSnapshot.data() ?? {};
        final currentBalance = _toDouble(newAccountData['balance']);

        transaction.update(newAccountRef, {
          'balance': currentBalance + amount,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    });

    await _refreshWatchSummarySafely();
    await _generateAiInsightsSafely();
  }

  Future<void> deleteIncome({
    required String incomeId,
  }) async {
    await _db.runTransaction((transaction) async {
      final incomeRef = incomesRef.doc(incomeId);
      final incomeSnapshot = await transaction.get(incomeRef);

      if (!incomeSnapshot.exists) {
        throw Exception('Entrata non trovata');
      }

      final data = incomeSnapshot.data() ?? {};
      final amount = _toDouble(data['amount']);
      final bankAccountId = data['bankAccountId']?.toString();

      DocumentReference<Map<String, dynamic>>? accountRef;
      DocumentSnapshot<Map<String, dynamic>>? accountSnapshot;

      if (bankAccountId != null && bankAccountId.trim().isNotEmpty) {
        accountRef = bankAccountsRef.doc(bankAccountId);
        accountSnapshot = await transaction.get(accountRef);
      }

      transaction.delete(incomeRef);

      if (accountRef != null &&
          accountSnapshot != null &&
          accountSnapshot.exists) {
        final accountData = accountSnapshot.data() ?? {};
        final currentBalance = _toDouble(accountData['balance']);

        transaction.update(accountRef, {
          'balance': currentBalance - amount,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    });

    await _refreshWatchSummarySafely();
    await _generateAiInsightsSafely();
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
    String? bankAccountId,
    String? bankAccountName,
  }) async {
    final isPlanned = type == 'planned';

    final shouldMoveMoney = !isPlanned &&
        isPaid &&
        bankAccountId != null &&
        bankAccountId.trim().isNotEmpty;

    final expenseRef = expensesRef.doc();

    await _db.runTransaction((transaction) async {
      DocumentReference<Map<String, dynamic>>? accountRef;
      DocumentSnapshot<Map<String, dynamic>>? accountSnapshot;

      if (shouldMoveMoney) {
        accountRef = bankAccountsRef.doc(bankAccountId);
        accountSnapshot = await transaction.get(accountRef);
      }

      transaction.set(expenseRef, {
        'title': title.trim(),
        'amount': amount,
        'category': category.trim(),
        'type': isPlanned ? 'planned' : 'standard',
        'due_date':
            isPlanned || dueDate == null ? null : Timestamp.fromDate(dueDate),
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
        'bankAccountId': shouldMoveMoney ? bankAccountId : null,
        'bankAccountName': shouldMoveMoney ? bankAccountName : null,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (accountRef != null &&
          accountSnapshot != null &&
          accountSnapshot.exists) {
        final accountData = accountSnapshot.data() ?? {};
        final currentBalance = _toDouble(accountData['balance']);

        transaction.update(accountRef, {
          'balance': currentBalance - amount,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    });

    await _syncExpenseReminderSafely(
      expenseId: expenseRef.id,
      title: title.trim(),
      amount: amount,
      dueDate: dueDate,
      isPaid: isPaid,
      reminderEnabled: reminderEnabled,
      isPlanned: isPlanned,
    );

    await _refreshWatchSummarySafely();
    await _generateAiInsightsSafely();
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
    final createdExpenses = <Map<String, dynamic>>[];

    for (var i = 0; i < dueDates.length; i++) {
      final docRef = expensesRef.doc();
      final dueDate = dueDates[i];

      createdExpenses.add({
        'id': docRef.id,
        'dueDate': dueDate,
      });

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
        'bankAccountId': null,
        'bankAccountName': null,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    for (final item in createdExpenses) {
      final expenseId = item['id']?.toString();
      final dueDate = item['dueDate'];

      if (expenseId == null || dueDate is! DateTime) continue;

      await _syncExpenseReminderSafely(
        expenseId: expenseId,
        title: title.trim(),
        amount: amount,
        dueDate: dueDate,
        isPaid: false,
        reminderEnabled: reminderEnabled,
        isPlanned: false,
      );
    }

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
    String? bankAccountId,
    String? bankAccountName,
  }) async {
    await _db.runTransaction((transaction) async {
      final expenseRef = expensesRef.doc(expenseId);
      final expenseSnapshot = await transaction.get(expenseRef);

      if (!expenseSnapshot.exists) {
        throw Exception('Spesa non trovata');
      }

      final oldData = expenseSnapshot.data() ?? {};
      final oldType = (oldData['type'] ?? 'standard').toString();
      final oldIsPlanned = oldType == 'planned';
      final oldIsPaid = oldData['is_paid'] == true;
      final oldAmount = _toDouble(oldData['amount']);
      final oldBankAccountId = oldData['bankAccountId']?.toString();

      final isPlanned = type == 'planned';

      final oldMovedMoney = !oldIsPlanned &&
          oldIsPaid &&
          oldBankAccountId != null &&
          oldBankAccountId.trim().isNotEmpty;

      final newMovedMoney = !isPlanned &&
          isPaid &&
          bankAccountId != null &&
          bankAccountId.trim().isNotEmpty;

      DocumentReference<Map<String, dynamic>>? oldAccountRef;
      DocumentSnapshot<Map<String, dynamic>>? oldAccountSnapshot;

      DocumentReference<Map<String, dynamic>>? newAccountRef;
      DocumentSnapshot<Map<String, dynamic>>? newAccountSnapshot;

      if (oldMovedMoney) {
        oldAccountRef = bankAccountsRef.doc(oldBankAccountId);
        oldAccountSnapshot = await transaction.get(oldAccountRef);
      }

      if (newMovedMoney) {
        newAccountRef = bankAccountsRef.doc(bankAccountId);
        newAccountSnapshot = await transaction.get(newAccountRef);
      }

      transaction.update(expenseRef, {
        'title': title.trim(),
        'amount': amount,
        'category': category.trim(),
        'type': isPlanned ? 'planned' : 'standard',
        'due_date':
            isPlanned || dueDate == null ? null : Timestamp.fromDate(dueDate),
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
        'bankAccountId': newMovedMoney ? bankAccountId : null,
        'bankAccountName': newMovedMoney ? bankAccountName : null,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (oldMovedMoney &&
          newMovedMoney &&
          oldBankAccountId == bankAccountId &&
          oldAccountRef != null &&
          oldAccountSnapshot != null &&
          oldAccountSnapshot.exists) {
        final accountData = oldAccountSnapshot.data() ?? {};
        final currentBalance = _toDouble(accountData['balance']);
        final difference = oldAmount - amount;

        transaction.update(oldAccountRef, {
          'balance': currentBalance + difference,
          'updated_at': FieldValue.serverTimestamp(),
        });

        return;
      }

      if (oldAccountRef != null &&
          oldAccountSnapshot != null &&
          oldAccountSnapshot.exists) {
        final accountData = oldAccountSnapshot.data() ?? {};
        final currentBalance = _toDouble(accountData['balance']);

        transaction.update(oldAccountRef, {
          'balance': currentBalance + oldAmount,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      if (newAccountRef != null &&
          newAccountSnapshot != null &&
          newAccountSnapshot.exists) {
        final accountData = newAccountSnapshot.data() ?? {};
        final currentBalance = _toDouble(accountData['balance']);

        transaction.update(newAccountRef, {
          'balance': currentBalance - amount,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    });

    await _syncExpenseReminderSafely(
      expenseId: expenseId,
      title: title.trim(),
      amount: amount,
      dueDate: dueDate,
      isPaid: isPaid,
      reminderEnabled: reminderEnabled,
      isPlanned: type == 'planned',
    );

    await _refreshWatchSummarySafely();
    await _generateAiInsightsSafely();
  }

  Future<void> updateExpensePaid({
    required String expenseId,
    required bool isPaid,
    String? bankAccountId,
    String? bankAccountName,
  }) async {
    await _db.runTransaction((transaction) async {
      final expenseRef = expensesRef.doc(expenseId);
      final expenseSnapshot = await transaction.get(expenseRef);

      if (!expenseSnapshot.exists) {
        throw Exception('Spesa non trovata');
      }

      final data = expenseSnapshot.data() ?? {};
      final type = (data['type'] ?? 'standard').toString();

      if (type == 'planned') return;

      final oldIsPaid = data['is_paid'] == true;
      final amount = _toDouble(data['amount']);
      final oldBankAccountId = data['bankAccountId']?.toString();

      if (oldIsPaid == isPaid) return;

      DocumentReference<Map<String, dynamic>>? accountRef;
      DocumentSnapshot<Map<String, dynamic>>? accountSnapshot;

      if (isPaid) {
        if (bankAccountId != null && bankAccountId.trim().isNotEmpty) {
          accountRef = bankAccountsRef.doc(bankAccountId);
          accountSnapshot = await transaction.get(accountRef);
        }

        transaction.update(expenseRef, {
          'is_paid': true,
          'bankAccountId': bankAccountId,
          'bankAccountName': bankAccountName,
          'updated_at': FieldValue.serverTimestamp(),
        });

        if (accountRef != null &&
            accountSnapshot != null &&
            accountSnapshot.exists) {
          final accountData = accountSnapshot.data() ?? {};
          final currentBalance = _toDouble(accountData['balance']);

          transaction.update(accountRef, {
            'balance': currentBalance - amount,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }

        return;
      }

      if (!isPaid) {
        if (oldBankAccountId != null && oldBankAccountId.trim().isNotEmpty) {
          accountRef = bankAccountsRef.doc(oldBankAccountId);
          accountSnapshot = await transaction.get(accountRef);
        }

        transaction.update(expenseRef, {
          'is_paid': false,
          'bankAccountId': null,
          'bankAccountName': null,
          'updated_at': FieldValue.serverTimestamp(),
        });

        if (accountRef != null &&
            accountSnapshot != null &&
            accountSnapshot.exists) {
          final accountData = accountSnapshot.data() ?? {};
          final currentBalance = _toDouble(accountData['balance']);

          transaction.update(accountRef, {
            'balance': currentBalance + amount,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }
    });

    if (isPaid) {
      await _cancelExpenseRemindersSafely(expenseId);
    } else {
      final updatedExpense = await expensesRef.doc(expenseId).get();
      final updatedData = updatedExpense.data();

      if (updatedData != null) {
        await _syncExpenseReminderSafely(
          expenseId: expenseId,
          title: (updatedData['title'] ?? 'Spesa').toString(),
          amount: _toDouble(updatedData['amount']),
          dueDate: _toDate(updatedData['due_date']),
          isPaid: updatedData['is_paid'] == true,
          reminderEnabled: updatedData['reminder_enabled'] == true,
          isPlanned: (updatedData['type'] ?? 'standard').toString() == 'planned',
        );
      }
    }

    await _refreshWatchSummarySafely();
    await _generateAiInsightsSafely();
  }

  Future<void> addExpenseSplitPayment({
    required String expenseId,
    required String title,
    required double amount,
    required DateTime paidAt,
    String? bankAccountId,
    String? bankAccountName,
  }) async {
    final docRef = expensesRef.doc(expenseId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception('Spesa non trovata');
      }

      DocumentReference<Map<String, dynamic>>? accountRef;
      DocumentSnapshot<Map<String, dynamic>>? accountSnapshot;

      if (bankAccountId != null && bankAccountId.trim().isNotEmpty) {
        accountRef = bankAccountsRef.doc(bankAccountId);
        accountSnapshot = await transaction.get(accountRef);
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
        'bankAccountId': bankAccountId,
        'bankAccountName': bankAccountName,
        'created_at': Timestamp.now(),
      });

      transaction.update(docRef, {
        'split_items': currentItems,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (accountRef != null &&
          accountSnapshot != null &&
          accountSnapshot.exists) {
        final accountData = accountSnapshot.data() ?? {};
        final currentBalance = _toDouble(accountData['balance']);

        transaction.update(accountRef, {
          'balance': currentBalance - amount,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    });

    await _refreshWatchSummarySafely();
  }

  Future<void> updateExpenseSplitItems({
    required String expenseId,
    required List<Map<String, dynamic>> splitItems,
  }) async {
    final docRef = expensesRef.doc(expenseId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception('Spesa non trovata');
      }

      final data = snapshot.data() ?? {};
      final oldRawItems = data['split_items'];

      final oldItems = oldRawItems is List
          ? oldRawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

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
          'bankAccountId': item['bankAccountId'],
          'bankAccountName': item['bankAccountName'],
          'created_at': rawCreatedAt is Timestamp
              ? rawCreatedAt
              : rawCreatedAt is DateTime
                  ? Timestamp.fromDate(rawCreatedAt)
                  : Timestamp.now(),
        };
      }).toList();

      final Map<String, double> oldAccountTotals = {};
      final Map<String, double> newAccountTotals = {};

      for (final item in oldItems) {
        final accountId = item['bankAccountId']?.toString();

        if (accountId == null || accountId.trim().isEmpty) continue;

        oldAccountTotals[accountId] =
            (oldAccountTotals[accountId] ?? 0.0) + _toDouble(item['amount']);
      }

      for (final item in cleanedItems) {
        final accountId = item['bankAccountId']?.toString();

        if (accountId == null || accountId.trim().isEmpty) continue;

        newAccountTotals[accountId] =
            (newAccountTotals[accountId] ?? 0.0) + _toDouble(item['amount']);
      }

      final accountIds = <String>{
        ...oldAccountTotals.keys,
        ...newAccountTotals.keys,
      };

      final accountSnapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};

      for (final accountId in accountIds) {
        final accountRef = bankAccountsRef.doc(accountId);
        final accountSnapshot = await transaction.get(accountRef);
        accountSnapshots[accountId] = accountSnapshot;
      }

      transaction.update(docRef, {
        'split_items': cleanedItems,
        'updated_at': FieldValue.serverTimestamp(),
      });

      for (final accountId in accountIds) {
        final oldTotal = oldAccountTotals[accountId] ?? 0.0;
        final newTotal = newAccountTotals[accountId] ?? 0.0;
        final difference = oldTotal - newTotal;

        if (difference == 0) continue;

        final accountSnapshot = accountSnapshots[accountId];

        if (accountSnapshot == null || !accountSnapshot.exists) continue;

        final accountRef = bankAccountsRef.doc(accountId);
        final accountData = accountSnapshot.data() ?? {};
        final currentBalance = _toDouble(accountData['balance']);

        transaction.update(accountRef, {
          'balance': currentBalance + difference,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    });

    await _refreshWatchSummarySafely();
  }

  Future<void> deleteExpense({
    required String expenseId,
  }) async {
    await _db.runTransaction((transaction) async {
      final expenseRef = expensesRef.doc(expenseId);
      final expenseSnapshot = await transaction.get(expenseRef);

      if (!expenseSnapshot.exists) return;

      final data = expenseSnapshot.data() ?? {};
      final type = (data['type'] ?? 'standard').toString();

      final Map<String, double> amountsToRestore = {};

      if (type == 'planned') {
        final splitItems = data['split_items'];

        if (splitItems is List) {
          for (final item in splitItems) {
            if (item is! Map) continue;

            final accountId = item['bankAccountId']?.toString();

            if (accountId == null || accountId.trim().isEmpty) continue;

            amountsToRestore[accountId] =
                (amountsToRestore[accountId] ?? 0.0) +
                    _toDouble(item['amount']);
          }
        }
      } else {
        final isPaid = data['is_paid'] == true;
        final accountId = data['bankAccountId']?.toString();

        if (isPaid && accountId != null && accountId.trim().isNotEmpty) {
          amountsToRestore[accountId] = _toDouble(data['amount']);
        }
      }

      final accountSnapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};

      for (final accountId in amountsToRestore.keys) {
        final accountRef = bankAccountsRef.doc(accountId);
        final accountSnapshot = await transaction.get(accountRef);
        accountSnapshots[accountId] = accountSnapshot;
      }

      transaction.delete(expenseRef);

      for (final entry in amountsToRestore.entries) {
        final accountSnapshot = accountSnapshots[entry.key];

        if (accountSnapshot == null || !accountSnapshot.exists) continue;

        final accountRef = bankAccountsRef.doc(entry.key);
        final accountData = accountSnapshot.data() ?? {};
        final currentBalance = _toDouble(accountData['balance']);

        transaction.update(accountRef, {
          'balance': currentBalance + entry.value,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    });

    await _cancelExpenseRemindersSafely(expenseId);

    await _refreshWatchSummarySafely();
    await _generateAiInsightsSafely();
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
    await _generateAiInsightsSafely();
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
    await _generateAiInsightsSafely();
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
    await _generateAiInsightsSafely();
  }

  Future<void> deleteGoal({
    required String goalId,
  }) async {
    await goalsRef.doc(goalId).delete();

    await _refreshWatchSummarySafely();
    await _generateAiInsightsSafely();
  }

  Future<double> _getTotalBankBalance() async {
    final snapshot = await bankAccountsRef.get();

    double total = 0.0;

    for (final doc in snapshot.docs) {
      total += _toDouble(doc.data()['balance']);
    }

    return total;
  }

  Future<List<Map<String, dynamic>>> _getBankAccountsForAI() async {
    final snapshot = await bankAccountsRef.orderBy('created_at').get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        'name': (data['name'] ?? 'Conto').toString(),
        'balance': _toDouble(data['balance']),
      };
    }).toList();
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

    final totalBankBalance = await _getTotalBankBalance();

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
      mainGoalRemainingAmount = mainGoalTargetAmount - mainGoalCurrentAmount;

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
    final double remainingBudgetWithBank = totalBankBalance - totalExpenses;

    return {
      'monthly_income': monthlyIncome,
      'monthly_expenses': monthlyExpenses,
      'monthly_planned_expenses': monthlyPlannedExpenses,
      'total_monthly_expenses': totalExpenses,
      'remaining_budget': remainingBudget,
      'total_bank_balance': totalBankBalance,
      'remaining_budget_with_bank': remainingBudgetWithBank,
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
    final bankAccounts = await _getBankAccountsForAI();
    final aiPersonalProfile = await getAiPersonalProfile();

    final aiProfile = Map<String, dynamic>.from(
      aiPersonalProfile['ai_profile'] ?? {},
    );

    final aiLearningProfile = Map<String, dynamic>.from(
      aiPersonalProfile['ai_learning_profile'] ?? {},
    );

    double totalBankBalance = 0.0;

    for (final account in bankAccounts) {
      totalBankBalance += _toDouble(account['balance']);
    }

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
    final double availableBudgetWithBank = totalBankBalance - totalExpenses;

    final double safetyBuffer = monthlyIncome > 0
        ? monthlyIncome * 0.10
        : totalBankBalance > 0
            ? totalBankBalance * 0.05
            : 0.0;

    final double spendableBudget = availableBudget - safetyBuffer;
    final double spendableBudgetWithBank =
        availableBudgetWithBank - safetyBuffer;

    final double dailyAvailable = remainingDaysInMonth > 0
        ? availableBudget / remainingDaysInMonth
        : availableBudget;

    final double dailyAvailableWithBank = remainingDaysInMonth > 0
        ? availableBudgetWithBank / remainingDaysInMonth
        : availableBudgetWithBank;

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
      availableBudgetWithBank: availableBudgetWithBank,
      totalBankBalance: totalBankBalance,
      safetyBuffer: safetyBuffer,
      spendableBudget: spendableBudget,
      spendableBudgetWithBank: spendableBudgetWithBank,
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
      availableBudgetWithBank: availableBudgetWithBank,
      totalBankBalance: totalBankBalance,
      activeGoals: activeGoals.length,
    );

    final mood = _financialMood(
      score: financialHealthScore,
      availableBudget: availableBudget,
      availableBudgetWithBank: availableBudgetWithBank,
      monthlyIncome: monthlyIncome,
      totalBankBalance: totalBankBalance,
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
      'total_bank_balance': totalBankBalance,
      'available_budget_with_bank': availableBudgetWithBank,
      'safety_buffer': safetyBuffer,
      'spendable_budget': spendableBudget < 0 ? 0.0 : spendableBudget,
      'spendable_budget_with_bank':
          spendableBudgetWithBank < 0 ? 0.0 : spendableBudgetWithBank,
      'daily_available': dailyAvailable,
      'daily_available_with_bank': dailyAvailableWithBank,
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
      'bank_accounts': bankAccounts,
      'suggestions': suggestions,
      'financial_health_score': financialHealthScore,
      'financial_mood': mood,

      // Profilo AI dichiarato dall’utente durante onboarding
      'ai_profile': aiProfile,

      // Profilo AI imparato dall’uso reale dell’app
      'ai_learning_profile': aiLearningProfile,

      // Contesto già pronto da usare nelle risposte AI
      'ai_personal_context': _buildAiPersonalContext(
        aiProfile: aiProfile,
        aiLearningProfile: aiLearningProfile,
      ),

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

    await _learnFromAIQuestionSafely(
      question: cleanedQuestion,
      snapshot: snapshot,
    );

    return _buildLocalAIPlannerAnswer(
      question: cleanedQuestion,
      snapshot: snapshot,
    );
  }

  Future<void> _learnFromAIQuestionSafely({
    required String question,
    required Map<String, dynamic> snapshot,
  }) async {
    try {
      await _learnFromAIQuestion(
        question: question,
        snapshot: snapshot,
      );
    } catch (_) {
      // L’apprendimento AI non deve mai bloccare la risposta all’utente.
    }
  }

  Future<void> _learnFromAIQuestion({
    required String question,
    required Map<String, dynamic> snapshot,
  }) async {
    final normalized = _normalizeAIQuestion(question);

    final asksBeforeSpending = _questionContainsAny(normalized, [
      'posso spendere',
      'posso comprare',
      'me lo posso permettere',
      'posso permettermi',
      'acquistare',
      'comprare',
      'spendere',
    ]);

    final asksAboutSaving = _questionContainsAny(normalized, [
      'risparmiare',
      'mettere da parte',
      'quanto posso risparmiare',
      'accantonare',
    ]);

    final asksAboutGoals = _questionContainsAny(normalized, [
      'obiettivo',
      'obiettivi',
      'target',
      'raggiungere',
      'scadenza',
    ]);

    final monthlyIncome = _toDouble(snapshot['monthly_income']);
    final totalExpenses = _toDouble(snapshot['total_expenses']);
    final availableBudget = _toDouble(snapshot['available_budget']);
    final safetyBuffer = _toDouble(snapshot['safety_buffer']);
    final topCategoryName = (snapshot['top_category_name'] ?? '').toString();
    final mood = (snapshot['financial_mood'] ?? '').toString();

    String spendingPattern = '';

    if (monthlyIncome > 0) {
      final ratio = totalExpenses / monthlyIncome;

      if (ratio >= 0.90) {
        spendingPattern = 'spese molto alte rispetto alle entrate';
      } else if (ratio >= 0.75) {
        spendingPattern = 'spese da monitorare';
      } else if (ratio <= 0.50) {
        spendingPattern = 'gestione prudente delle spese';
      } else {
        spendingPattern = 'spese abbastanza equilibrate';
      }
    }

    String budgetSensitivity = '';

    if (availableBudget < 0) {
      budgetSensitivity = 'alta';
    } else if (safetyBuffer > 0 && availableBudget <= safetyBuffer) {
      budgetSensitivity = 'medio-alta';
    } else {
      budgetSensitivity = 'media';
    }

    String responsePreference = '';

    final aiProfile = snapshot['ai_profile'];
    if (aiProfile is Map) {
      final profile = Map<String, dynamic>.from(aiProfile);
      final adviceStyle = (profile['advice_style'] ?? '').toString();

      if (adviceStyle == 'simple') {
        responsePreference = 'risposte brevi e pratiche';
      } else if (adviceStyle == 'detailed') {
        responsePreference = 'risposte dettagliate e spiegate';
      } else if (adviceStyle == 'motivational') {
        responsePreference = 'risposte motivazionali e rassicuranti';
      } else if (adviceStyle == 'practical') {
        responsePreference = 'risposte pratiche e dirette';
      }
    }

    String preferredGoalFocus = '';

    final activeGoals = snapshot['active_goals'];

    if (activeGoals is List && activeGoals.isNotEmpty) {
      final firstGoal = activeGoals.first;

      if (firstGoal is Map) {
        preferredGoalFocus = (firstGoal['title'] ?? '').toString();
      }
    }

    await updateAiLearningProfile(
      preferredGoalFocus:
          preferredGoalFocus.trim().isEmpty ? null : preferredGoalFocus,
      spendingPattern: spendingPattern.trim().isEmpty ? null : spendingPattern,
      budgetSensitivity:
          budgetSensitivity.trim().isEmpty ? null : budgetSensitivity,
      responsePreference:
          responsePreference.trim().isEmpty ? null : responsePreference,
      lastFinancialMood: mood.trim().isEmpty ? null : mood,
      strongestGoalCategory:
          topCategoryName.trim().isEmpty ? null : topCategoryName,
      oftenAsksBeforeSpending: asksBeforeSpending ? true : null,
      oftenAsksAboutSaving: asksAboutSaving ? true : null,
      oftenAsksAboutGoals: asksAboutGoals ? true : null,
    );
  }

  Future<void> generateAiInsights() async {
    final snapshot = await getAIPlannerSnapshot();

    final monthlyIncome = _toDouble(snapshot['monthly_income']);
    final totalExpenses = _toDouble(snapshot['total_expenses']);
    final unpaidExpenses = _toDouble(snapshot['unpaid_expenses']);
    final availableBudget = _toDouble(snapshot['available_budget']);
    final safetyBuffer = _toDouble(snapshot['safety_buffer']);
    final spendableBudget = _toDouble(snapshot['spendable_budget']);
    final topCategoryName = (snapshot['top_category_name'] ?? '').toString();
    final topCategoryAmount = _toDouble(snapshot['top_category_amount']);
    final mainGoal = snapshot['main_goal'];
    final personalOpening = _personalizedOpeningFromSnapshot(snapshot);

    if (monthlyIncome <= 0) return;

    await updateAiLearningProfile(
      spendingPattern: totalExpenses > monthlyIncome * 0.85
          ? 'spese alte rispetto alle entrate'
          : 'spese monitorate nel mese',
      budgetSensitivity: availableBudget <= safetyBuffer && safetyBuffer > 0
          ? 'medio-alta'
          : 'media',
      lastFinancialMood: (snapshot['financial_mood'] ?? '').toString(),
      strongestGoalCategory:
          topCategoryName.trim().isEmpty ? null : topCategoryName,
    );

    final insightsRef = _db.collection('users').doc(_uid).collection('ai_insights');

    final now = DateTime.now();
    final todayKey =
        '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';

    String safeCode(String value) {
      return value
          .toLowerCase()
          .trim()
          .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
    }

    Future<void> createInsight({
      required String code,
      required String title,
      required String message,
      required String type,
      required int priority,
    }) async {
      final cleanedCode = safeCode(code);
      final baseDocId = '${todayKey}_$cleanedCode';
      final baseDocRef = insightsRef.doc(baseDocId);

      final existing = await baseDocRef.get();

      if (existing.exists) {
        final existingData = existing.data() ?? {};
        final isArchived = existingData['is_archived'] == true;

        // Se il messaggio esiste ed è ancora visibile/non archiviato,
        // non lo ricreo per evitare duplicati.
        if (!isArchived) return;

        // Se invece l'utente lo aveva già archiviato con "Ho capito",
        // e una nuova modifica genera di nuovo lo stesso avviso,
        // creo una nuova notifica con ID diverso.
        final newDocId =
            '${baseDocId}_${DateTime.now().millisecondsSinceEpoch}';

        await insightsRef.doc(newDocId).set({
          'code': cleanedCode,
          'title': title,
          'message': message,
          'type': type,
          'priority': priority,
          'is_read': false,
          'is_archived': false,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        await _notifyAiInsightSafely(
          code: cleanedCode,
          title: title,
          message: message,
          priority: priority,
        );

        return;
      }

      await baseDocRef.set({
        'code': cleanedCode,
        'title': title,
        'message': message,
        'type': type,
        'priority': priority,
        'is_read': false,
        'is_archived': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _notifyAiInsightSafely(
        code: cleanedCode,
        title: title,
        message: message,
        priority: priority,
      );
    }

    final expenseRatio = totalExpenses / monthlyIncome;

    if (totalExpenses > monthlyIncome) {
      await createInsight(
        code: 'expenses_over_income',
        title: 'Spese sopra le entrate',
        message:
            '${personalOpening}questo mese le spese totali superano le entrate. Ti consiglio di bloccare le spese extra e controllare le uscite non urgenti.',
        type: 'danger',
        priority: 100,
      );

      return;
    }

    if (expenseRatio >= 0.85) {
      await createInsight(
        code: 'budget_almost_finished',
        title: 'Budget quasi esaurito',
        message:
            '${personalOpening}Hai già usato circa ${(expenseRatio * 100).toStringAsFixed(0)}% delle entrate mensili. Meglio rallentare con le spese fino a fine mese.',
        type: 'warning',
        priority: 90,
      );
    }

    if (availableBudget <= safetyBuffer && safetyBuffer > 0) {
      await createInsight(
        code: 'near_safety_buffer',
        title: 'Sei vicino al margine di sicurezza',
        message:
            'Hai ancora budget disponibile, ma sei vicino al margine di sicurezza. Ti consiglio prudenza con nuovi acquisti.',
        type: 'warning',
        priority: 80,
      );
    }

    if (unpaidExpenses > monthlyIncome * 0.30) {
      await createInsight(
        code: 'many_unpaid_expenses',
        title: 'Molte spese ancora da pagare',
        message:
            'Hai ancora ${_formatMoneyText(unpaidExpenses)} di spese non pagate. Prima di fare nuovi acquisti, controlla le prossime scadenze.',
        type: 'warning',
        priority: 85,
      );
    }

    if (topCategoryName.isNotEmpty && topCategoryAmount > 0) {
      final categoryRatio =
          totalExpenses > 0 ? topCategoryAmount / totalExpenses : 0.0;

      if (categoryRatio >= 0.35) {
        await createInsight(
          code: 'heavy_category_$topCategoryName',
          title: 'Categoria molto pesante',
          message:
              'La categoria "$topCategoryName" pesa molto questo mese. Riducendola anche solo del 20%, potresti recuperare circa ${_formatMoneyText(topCategoryAmount * 0.20)}.',
          type: 'warning',
          priority: 75,
        );
      }
    }

    if (spendableBudget >= 50 && mainGoal is Map<String, dynamic>) {
      final goalTitle = (mainGoal['title'] ?? '').toString();
      final remainingAmount = _toDouble(mainGoal['remaining_amount']);

      if (goalTitle.isNotEmpty && remainingAmount > 0) {
        final suggestedSaving = _suggestedGoalSaving(
          spendableBudget: spendableBudget,
          remainingGoalAmount: remainingAmount,
        );

        await createInsight(
          code: 'goal_saving_available',
          title: 'Puoi mettere qualcosa da parte',
          message:
              'Hai un margine positivo. Potresti mettere circa ${_formatMoneyText(suggestedSaving)} sull’obiettivo "$goalTitle".',
          type: 'success',
          priority: 65,
        );
      }
    }
  }

  Future<void> _generateAiInsightsSafely() async {
    try {
      await generateAiInsights();
    } catch (error) {
      // L'AI non deve mai bloccare il salvataggio di spese, entrate o obiettivi.
      // Se vuoi debug temporaneo:
      // print('Errore generateAiInsights: $error');
    }
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
      // il salvataggio principale di entrate, spese, conti o obiettivi.
    }
  }

List<String> _buildAIPlannerSuggestions({
  required double monthlyIncome,
  required double paidExpenses,
  required double unpaidExpenses,
  required double plannedExpenses,
  required double availableBudget,
  required double availableBudgetWithBank,
  required double totalBankBalance,
  required double safetyBuffer,
  required double spendableBudget,
  required double spendableBudgetWithBank,
  required double previousTotalExpenses,
  required double currentTotalExpenses,
  required String topCategoryName,
  required double topCategoryAmount,
  required Map<String, dynamic>? mainGoal,
  }) {
    final suggestions = <String>[];

    final totalExpenses = paidExpenses + unpaidExpenses + plannedExpenses;
    final usableSpendableBudget =
        spendableBudget > 0 ? spendableBudget : spendableBudgetWithBank;

    final expenseRatio = monthlyIncome > 0 ? totalExpenses / monthlyIncome : 0.0;
    final unpaidRatio = monthlyIncome > 0 ? unpaidExpenses / monthlyIncome : 0.0;
    final savingPotential = usableSpendableBudget > 0
        ? (usableSpendableBudget * 0.35).clamp(0.0, usableSpendableBudget)
        : 0.0;

    if (monthlyIncome <= 0 && totalBankBalance <= 0) {
      suggestions.add(
        'Non hai ancora registrato entrate o soldi disponibili in banca. Inserisci almeno un conto o un’entrata per ricevere consigli più precisi.',
      );

      return suggestions;
    }

    if (monthlyIncome <= 0 && totalBankBalance > 0) {
      suggestions.add(
        'Non hai ancora registrato entrate per questo mese, però hai ${_formatMoneyText(totalBankBalance)} nei conti. Posso aiutarti a gestire la liquidità, ma per un piano mensile realistico ti consiglio di inserire anche le entrate.',
      );
    }

    if (monthlyIncome > 0) {
      if (availableBudget < 0 && totalBankBalance > 0) {
        if (availableBudgetWithBank >= 0) {
          suggestions.add(
            'Questo mese le uscite superano le entrate di circa ${_formatMoneyText(availableBudget.abs())}. Puoi coprire la differenza con i soldi in banca, ma stai consumando liquidità già disponibile.',
          );
        } else {
          suggestions.add(
            'Questo mese le uscite superano le entrate e anche considerando i soldi in banca il margine resta negativo. Ti consiglio di bloccare le spese extra e rimandare quelle non urgenti.',
          );
        }
      } else if (availableBudget < 0) {
        suggestions.add(
          'Questo mese le uscite superano le entrate. Prima di fare nuove spese, prova a ridurre o rimandare quelle non urgenti.',
        );
      } else if (expenseRatio >= 0.90) {
        suggestions.add(
          'Hai già impegnato circa ${(expenseRatio * 100).toStringAsFixed(0)}% delle entrate mensili. È una situazione delicata: meglio evitare spese non essenziali fino a fine mese.',
        );
      } else if (expenseRatio >= 0.75) {
        suggestions.add(
          'Le spese stanno salendo: hai usato circa ${(expenseRatio * 100).toStringAsFixed(0)}% delle entrate. Sei ancora in tempo per mantenere un buon margine.',
        );
      } else if (availableBudget <= safetyBuffer && safetyBuffer > 0) {
        suggestions.add(
          'Hai ancora budget disponibile, ma sei vicino al margine di sicurezza. Ti consiglio di evitare spese extra non necessarie.',
        );
      } else {
        suggestions.add(
          'La situazione del mese è sotto controllo. Puoi gestire le prossime spese mantenendo comunque un margine di sicurezza.',
        );
      }
    }

    if (totalBankBalance > 0) {
      suggestions.add(
        'Al momento hai ${_formatMoneyText(totalBankBalance)} disponibili nei conti registrati.',
      );
    }

    if (unpaidExpenses > 0) {
      if (unpaidRatio >= 0.30) {
        suggestions.add(
          'Hai ancora ${_formatMoneyText(unpaidExpenses)} di spese da pagare. Prima di destinare soldi agli obiettivi, ti conviene dare priorità a queste scadenze.',
        );
      } else {
        suggestions.add(
          'Hai ancora spese da pagare per ${_formatMoneyText(unpaidExpenses)}. Considerale come soldi già impegnati prima di fare nuovi acquisti.',
        );
      }
    }

    if (plannedExpenses > 0) {
      suggestions.add(
        'Hai ${_formatMoneyText(plannedExpenses)} di spese pianificate questo mese. Anche se non sono ancora uscite reali, è meglio trattarle come budget già occupato.',
      );
    }

    if (savingPotential >= 10 && availableBudget > safetyBuffer) {
      suggestions.add(
        'Hai un margine positivo: potresti mettere da parte circa ${_formatMoneyText(savingPotential)} questo mese senza usare tutto il budget libero.',
      );
    }

    if (previousTotalExpenses > 0 &&
        currentTotalExpenses > previousTotalExpenses) {
      final difference = currentTotalExpenses - previousTotalExpenses;
      final ratio = difference / previousTotalExpenses;

      if (ratio >= 0.20) {
        suggestions.add(
          'Questo mese stai spendendo circa ${_formatMoneyText(difference)} in più rispetto al mese scorso. Ti consiglio di controllare subito le categorie più pesanti.',
        );
      } else {
        suggestions.add(
          'Questo mese stai spendendo circa ${_formatMoneyText(difference)} in più rispetto al mese scorso. Tieni d’occhio le uscite nei prossimi giorni.',
        );
      }
    } else if (previousTotalExpenses > 0 &&
        currentTotalExpenses < previousTotalExpenses) {
      final difference = previousTotalExpenses - currentTotalExpenses;

      suggestions.add(
        'Rispetto al mese scorso stai spendendo circa ${_formatMoneyText(difference)} in meno. Ottimo segnale: potresti trasformare parte di questo margine in risparmio.',
      );
    }

    if (topCategoryName.isNotEmpty && topCategoryAmount > 0) {
      final categoryRatio =
          currentTotalExpenses > 0 ? topCategoryAmount / currentTotalExpenses : 0.0;

      if (categoryRatio >= 0.35) {
        final possibleSaving = topCategoryAmount * 0.20;

        suggestions.add(
          'La categoria "$topCategoryName" pesa molto questo mese: ${_formatMoneyText(topCategoryAmount)}. Riducendola del 20%, potresti liberare circa ${_formatMoneyText(possibleSaving)}.',
        );
      } else {
        suggestions.add(
          'La categoria che pesa di più questo mese è "$topCategoryName" con ${_formatMoneyText(topCategoryAmount)}.',
        );
      }
    }

    if (mainGoal != null) {
      final goalTitle = (mainGoal['title'] ?? '').toString();
      final remainingAmount = _toDouble(mainGoal['remaining_amount']);
      final progress = _toDouble(mainGoal['progress']);
      final daysRemaining = mainGoal['days_remaining'];

      if (goalTitle.isNotEmpty && remainingAmount > 0) {
        if (usableSpendableBudget > 0) {
          final suggestedSaving = _suggestedGoalSaving(
            spendableBudget: usableSpendableBudget,
            remainingGoalAmount: remainingAmount,
          );

          if (remainingAmount <= usableSpendableBudget) {
            suggestions.add(
              'L’obiettivo "$goalTitle" è raggiungibile: ti mancano ${_formatMoneyText(remainingAmount)} e il tuo margine attuale potrebbe coprirlo.',
            );
          } else {
            suggestions.add(
              'Per l’obiettivo "$goalTitle", potresti mettere da parte circa ${_formatMoneyText(suggestedSaving)} questo mese senza toccare troppo il margine di sicurezza.',
            );
          }
        } else {
          suggestions.add(
            'Hai un obiettivo attivo, "$goalTitle", ma per ora non ti consiglio di aggiungere soldi finché non aumenta il margine disponibile.',
          );
        }

        if (progress >= 70) {
          suggestions.add(
            'Sei già al ${progress.toStringAsFixed(0)}% dell’obiettivo "$goalTitle". Ti manca poco: prova a proteggerlo dalle spese extra.',
          );
        }

        if (daysRemaining is int && daysRemaining >= 0 && daysRemaining <= 30) {
          suggestions.add(
            'L’obiettivo "$goalTitle" è vicino alla scadenza. Mancano circa $daysRemaining giorni.',
          );
        }
      }
    }

    if (suggestions.isEmpty) {
      suggestions.add(
        'Aggiungi entrate, spese e obiettivi per ricevere consigli più precisi dal tuo AI Planner.',
      );
    }

    return suggestions.take(8).toList();
  }

  int _calculateFinancialHealthScore({
    required double monthlyIncome,
    required double totalExpenses,
    required double unpaidExpenses,
    required double availableBudget,
    required double availableBudgetWithBank,
    required double totalBankBalance,
    required int activeGoals,
  }) {
    if (monthlyIncome <= 0 && totalBankBalance <= 0) return 35;

    int score = 70;

    if (monthlyIncome > 0) {
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
    } else {
      score -= 10;
    }

    if (availableBudget < 0 && availableBudgetWithBank >= 0) {
      score -= 10;
    } else if (availableBudgetWithBank < 0) {
      score -= 25;
    } else if (monthlyIncome > 0 && availableBudget >= monthlyIncome * 0.20) {
      score += 10;
    }

    if (monthlyIncome > 0 && unpaidExpenses > monthlyIncome * 0.35) {
      score -= 10;
    }

    if (totalBankBalance > 0) {
      score += 5;
    }

    if (activeGoals > 0 && availableBudgetWithBank > 0) {
      score += 5;
    }

    return score.clamp(0, 100).toInt();
  }

  String _financialMood({
    required int score,
    required double availableBudget,
    required double availableBudgetWithBank,
    required double monthlyIncome,
    required double totalBankBalance,
  }) {
    if (monthlyIncome <= 0 && totalBankBalance <= 0) {
      return 'Da configurare';
    }

    if (availableBudgetWithBank < 0) {
      return 'Critica';
    }

    if (availableBudget < 0 && availableBudgetWithBank >= 0) {
      return 'Da controllare';
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

  String _labelFromValue(String? value, Map<String, String> labels) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }

    return labels[value] ?? value;
  }

  String _mainGoalLabel(Map<String, dynamic>? profile) {
    return _labelFromValue(
      profile?['main_goal']?.toString(),
      {
        'save_more': 'risparmiare di più',
        'control_expenses': 'controllare meglio le spese',
        'reach_goal': 'raggiungere un obiettivo importante',
        'reduce_stress': 'vivere con più tranquillità nella gestione dei soldi',
      },
    );
  }

  String _moneyFeelingLabel(Map<String, dynamic>? profile) {
    return _labelFromValue(
      profile?['money_feeling']?.toString(),
      {
        'calm': 'abbastanza tranquillo',
        'medium': 'così così',
        'confused': 'un po’ confuso',
        'stressed': 'spesso in difficoltà',
      },
    );
  }

  String _adviceStyleLabel(Map<String, dynamic>? profile) {
    return _labelFromValue(
      profile?['advice_style']?.toString(),
      {
        'practical': 'pratico e diretto',
        'motivational': 'motivazionale',
        'detailed': 'dettagliato',
        'simple': 'semplice e veloce',
      },
    );
  }

  String _aiFrequencyLabel(Map<String, dynamic>? profile) {
    return _labelFromValue(
      profile?['ai_frequency']?.toString(),
      {
        'only_when_asked': 'solo quando chiede lui',
        'occasional': 'ogni tanto',
        'frequent': 'spesso e in modo proattivo',
      },
    );
  }

  List<String> _interestLabels(Map<String, dynamic>? profile) {
    final rawInterests = profile?['interests'];

    if (rawInterests is! List) {
      return [];
    }

    final labels = {
      'travel': 'viaggiare',
      'home': 'casa',
      'car': 'auto o moto',
      'emergency_fund': 'fondo emergenza',
      'shopping': 'tempo libero',
      'investing': 'investire nel futuro',
    };

    return rawInterests
        .map((item) => labels[item.toString()] ?? item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  String _buildAiPersonalContext({
    required Map<String, dynamic> aiProfile,
    required Map<String, dynamic> aiLearningProfile,
  }) {
    final lines = <String>[];

    final mainGoal = _mainGoalLabel(aiProfile);
    final interests = _interestLabels(aiProfile);
    final moneyFeeling = _moneyFeelingLabel(aiProfile);
    final adviceStyle = _adviceStyleLabel(aiProfile);
    final aiFrequency = _aiFrequencyLabel(aiProfile);

    if (mainGoal.isNotEmpty) {
      lines.add('Obiettivo principale dichiarato: $mainGoal.');
    }

    if (interests.isNotEmpty) {
      lines.add('Interessi personali dichiarati: ${interests.join(', ')}.');
    }

    if (moneyFeeling.isNotEmpty) {
      lines.add('Rapporto emotivo con i soldi: $moneyFeeling.');
    }

    if (adviceStyle.isNotEmpty) {
      lines.add('Stile di consiglio preferito: $adviceStyle.');
    }

    if (aiFrequency.isNotEmpty) {
      lines.add('Frequenza desiderata dei consigli: $aiFrequency.');
    }

    final preferredGoalFocus =
        (aiLearningProfile['preferred_goal_focus'] ?? '').toString();

    final spendingPattern =
        (aiLearningProfile['spending_pattern'] ?? '').toString();

    final budgetSensitivity =
        (aiLearningProfile['budget_sensitivity'] ?? '').toString();

    final responsePreference =
        (aiLearningProfile['response_preference'] ?? '').toString();

    final strongestGoalCategory =
        (aiLearningProfile['strongest_goal_category'] ?? '').toString();

    if (preferredGoalFocus.isNotEmpty) {
      lines.add('Focus ricorrente osservato: $preferredGoalFocus.');
    }

    if (strongestGoalCategory.isNotEmpty) {
      lines.add('Categoria obiettivo più forte osservata: $strongestGoalCategory.');
    }

    if (spendingPattern.isNotEmpty) {
      lines.add('Pattern di spesa osservato: $spendingPattern.');
    }

    if (budgetSensitivity.isNotEmpty) {
      lines.add('Sensibilità al budget osservata: $budgetSensitivity.');
    }

    if (responsePreference.isNotEmpty) {
      lines.add('Preferenza risposta osservata: $responsePreference.');
    }

    if (aiLearningProfile['often_asks_before_spending'] == true) {
      lines.add(
        'L’utente tende a chiedere conferma prima di spendere: rispondere con chiarezza sul sì/no e sul margine residuo.',
      );
    }

    if (aiLearningProfile['often_asks_about_saving'] == true) {
      lines.add(
        'L’utente chiede spesso quanto può risparmiare: proporre quote realistiche e sostenibili.',
      );
    }

    if (aiLearningProfile['often_asks_about_goals'] == true) {
      lines.add(
        'L’utente mostra interesse per gli obiettivi: collegare i consigli agli obiettivi attivi quando ha senso.',
      );
    }

    return lines.join('\n');
  }

  String _personalizedOpeningFromSnapshot(Map<String, dynamic> snapshot) {
    final aiProfile = snapshot['ai_profile'];
    final aiLearningProfile = snapshot['ai_learning_profile'];

    final profile = aiProfile is Map
        ? Map<String, dynamic>.from(aiProfile)
        : <String, dynamic>{};

    final learning = aiLearningProfile is Map
        ? Map<String, dynamic>.from(aiLearningProfile)
        : <String, dynamic>{};

    final mainGoal = _mainGoalLabel(profile);
    final interests = _interestLabels(profile);
    final moneyFeeling = _moneyFeelingLabel(profile);
    final adviceStyle = _adviceStyleLabel(profile);

    final parts = <String>[];

    if (mainGoal.isNotEmpty) {
      parts.add('visto che il tuo obiettivo principale è $mainGoal');
    }

    if (interests.isNotEmpty) {
      parts.add('tenendo conto che per te contano ${interests.join(', ')}');
    }

    if (moneyFeeling == 'spesso in difficoltà' || moneyFeeling == 'un po’ confuso') {
      parts.add('senza metterti pressione');
    }

    if (adviceStyle == 'semplice e veloce') {
      parts.add('vado dritto al punto');
    }

    if (learning['often_asks_before_spending'] == true) {
      parts.add('ti do una risposta chiara sul margine reale');
    }

    if (parts.isEmpty) {
      return '';
    }

    return '${parts.join(', ')}: ';
  }

  String _personalizedClosingFromSnapshot(Map<String, dynamic> snapshot) {
    final aiProfile = snapshot['ai_profile'];

    final profile = aiProfile is Map
        ? Map<String, dynamic>.from(aiProfile)
        : <String, dynamic>{};

    final moneyFeeling = _moneyFeelingLabel(profile);
    final adviceStyle = _adviceStyleLabel(profile);

    if (moneyFeeling == 'spesso in difficoltà') {
      return ' La cosa importante è non sistemare tutto insieme: prima proteggi le spese essenziali, poi pensiamo agli obiettivi.';
    }

    if (moneyFeeling == 'un po’ confuso') {
      return ' Ti conviene ragionare per passi: prima entrate e spese obbligatorie, poi margine libero, poi obiettivi.';
    }

    if (adviceStyle == 'motivazionale') {
      return ' Sei sulla strada giusta: anche piccoli miglioramenti, ripetuti ogni mese, fanno una grande differenza.';
    }

    return '';
  }

  String _normalizeAIQuestion(String value) {
  var text = value.toLowerCase().trim();

  const replacements = {
    'à': 'a',
    'è': 'e',
    'é': 'e',
    'ì': 'i',
    'ò': 'o',
    'ù': 'u',
  };

  replacements.forEach((from, to) {
    text = text.replaceAll(from, to);
  });

  text = text.replaceAll(RegExp(r'\s+'), ' ');

  return text;
}

bool _questionContainsAny(String text, List<String> words) {
  return words.any(text.contains);
}

String _goalAdviceText({
  required Map<String, dynamic>? mainGoal,
  required double spendableBudget,
  required double spendableBudgetWithBank,
}) {
  if (mainGoal is! Map<String, dynamic>) {
    final realSpendableBudget =
        spendableBudget > 0 ? spendableBudget : spendableBudgetWithBank;

    if (realSpendableBudget <= 0) {
      return 'Al momento non vedo un margine adatto per risparmiare. Prima sistemerei le spese del mese.';
    }

    return 'Non vedo un obiettivo principale attivo. Però potresti mettere da parte circa ${_formatMoneyText(realSpendableBudget * 0.35)} questo mese.';
  }

  final goalTitle = (mainGoal['title'] ?? '').toString();
  final remainingAmount = _toDouble(mainGoal['remaining_amount']);
  final progress = _toDouble(mainGoal['progress']);
  final daysRemaining = mainGoal['days_remaining'];

  final realSpendableBudget =
      spendableBudget > 0 ? spendableBudget : spendableBudgetWithBank;

  if (goalTitle.isEmpty) {
    return 'Hai un obiettivo attivo, ma non riesco a leggere bene il nome. Controlla i dati dell’obiettivo.';
  }

  if (remainingAmount <= 0) {
    return 'L’obiettivo "$goalTitle" sembra già completato. Ottimo lavoro!';
  }

  if (realSpendableBudget <= 0) {
    return 'Hai l’obiettivo "$goalTitle", ma questo mese il margine disponibile è basso. Ti consiglio di proteggere prima le spese essenziali e riprendere il risparmio appena il budget migliora.';
  }

  final suggestedSaving = _suggestedGoalSaving(
    spendableBudget: realSpendableBudget,
    remainingGoalAmount: remainingAmount,
  );

  final buffer = StringBuffer();

  if (remainingAmount <= realSpendableBudget) {
    buffer.write(
      'L’obiettivo "$goalTitle" è molto vicino: ti mancano ${_formatMoneyText(remainingAmount)} e il tuo margine attuale potrebbe coprirlo. ',
    );
  } else {
    buffer.write(
      'Per l’obiettivo "$goalTitle", ti consiglierei di mettere da parte circa ${_formatMoneyText(suggestedSaving)} questo mese. ',
    );
  }

  buffer.write(
    'Sei al ${progress.toStringAsFixed(0)}% e mancano ${_formatMoneyText(remainingAmount)}.',
  );

  if (daysRemaining is int) {
    if (daysRemaining < 0) {
      buffer.write(' La scadenza risulta superata: valuta se aggiornarla.');
    } else if (daysRemaining == 0) {
      buffer.write(' La scadenza è oggi.');
    } else if (daysRemaining <= 30) {
      buffer.write(' Mancano circa $daysRemaining giorni, quindi conviene dargli priorità.');
    }
  }

  return buffer.toString();
}

String _expenseControlAdvice({
  required double monthlyIncome,
  required double totalExpenses,
  required double previousTotalExpenses,
  required String topCategoryName,
  required double topCategoryAmount,
}) {
  if (totalExpenses <= 0) {
    return 'Al momento non vedo spese registrate per questo mese. Quando aggiungi le uscite, posso dirti quali categorie controllare.';
  }

  final expenseRatio = monthlyIncome > 0 ? totalExpenses / monthlyIncome : 0.0;
  final buffer = StringBuffer();

  buffer.write(
    'Questo mese hai uscite totali per ${_formatMoneyText(totalExpenses)}.',
  );

  if (monthlyIncome > 0) {
    buffer.write(
      ' Sono circa ${(expenseRatio * 100).toStringAsFixed(0)}% delle entrate mensili.',
    );

    if (expenseRatio >= 0.90) {
      buffer.write(
        ' È una percentuale alta: ti consiglio di bloccare le spese non essenziali.',
      );
    } else if (expenseRatio >= 0.75) {
      buffer.write(
        ' Sei in una fascia da controllare: meglio ridurre gli acquisti extra.',
      );
    } else {
      buffer.write(
        ' La situazione è ancora gestibile.',
      );
    }
  }

  if (topCategoryName.isNotEmpty && topCategoryAmount > 0) {
    final possibleSaving = topCategoryAmount * 0.20;

    buffer.write(
      ' La categoria più pesante è "$topCategoryName" con ${_formatMoneyText(topCategoryAmount)}.',
    );

    if (possibleSaving >= 5) {
      buffer.write(
        ' Riducendola del 20%, potresti liberare circa ${_formatMoneyText(possibleSaving)}.',
      );
    }
  }

  if (previousTotalExpenses > 0) {
    buffer.write(
      ' ${currentVsPreviousSentence(
        currentTotalExpenses: totalExpenses,
        previousTotalExpenses: previousTotalExpenses,
      )}',
    );
  }

  return buffer.toString();
}

  String _buildLocalAIPlannerAnswer({
    required String question,
    required Map<String, dynamic> snapshot,
  }) {
    final lowerQuestion = _normalizeAIQuestion(question);

    final monthlyIncome = _toDouble(snapshot['monthly_income']);
    final paidExpenses = _toDouble(snapshot['paid_expenses']);
    final unpaidExpenses = _toDouble(snapshot['unpaid_expenses']);
    final plannedExpenses = _toDouble(snapshot['planned_expenses']);
    final totalExpenses = _toDouble(snapshot['total_expenses']);
    final previousTotalExpenses = _toDouble(snapshot['previous_total_expenses']);
    final availableBudget = _toDouble(snapshot['available_budget']);
    final totalBankBalance = _toDouble(snapshot['total_bank_balance']);
    final availableBudgetWithBank =
        _toDouble(snapshot['available_budget_with_bank']);
    final safetyBuffer = _toDouble(snapshot['safety_buffer']);
    final spendableBudget = _toDouble(snapshot['spendable_budget']);
    final spendableBudgetWithBank =
        _toDouble(snapshot['spendable_budget_with_bank']);
    final dailyAvailable = _toDouble(snapshot['daily_available']);
    final dailyAvailableWithBank =
        _toDouble(snapshot['daily_available_with_bank']);
    final topCategoryName = (snapshot['top_category_name'] ?? '').toString();
    final topCategoryAmount = _toDouble(snapshot['top_category_amount']);
    final mood = (snapshot['financial_mood'] ?? '').toString();
    final score = snapshot['financial_health_score'];
    final mainGoal = snapshot['main_goal'];

    final amountInQuestion = _extractFirstAmountFromText(lowerQuestion);
    final personalizedOpening = _personalizedOpeningFromSnapshot(snapshot);
    final personalizedClosing = _personalizedClosingFromSnapshot(snapshot);

    final askedAboutAffordability = _questionContainsAny(lowerQuestion, [
      'posso',
      'permettermi',
      'comprare',
      'spendere',
      'acquistare',
      'prendere',
      'pagare',
      'posso comprare',
      'posso spendere',
      'me lo posso permettere',
    ]);

    final askedAboutSaving = _questionContainsAny(lowerQuestion, [
      'risparmiare',
      'mettere da parte',
      'accantonare',
      'salvare soldi',
      'quanto posso risparmiare',
      'quanto mettere da parte',
    ]);

    final askedAboutGoals = _questionContainsAny(lowerQuestion, [
      'obiettivo',
      'obiettivi',
      'target',
      'raggiungere',
      'scadenza',
      'manca',
      'mancano',
    ]);

    final askedAboutSituation = _questionContainsAny(lowerQuestion, [
      'come sto',
      'situazione',
      'andamento',
      'budget',
      'mese',
      'come va',
      'sto andando',
      'analisi',
      'riepilogo',
    ]);

    final askedAboutExpenses = _questionContainsAny(lowerQuestion, [
      'spese',
      'spendendo',
      'categoria',
      'categorie',
      'uscite',
      'sto spendendo troppo',
      'dove sto spendendo',
      'controllare',
      'tagliare',
      'ridurre',
    ]);

    final askedAboutBank = _questionContainsAny(lowerQuestion, [
      'banca',
      'conto',
      'conti',
      'saldo',
      'liquidita',
      'liquidità',
      'soldi in banca',
    ]);

    final askedAboutDailyBudget = _questionContainsAny(lowerQuestion, [
      'al giorno',
      'giornaliero',
      'ogni giorno',
      'quanto al giorno',
      'giorno',
    ]);

    final askedAboutDanger = _questionContainsAny(lowerQuestion, [
      'rischio',
      'problema',
      'critica',
      'attenzione',
      'male',
      'preoccupare',
      'sforare',
      'rosso',
      'cosa posso fare',
      'cosa devo fare',
      'che posso fare',
      'come posso migliorare',
      'migliorare',
      'sistemare',
      'come risolvo',
      'come posso sistemare',
      'che mi consigli',
      'cosa mi consigli',
      'consiglio',
      'consigli',
    ]);

    if (monthlyIncome <= 0 && totalBankBalance <= 0) {
      return 'Per risponderti bene ho bisogno che tu inserisca almeno un’entrata o un conto bancario con il saldo disponibile. Al momento non vedo soldi registrati, quindi non posso calcolare un budget realistico.';
    }

    if (askedAboutBank) {
      if (totalBankBalance <= 0) {
        return 'Al momento non vedo conti bancari con saldo disponibile. Aggiungi almeno un conto, ad esempio “Conto principale”, “Revolut” o “Postepay”, così posso considerare anche i soldi già presenti in banca.';
      }

      if (availableBudget < 0 && availableBudgetWithBank >= 0) {
        return 'Nei conti registrati hai ${_formatMoneyText(totalBankBalance)}. Questo mese le spese superano le entrate di circa ${_formatMoneyText(availableBudget.abs())}, però la liquidità in banca riesce a coprire la differenza. Dopo le spese previste, il margine stimato considerando la banca è ${_formatMoneyText(availableBudgetWithBank)}. Ti consiglio comunque di fare attenzione, perché stai usando soldi già disponibili e non margine generato dal mese.';
      }

      if (availableBudgetWithBank < 0) {
        return 'Nei conti registrati hai ${_formatMoneyText(totalBankBalance)}, ma considerando tutte le spese del mese il margine stimato resta negativo: ${_formatMoneyText(availableBudgetWithBank)}. Meglio non fare nuove spese extra.';
      }

      return 'Nei conti registrati hai ${_formatMoneyText(totalBankBalance)}. Considerando le spese del mese, il margine stimato con la banca è ${_formatMoneyText(availableBudgetWithBank)}.';
    }

    if (askedAboutDailyBudget) {
      final daily = dailyAvailable > 0 ? dailyAvailable : dailyAvailableWithBank;

      if (daily <= 0) {
        return 'Al momento non hai un margine giornaliero positivo. Per arrivare meglio a fine mese, ti consiglierei di evitare spese extra e controllare prima quelle ancora da pagare.';
      }

      if (daily < 10) {
        return '${personalizedOpening}Puoi considerare circa ${_formatMoneyText(daily)} al giorno, ma è un margine basso. Ti consiglio di usarlo solo per spese davvero necessarie.$personalizedClosing';
      }

      return '${personalizedOpening}Per il resto del mese puoi considerare circa ${_formatMoneyText(daily)} al giorno. Cerca comunque di non usarlo tutto, così mantieni un margine per imprevisti.$personalizedClosing';
    }

    if (askedAboutAffordability) {
      final realSpendableBudget =
          spendableBudget > 0 ? spendableBudget : spendableBudgetWithBank;

      if (amountInQuestion != null && amountInQuestion > 0) {
        final remainingAfterPurchase = availableBudgetWithBank - amountInQuestion;
        final remainingAfterSafety = remainingAfterPurchase - safetyBuffer;

        if (remainingAfterPurchase < 0) {
          return 'Guardando i tuoi dati, non te lo consiglio. Considerando anche i soldi in banca hai un margine stimato di ${_formatMoneyText(availableBudgetWithBank)}, ma questa spesa sarebbe di ${_formatMoneyText(amountInQuestion)}. Andresti sotto di circa ${_formatMoneyText(remainingAfterPurchase.abs())}.';
        }

        if (availableBudget < 0 && availableBudgetWithBank >= 0) {
          return 'Puoi coprirla solo usando i soldi già presenti in banca. Le entrate del mese non bastano, perché il budget mensile è negativo di circa ${_formatMoneyText(availableBudget.abs())}. Dopo una spesa da ${_formatMoneyText(amountInQuestion)}, considerando la banca, ti resterebbero circa ${_formatMoneyText(remainingAfterPurchase)}. Io lo farei solo se è una spesa importante.';
        }

        if (remainingAfterSafety < 0) {
          return 'Tecnicamente puoi farlo, perché considerando anche la banca hai ${_formatMoneyText(availableBudgetWithBank)} disponibili. Però dopo una spesa da ${_formatMoneyText(amountInQuestion)} ti resterebbero ${_formatMoneyText(remainingAfterPurchase)}, andando sotto il margine di sicurezza consigliato di ${_formatMoneyText(safetyBuffer)}. Io ti direi: fallo solo se è davvero necessario.';
        }

        return '${personalizedOpening}Sì, puoi permettertelo. Considerando anche i soldi in banca hai ${_formatMoneyText(availableBudgetWithBank)} disponibili e dopo una spesa da ${_formatMoneyText(amountInQuestion)} ti resterebbero circa ${_formatMoneyText(remainingAfterPurchase)}. Se vuoi essere prudente, evita comunque di fare troppe spese simili nello stesso mese.$personalizedClosing';
      }

      if (realSpendableBudget <= 0) {
        return 'In questo momento non ti consiglio nuove spese extra. Considerando entrate, spese e banca, il margine realmente spendibile è basso perché sarebbe meglio tenere circa ${_formatMoneyText(safetyBuffer)} come sicurezza.';
      }

      return '${personalizedOpening}In questo momento puoi spendere circa ${_formatMoneyText(realSpendableBudget)} senza intaccare troppo il margine di sicurezza. Questa stima considera anche i soldi presenti in banca.$personalizedClosing';
    }

    if (askedAboutSaving || askedAboutGoals) {
      final answer = _goalAdviceText(
        mainGoal: mainGoal is Map<String, dynamic> ? mainGoal : null,
        spendableBudget: spendableBudget,
        spendableBudgetWithBank: spendableBudgetWithBank,
      );

      return '$personalizedOpening$answer$personalizedClosing';
    }

    if (askedAboutExpenses) {
      final answer = _expenseControlAdvice(
        monthlyIncome: monthlyIncome,
        totalExpenses: totalExpenses,
        previousTotalExpenses: previousTotalExpenses,
        topCategoryName: topCategoryName,
        topCategoryAmount: topCategoryAmount,
      );

      return '$personalizedOpening$answer$personalizedClosing';
    }

    if (askedAboutDanger) {
      if (availableBudgetWithBank < 0) {
        return 'Per migliorare la situazione ti consiglio di fare 3 cose subito: blocca le spese extra, controlla le spese non ancora pagate e prova a rimandare quelle non urgenti. Anche considerando la banca, il margine stimato è negativo di ${_formatMoneyText(availableBudgetWithBank.abs())}, quindi ora la priorità è ridurre le uscite.';
      }

      if (availableBudget < 0 && availableBudgetWithBank >= 0) {
        return 'Puoi migliorare così: prima controlla le spese non pagate, poi evita nuovi acquisti non necessari e usa i soldi in banca solo per coprire le uscite importanti. Le spese superano le entrate di circa ${_formatMoneyText(availableBudget.abs())}, quindi il mese non sta generando margine positivo.';
      }

      if (availableBudget <= safetyBuffer && safetyBuffer > 0) {
        return 'La situazione non è critica, però sei vicino al margine di sicurezza. Ti consiglio di rallentare con le spese extra, dare priorità alle scadenze e rimandare gli acquisti non urgenti fino al prossimo mese.';
      }

      if (topCategoryName.isNotEmpty && topCategoryAmount > 0) {
        return 'Puoi migliorare partendo dalla categoria più pesante: "$topCategoryName", dove hai speso circa ${_formatMoneyText(topCategoryAmount)}. Prova a ridurla del 20%: potresti recuperare circa ${_formatMoneyText(topCategoryAmount * 0.20)}. In più, mantieni almeno ${_formatMoneyText(safetyBuffer)} come margine di sicurezza.';
      }

      return 'La situazione non sembra grave. Per migliorarla ancora, prova a mettere da parte una piccola quota del budget disponibile, evita spese impulsive e controlla ogni settimana le categorie più alte.';
    }

    if (askedAboutSituation) {
      final buffer = StringBuffer();

      buffer.write(
        'La tua situazione attuale è "$mood". Hai entrate per ${_formatMoneyText(monthlyIncome)}, spese già pagate per ${_formatMoneyText(paidExpenses)}, spese ancora da pagare per ${_formatMoneyText(unpaidExpenses)} e spese pianificate per ${_formatMoneyText(plannedExpenses)}. ',
      );

      if (availableBudget < 0 && availableBudgetWithBank >= 0) {
        buffer.write(
          'Il budget mensile è negativo di ${_formatMoneyText(availableBudget.abs())}, però hai ${_formatMoneyText(totalBankBalance)} in banca: quindi puoi coprire la differenza, ma stai usando liquidità già disponibile. ',
        );
      } else if (availableBudgetWithBank < 0) {
        buffer.write(
          'Anche considerando la banca, il margine stimato è negativo. Ti consiglio di bloccare le spese extra. ',
        );
      } else {
        buffer.write(
          'Il budget disponibile del mese è ${_formatMoneyText(availableBudget)}, mentre considerando anche la banca il margine stimato è ${_formatMoneyText(availableBudgetWithBank)}. ',
        );
      }

      if (topCategoryName.isNotEmpty && topCategoryAmount > 0) {
        buffer.write(
          'La categoria più pesante è "$topCategoryName" con ${_formatMoneyText(topCategoryAmount)}. ',
        );
      }

      if (score is int) {
        buffer.write('Il punteggio AI è $score/100.');
      }

      return buffer.toString();
    }

    final daily = dailyAvailableWithBank > 0 ? dailyAvailableWithBank : dailyAvailable;

    return '${personalizedOpening}Guardando la tua situazione, hai ${_formatMoneyText(monthlyIncome)} di entrate e ${_formatMoneyText(totalExpenses)} di uscite totali previste questo mese. Nei conti registrati hai ${_formatMoneyText(totalBankBalance)}. Il budget mensile stimato è ${_formatMoneyText(availableBudget)}, mentre considerando anche la banca il margine stimato è ${_formatMoneyText(availableBudgetWithBank)}. Il tuo stato è "$mood"${score is int ? ' con un punteggio di $score/100' : ''}. Puoi usare circa ${_formatMoneyText(daily)} al giorno per il resto del mese, mantenendo prudenza.$personalizedClosing';
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
      } else if (value is List) {
        cleaned[entry.key] = value.map((item) {
          if (item is Map) {
            return item.map(
              (key, mapValue) => MapEntry(
                key.toString(),
                mapValue is Timestamp
                    ? mapValue.toDate().toIso8601String()
                    : mapValue,
              ),
            );
          }

          return item;
        }).toList();
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