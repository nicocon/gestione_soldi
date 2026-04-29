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
    return expensesRef.orderBy('due_date', descending: false).snapshots();
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
    });
  }

  Future<void> addExpense({
    required String title,
    required double amount,
    required DateTime dueDate,
    required String category,
    required bool isPaid,
    required bool reminderEnabled,
  }) async {
    await expensesRef.add({
      'title': title.trim(),
      'amount': amount,
      'due_date': Timestamp.fromDate(dueDate),
      'category': category.trim(),
      'is_paid': isPaid,
      'reminder_enabled': reminderEnabled,
      'created_at': FieldValue.serverTimestamp(),
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
    });
  }
}