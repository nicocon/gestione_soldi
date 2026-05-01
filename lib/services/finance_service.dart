import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FinanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
  }

  Future<void> deleteIncome({
    required String incomeId,
  }) async {
    await incomesRef.doc(incomeId).delete();
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
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
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
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateExpensePaid({
    required String expenseId,
    required bool isPaid,
  }) async {
    await expensesRef.doc(expenseId).update({
      'is_paid': isPaid,
      'updated_at': FieldValue.serverTimestamp(),
    });
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
  }

  Future<void> deleteExpense({
    required String expenseId,
  }) async {
    await expensesRef.doc(expenseId).delete();
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
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0;
  }
}