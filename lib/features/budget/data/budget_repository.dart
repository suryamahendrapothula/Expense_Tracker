import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_database/firebase_database.dart';
import 'budget_model.dart';
import '../../../core/services/hive_service.dart';
import '../../auth/data/auth_repository.dart';

abstract class BudgetRepository {
  Future<List<BudgetModel>> getBudgets();
  Future<void> saveBudget(BudgetModel budget);
  Future<void> deleteBudget(String id);
  Future<void> seedMockBudgets();
}

class BudgetRepositoryImpl implements BudgetRepository {
  final _uuid = const Uuid();

  FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://trac-4c25b-default-rtdb.firebaseio.com/',
      );

  @override
  Future<List<BudgetModel>> getBudgets() async {
    final rawItems = HiveService.getAllItems(HiveService.budgetsBoxName);
    return rawItems.map((e) => BudgetModel.fromMap(e)).toList();
  }

  @override
  Future<void> saveBudget(BudgetModel budget) async {
    await HiveService.saveItem(HiveService.budgetsBoxName, budget.id, budget.toMap());
    
    final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _db
          .ref('users/$uid/budgets/${budget.id}')
          .set(budget.toMap())
          .timeout(const Duration(seconds: 2))
          .catchError((e) {
        print("Realtime Database save budget error: $e");
        return null;
      });
    }
  }

  @override
  Future<void> deleteBudget(String id) async {
    await HiveService.deleteItem(HiveService.budgetsBoxName, id);
    
    final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _db
          .ref('users/$uid/budgets/$id')
          .remove()
          .timeout(const Duration(seconds: 2))
          .catchError((e) {
        print("Realtime Database delete budget error: $e");
        return null;
      });
    }
  }

  @override
  Future<void> seedMockBudgets() async {
    final now = DateTime.now();
    final mockBudgets = [
      BudgetModel(
        id: _uuid.v4(),
        amount: 45000.0,
        category: 'All',
        period: 'monthly',
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
        updatedAt: now,
      ),
      BudgetModel(
        id: _uuid.v4(),
        amount: 8000.0,
        category: 'Grocery',
        period: 'monthly',
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
        updatedAt: now,
      ),
      BudgetModel(
        id: _uuid.v4(),
        amount: 5000.0,
        category: 'Food',
        period: 'weekly',
        startDate: now.subtract(const Duration(days: 2)),
        endDate: now.add(const Duration(days: 5)),
        updatedAt: now,
      ),
    ];

    for (var b in mockBudgets) {
      await HiveService.saveItem(HiveService.budgetsBoxName, b.id, b.toMap());
    }
  }
}

// Provider
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepositoryImpl();
});

class BudgetNotifier extends StateNotifier<AsyncValue<List<BudgetModel>>> {
  final BudgetRepository _repo;

  BudgetNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadBudgets();
  }

  Future<void> loadBudgets() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getBudgets();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addBudget(BudgetModel budget) async {
    try {
      await _repo.saveBudget(budget);
      await loadBudgets();
    } catch (_) {}
  }

  Future<void> deleteBudget(String id) async {
    try {
      await _repo.deleteBudget(id);
      await loadBudgets();
    } catch (_) {}
  }
}

final budgetListProvider = StateNotifierProvider<BudgetNotifier, AsyncValue<List<BudgetModel>>>((ref) {
  final repo = ref.watch(budgetRepositoryProvider);
  ref.watch(currentUserProvider);
  return BudgetNotifier(repo);
});
