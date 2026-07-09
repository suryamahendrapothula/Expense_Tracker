import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_database/firebase_database.dart';
import 'goal_model.dart';
import '../../../core/services/hive_service.dart';
import '../../auth/data/auth_repository.dart';

abstract class GoalRepository {
  Future<List<GoalModel>> getGoals();
  Future<void> saveGoal(GoalModel goal);
  Future<void> addFundsToGoal(String id, double amount);
  Future<void> deleteGoal(String id);
  Future<void> seedMockGoals();
}

class GoalRepositoryImpl implements GoalRepository {
  final _uuid = const Uuid();

  FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://trac-4c25b-default-rtdb.firebaseio.com/',
      );

  @override
  Future<List<GoalModel>> getGoals() async {
    final rawItems = HiveService.getAllItems(HiveService.goalsBoxName);
    return rawItems.map((e) => GoalModel.fromMap(e)).toList();
  }

  @override
  Future<void> saveGoal(GoalModel goal) async {
    await HiveService.saveItem(HiveService.goalsBoxName, goal.id, goal.toMap());
    
    final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _db
          .ref('users/$uid/goals/${goal.id}')
          .set(goal.toMap())
          .timeout(const Duration(seconds: 2))
          .catchError((e) {
        print("Realtime Database save goal error: $e");
        return null;
      });
    }
  }

  @override
  Future<void> addFundsToGoal(String id, double amount) async {
    final raw = HiveService.getBox(HiveService.goalsBoxName).get(id);
    if (raw != null) {
      final goal = GoalModel.fromMap(Map<String, dynamic>.from(raw));
      final newAmount = goal.currentAmount + amount;
      final completed = newAmount >= goal.targetAmount;
      final updated = goal.copyWith(
        currentAmount: newAmount,
        isCompleted: completed,
      );
      await saveGoal(updated);
    }
  }

  @override
  Future<void> deleteGoal(String id) async {
    await HiveService.deleteItem(HiveService.goalsBoxName, id);
    
    final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _db
          .ref('users/$uid/goals/$id')
          .remove()
          .timeout(const Duration(seconds: 2))
          .catchError((e) {
        print("Realtime Database delete goal error: $e");
        return null;
      });
    }
  }

  @override
  Future<void> seedMockGoals() async {
    final now = DateTime.now();
    final mockGoals = [
      GoalModel(
        id: _uuid.v4(),
        name: 'MacBook Pro M3 Max',
        targetAmount: 250000.0,
        currentAmount: 180000.0,
        imageUrl: 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?auto=format&fit=crop&w=400&q=80',
        targetDate: now.add(const Duration(days: 90)),
        createdAt: now,
      ),
      GoalModel(
        id: _uuid.v4(),
        name: 'Trip to Bali',
        targetAmount: 120000.0,
        currentAmount: 45000.0,
        imageUrl: 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=400&q=80',
        targetDate: now.add(const Duration(days: 180)),
        createdAt: now,
      ),
      GoalModel(
        id: _uuid.v4(),
        name: 'Emergency Fund',
        targetAmount: 300000.0,
        currentAmount: 150000.0,
        imageUrl: 'https://images.unsplash.com/photo-1579621970563-ebec7560ff3e?auto=format&fit=crop&w=400&q=80',
        targetDate: now.add(const Duration(days: 365)),
        createdAt: now,
      ),
    ];

    for (var g in mockGoals) {
      await HiveService.saveItem(HiveService.goalsBoxName, g.id, g.toMap());
    }
  }
}

// Provider
final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepositoryImpl();
});

class GoalNotifier extends StateNotifier<AsyncValue<List<GoalModel>>> {
  final GoalRepository _repo;

  GoalNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadGoals();
  }

  Future<void> loadGoals() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getGoals();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addGoal(GoalModel goal) async {
    try {
      await _repo.saveGoal(goal);
      await loadGoals();
    } catch (_) {}
  }

  Future<void> addFunds(String id, double amount) async {
    try {
      await _repo.addFundsToGoal(id, amount);
      await loadGoals();
    } catch (_) {}
  }

  Future<void> deleteGoal(String id) async {
    try {
      await _repo.deleteGoal(id);
      await loadGoals();
    } catch (_) {}
  }
}

final goalListProvider = StateNotifierProvider<GoalNotifier, AsyncValue<List<GoalModel>>>((ref) {
  final repo = ref.watch(goalRepositoryProvider);
  ref.watch(currentUserProvider);
  return GoalNotifier(repo);
});
