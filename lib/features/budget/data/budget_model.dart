class BudgetModel {
  final String id;
  final double amount;
  final String category; // 'All' or specific categories
  final String period; // 'daily', 'weekly', 'monthly'
  final DateTime startDate;
  final DateTime endDate;
  final DateTime updatedAt;

  BudgetModel({
    required this.id,
    required this.amount,
    required this.category,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.updatedAt,
  });

  BudgetModel copyWith({
    String? id,
    double? amount,
    String? category,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? updatedAt,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'period': period,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] ?? 'All',
      period: map['period'] ?? 'monthly',
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']) : DateTime.now(),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
    );
  }
}
