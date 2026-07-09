import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_database/firebase_database.dart';
import '../domain/transaction_model.dart';
import '../../../core/services/hive_service.dart';
import '../../auth/data/auth_repository.dart';

abstract class TransactionRepository {
  Future<List<TransactionModel>> getTransactions();
  Future<void> saveTransaction(TransactionModel transaction);
  Future<void> deleteTransaction(String id);
  Future<void> syncPendingTransactions();
  Future<void> seedMockData();
}

class TransactionRepositoryImpl implements TransactionRepository {
  final _uuid = const Uuid();

  FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://trac-4c25b-default-rtdb.firebaseio.com/',
      );

  @override
  Future<List<TransactionModel>> getTransactions() async {
    final rawItems = HiveService.getAllItems(HiveService.expensesBoxName);
    return rawItems.map((e) => TransactionModel.fromMap(e)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> saveTransaction(TransactionModel transaction) async {
    final boxName = HiveService.expensesBoxName;
    final map = transaction.toMap();
    await HiveService.saveItem(boxName, transaction.id, map);
    
    final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _db
          .ref('users/$uid/transactions/${transaction.id}')
          .set(map)
          .timeout(const Duration(seconds: 2))
          .catchError((e) {
        print("Realtime Database save transaction error: $e");
        return null;
      });
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final boxName = HiveService.expensesBoxName;
    await HiveService.deleteItem(boxName, id);
    
    final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _db
          .ref('users/$uid/transactions/$id')
          .remove()
          .timeout(const Duration(seconds: 2))
          .catchError((e) {
        print("Realtime Database delete transaction error: $e");
        return null;
      });
    }
  }

  @override
  Future<void> syncPendingTransactions() async {
    final transactions = await getTransactions();
    final unsynced = transactions.where((t) => !t.isSynced).toList();
    
    for (var tx in unsynced) {
      await Future.delayed(const Duration(milliseconds: 200)); // Simulate networking
      final syncedTx = tx.copyWith(isSynced: true);
      await HiveService.saveItem(HiveService.expensesBoxName, syncedTx.id, syncedTx.toMap());
    }
  }

  Future<void> _simulateFirestoreSync(TransactionModel tx) async {
    await Future.delayed(const Duration(seconds: 2));
    final syncedTx = tx.copyWith(isSynced: true);
    await HiveService.saveItem(HiveService.expensesBoxName, syncedTx.id, syncedTx.toMap());
  }

  @override
  Future<void> seedMockData() async {
    final now = DateTime.now();
    final mockTxs = [
      // Current Month Expenses
      TransactionModel(
        id: _uuid.v4(),
        amount: 15000.0,
        type: TransactionType.expense,
        category: 'Rent',
        date: DateTime(now.year, now.month, 1),
        notes: 'Monthly apartment rent',
        paymentMethod: PaymentMethod.bankTransfer,
        isSynced: true,
        updatedAt: now,
      ),
      TransactionModel(
        id: _uuid.v4(),
        amount: 3200.0,
        type: TransactionType.expense,
        category: 'Grocery',
        date: now.subtract(const Duration(days: 1)),
        notes: 'Whole Foods organic supplies',
        merchantName: 'Whole Foods Market',
        paymentMethod: PaymentMethod.creditCard,
        isSynced: true,
        updatedAt: now,
      ),
      TransactionModel(
        id: _uuid.v4(),
        amount: 850.0,
        type: TransactionType.expense,
        category: 'Food',
        date: now.subtract(const Duration(days: 2)),
        notes: 'Dinner at Starbucks',
        merchantName: 'Starbucks Coffee',
        paymentMethod: PaymentMethod.upi,
        isSynced: true,
        updatedAt: now,
      ),
      TransactionModel(
        id: _uuid.v4(),
        amount: 2500.0,
        type: TransactionType.expense,
        category: 'Fuel',
        date: now.subtract(const Duration(days: 3)),
        notes: 'Full tank gas',
        merchantName: 'Shell Petrol Station',
        paymentMethod: PaymentMethod.creditCard,
        isSynced: true,
        updatedAt: now,
      ),
      TransactionModel(
        id: _uuid.v4(),
        amount: 999.0,
        type: TransactionType.expense,
        category: 'Entertainment',
        date: now.subtract(const Duration(days: 4)),
        notes: 'Netflix Premium Annual',
        merchantName: 'Netflix Inc',
        paymentMethod: PaymentMethod.wallet,
        isSynced: true,
        updatedAt: now,
      ),
      TransactionModel(
        id: _uuid.v4(),
        amount: 4500.0,
        type: TransactionType.expense,
        category: 'Shopping',
        date: now.subtract(const Duration(days: 5)),
        notes: 'Running shoes from Nike',
        merchantName: 'Nike Store',
        paymentMethod: PaymentMethod.creditCard,
        isSynced: true,
        updatedAt: now,
      ),
      TransactionModel(
        id: _uuid.v4(),
        amount: 1200.0,
        type: TransactionType.expense,
        category: 'Medical',
        date: now.subtract(const Duration(days: 6)),
        notes: 'Vitamins & Painkillers',
        merchantName: 'CVS Pharmacy',
        paymentMethod: PaymentMethod.debitCard,
        isSynced: true,
        updatedAt: now,
      ),
      TransactionModel(
        id: _uuid.v4(),
        amount: 350.0,
        type: TransactionType.expense,
        category: 'Others',
        date: now.subtract(const Duration(days: 7)),
        notes: 'Tea and snacks',
        paymentMethod: PaymentMethod.cash,
        isSynced: true,
        updatedAt: now,
      ),
      
      // Incomes
      TransactionModel(
        id: _uuid.v4(),
        amount: 85000.0,
        type: TransactionType.income,
        category: 'Salary',
        date: DateTime(now.year, now.month, 1),
        notes: 'Monthly corporate salary payout',
        paymentMethod: PaymentMethod.bankTransfer,
        isSynced: true,
        updatedAt: now,
      ),
      TransactionModel(
        id: _uuid.v4(),
        amount: 15000.0,
        type: TransactionType.income,
        category: 'Freelancing',
        date: now.subtract(const Duration(days: 4)),
        notes: 'Mobile app UI redesign milestone',
        paymentMethod: PaymentMethod.bankTransfer,
        isSynced: true,
        updatedAt: now,
      ),
      TransactionModel(
        id: _uuid.v4(),
        amount: 5000.0,
        type: TransactionType.income,
        category: 'Investments',
        date: now.subtract(const Duration(days: 10)),
        notes: 'Stock dividends',
        paymentMethod: PaymentMethod.bankTransfer,
        isSynced: true,
        updatedAt: now,
      ),
    ];

    for (var tx in mockTxs) {
      await HiveService.saveItem(HiveService.expensesBoxName, tx.id, tx.toMap());
    }
  }
}

// Provider
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositoryImpl();
});

// A StateNotifierProvider to manage transaction state in the UI
class TransactionNotifier extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  final TransactionRepository _repo;

  TransactionNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getTransactions();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addTransaction(TransactionModel tx) async {
    try {
      await _repo.saveTransaction(tx);
      await loadTransactions();
    } catch (_) {}
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await _repo.deleteTransaction(id);
      await loadTransactions();
    } catch (_) {}
  }
}

final transactionListProvider = StateNotifierProvider<TransactionNotifier, AsyncValue<List<TransactionModel>>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  ref.watch(currentUserProvider);
  return TransactionNotifier(repo);
});
