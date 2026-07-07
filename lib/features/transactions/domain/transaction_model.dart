import 'package:flutter/foundation.dart';

enum TransactionType { expense, income }

enum PaymentMethod {
  cash,
  upi,
  creditCard,
  debitCard,
  wallet,
  bankTransfer;

  String get displayName {
    switch (this) {
      case PaymentMethod.cash: return 'Cash';
      case PaymentMethod.upi: return 'UPI';
      case PaymentMethod.creditCard: return 'Credit Card';
      case PaymentMethod.debitCard: return 'Debit Card';
      case PaymentMethod.wallet: return 'Wallet';
      case PaymentMethod.bankTransfer: return 'Bank Transfer';
    }
  }
}

class TransactionModel {
  final String id;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String notes;
  final String? receiptUrl;
  final PaymentMethod paymentMethod;
  final List<String> tags;
  final String? location;
  final String? merchantName;
  final bool isSynced;
  final DateTime updatedAt;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.notes = '',
    this.receiptUrl,
    required this.paymentMethod,
    this.tags = const [],
    this.location,
    this.merchantName,
    this.isSynced = false,
    required this.updatedAt,
  });

  TransactionModel copyWith({
    String? id,
    double? amount,
    TransactionType? type,
    String? category,
    DateTime? date,
    String? notes,
    String? receiptUrl,
    PaymentMethod? paymentMethod,
    List<String>? tags,
    String? location,
    String? merchantName,
    bool? isSynced,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      tags: tags ?? this.tags,
      location: location ?? this.location,
      merchantName: merchantName ?? this.merchantName,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type.name,
      'category': category,
      'date': date.toIso8601String(),
      'notes': notes,
      'receiptUrl': receiptUrl,
      'paymentMethod': paymentMethod.name,
      'tags': tags,
      'location': location,
      'merchantName': merchantName,
      'isSynced': isSynced,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      category: map['category'] ?? 'Others',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      notes: map['notes'] ?? '',
      receiptUrl: map['receiptUrl'],
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == map['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
      tags: List<String>.from(map['tags'] ?? []),
      location: map['location'],
      merchantName: map['merchantName'],
      isSynced: map['isSynced'] ?? false,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
    );
  }
}
