import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../app/config/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../domain/transaction_model.dart';
import '../data/transaction_repository.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final String? transactionId;

  const AddTransactionScreen({super.key, this.transactionId});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagController = TextEditingController();
  final _merchantController = TextEditingController();
  final _locationController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String _category = 'Food';
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  DateTime _date = DateTime.now();
  final List<String> _tags = [];

  final List<String> _expenseCategories = [
    'Food', 'Grocery', 'Shopping', 'Medical', 'Fuel', 'Entertainment',
    'Bills', 'Education', 'Travel', 'Rent', 'EMI', 'Investment', 'Others'
  ];

  final List<String> _incomeCategories = [
    'Salary', 'Freelancing', 'Business', 'Gifts', 'Bonus', 'Investments', 'Other Income'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.transactionId != null) {
      _loadTransactionData();
    }
  }

  void _loadTransactionData() {
    final listState = ref.read(transactionListProvider);
    listState.whenData((list) {
      final tx = list.firstWhere((t) => t.id == widget.transactionId);
      _amountController.text = tx.amount.toString();
      _notesController.text = tx.notes;
      _merchantController.text = tx.merchantName ?? '';
      _locationController.text = tx.location ?? '';
      _type = tx.type;
      _category = tx.category;
      _paymentMethod = tx.paymentMethod;
      _date = tx.date;
      _tags.addAll(tx.tags);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _tagController.dispose();
    _merchantController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _saveTransaction() {
    if (!_formKey.currentState!.validate()) return;

    final amt = double.tryParse(_amountController.text) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than zero')),
      );
      return;
    }

    final now = DateTime.now();
    final tx = TransactionModel(
      id: widget.transactionId ?? const Uuid().v4(),
      amount: amt,
      type: _type,
      category: _category,
      date: DateTime(_date.year, _date.month, _date.day, now.hour, now.minute),
      notes: _notesController.text.trim(),
      paymentMethod: _paymentMethod,
      tags: _tags,
      location: _locationController.text.isEmpty ? null : _locationController.text.trim(),
      merchantName: _merchantController.text.isEmpty ? null : _merchantController.text.trim(),
      isSynced: false,
      updatedAt: now,
    );

    ref.read(transactionListProvider.notifier).addTransaction(tx);
    context.pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transaction saved successfully!'),
        backgroundColor: AppColors.income,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = _type == TransactionType.expense ? _expenseCategories : _incomeCategories;
    
    // Safety check for category matching when type switches
    if (!categories.contains(_category)) {
      _category = categories.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transactionId == null ? 'Add Transaction' : 'Edit Transaction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppColors.income, size: 28),
            onPressed: _saveTransaction,
          )
        ],
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.darkBackground, const Color(0xFF101222)]
                : [AppColors.lightBackground, const Color(0xFFEDF2F8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Type selector (Income / Expense toggle)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _type = TransactionType.expense),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: _type == TransactionType.expense 
                                  ? AppColors.expense.withOpacity(0.15) 
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'EXPENSE',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _type == TransactionType.expense ? AppColors.expense : Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _type = TransactionType.income),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: _type == TransactionType.income 
                                  ? AppColors.income.withOpacity(0.15) 
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'INCOME',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _type == TransactionType.income ? AppColors.income : Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Amount Form Box
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AMOUNT (₹)',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          border: InputBorder.none,
                          prefixText: '₹ ',
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Enter amount';
                          if (double.tryParse(val) == null) return 'Enter valid number';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Parameters Form Box
                GlassCard(
                  child: Column(
                    children: [
                      // Category Dropdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.category_outlined, size: 20, color: Colors.grey),
                              SizedBox(width: 12),
                              Text('Category', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                          DropdownButton<String>(
                            value: _category,
                            underline: const SizedBox(),
                            items: categories.map((c) {
                              return DropdownMenuItem<String>(
                                value: c,
                                child: Text(c, style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _category = val);
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Date Picker
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey),
                              SizedBox(width: 12),
                              Text('Date', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _date,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) setState(() => _date = picked);
                            },
                            child: Text(
                              DateFormat('dd MMM, yyyy').format(_date),
                              style: const TextStyle(fontSize: 14, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Payment Method
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.payment_outlined, size: 20, color: Colors.grey),
                              SizedBox(width: 12),
                              Text('Payment Mode', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                          DropdownButton<PaymentMethod>(
                            value: _paymentMethod,
                            underline: const SizedBox(),
                            items: PaymentMethod.values.map((method) {
                              return DropdownMenuItem<PaymentMethod>(
                                value: method,
                                child: Text(method.displayName, style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _paymentMethod = val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Details (Merchant, Location, Notes, Tags)
                GlassCard(
                  child: Column(
                    children: [
                      // Merchant
                      TextFormField(
                        controller: _merchantController,
                        decoration: const InputDecoration(
                          labelText: 'Merchant Name',
                          prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                          border: InputBorder.none,
                        ),
                      ),
                      const Divider(height: 1),
                      // Location
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location / Address',
                          prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                          border: InputBorder.none,
                        ),
                      ),
                      const Divider(height: 1),
                      // Notes
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          prefixIcon: Icon(Icons.sticky_note_2_outlined, size: 20),
                          border: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tags Card
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TAGS',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ..._tags.map((t) => Chip(
                                label: Text(t, style: const TextStyle(fontSize: 11)),
                                deleteIcon: const Icon(Icons.close, size: 12),
                                onDeleted: () => setState(() => _tags.remove(t)),
                              )),
                          ActionChip(
                            label: const Text('+ Add Tag', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                            onPressed: () {
                              _showAddTagDialog();
                            },
                          )
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                CustomButton(
                  text: widget.transactionId == null ? 'Save Transaction' : 'Update Transaction',
                  onTap: _saveTransaction,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddTagDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: _tagController,
          decoration: const InputDecoration(labelText: 'Tag Label'),
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final text = _tagController.text.trim();
              if (text.isNotEmpty && !_tags.contains(text)) {
                setState(() => _tags.add(text));
                _tagController.clear();
                context.pop();
              }
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }
}
