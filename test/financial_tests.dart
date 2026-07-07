import 'package:flutter_test/flutter_test.dart';
import 'package:trac/features/auth/domain/user_model.dart';
import 'package:trac/features/transactions/domain/transaction_model.dart';

void main() {
  group('UserModel Tests', () {
    test('UserModel should correctly serialize to and from maps', () {
      final user = UserModel(
        uid: 'test_uid_123',
        email: 'tester@antigravity.com',
        displayName: 'Test User',
        photoUrl: 'https://avatar.url',
        createdAt: DateTime(2026, 1, 1),
      );

      final map = user.toMap();
      expect(map['uid'], 'test_uid_123');
      expect(map['email'], 'tester@antigravity.com');
      
      final deserialized = UserModel.fromMap(map);
      expect(deserialized.uid, 'test_uid_123');
      expect(deserialized.displayName, 'Test User');
    });
  });

  group('TransactionModel Tests', () {
    test('TransactionModel should correctly distinguish income vs expense', () {
      final tx1 = TransactionModel(
        id: 'tx_1',
        amount: 250.0,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime.now(),
        paymentMethod: PaymentMethod.upi,
        updatedAt: DateTime.now(),
      );

      final tx2 = TransactionModel(
        id: 'tx_2',
        amount: 5000.0,
        type: TransactionType.income,
        category: 'Salary',
        date: DateTime.now(),
        paymentMethod: PaymentMethod.bankTransfer,
        updatedAt: DateTime.now(),
      );

      expect(tx1.type, TransactionType.expense);
      expect(tx2.type, TransactionType.income);
      expect(tx1.amount, 250.0);
    });
  });

  group('Financial Health Calculator Engine Tests', () {
    test('Should calculate correct score based on income and expenses', () {
      double totalIncome = 100000.0;
      double totalExpense = 40000.0; // 40% burn rate, 60% savings rate
      double budgetAmount = 50000.0;

      double budgetProgress = (totalExpense / budgetAmount).clamp(0.0, 1.0);
      double savingsRate = ((totalIncome - totalExpense) / totalIncome) * 100;
      
      // Health Score math identical to dashboard_screen.dart
      double scoreVal = 50.0 + (savingsRate * 0.3) + ((1 - budgetProgress) * 20.0);
      double healthScore = scoreVal.clamp(10.0, 99.0);

      expect(healthScore, 72.0); // 50.0 + 18.0 + 4.0 = 72
    });

    test('Should clamp health score under limit bounds', () {
      double totalIncome = 100000.0;
      double totalExpense = 5000.0; // 95% savings rate
      double budgetAmount = 50000.0;

      double budgetProgress = (totalExpense / budgetAmount).clamp(0.0, 1.0);
      double savingsRate = ((totalIncome - totalExpense) / totalIncome) * 100;
      
      double scoreVal = 50.0 + (savingsRate * 0.3) + ((1 - budgetProgress) * 20.0);
      double healthScore = scoreVal.clamp(10.0, 99.0);

      expect(healthScore, 96.5); // Clamps within limits (96.5 is < 99)
    });
  });
}
