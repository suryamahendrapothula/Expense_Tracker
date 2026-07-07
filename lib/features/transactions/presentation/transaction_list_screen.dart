import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/config/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../domain/transaction_model.dart';
import '../data/transaction_repository.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  
  TransactionType? _typeFilter; // null means All
  String _categoryFilter = 'All';
  PaymentMethod? _paymentMethodFilter;
  String _sortBy = 'Date (Newest)';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(transactionListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: _showFiltersBottomSheet,
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.darkBackground, const Color(0xFF101222)]
                : [AppColors.lightBackground, const Color(0xFFEDF2F8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Search Field
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      hintText: 'Search merchant, notes, tags...',
                      border: InputBorder.none,
                      icon: Icon(Icons.search_rounded, color: Colors.grey),
                    ),
                  ),
                ),
              ),

              // Quick Type Filters (All, Expense, Income)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    _QuickFilterChip(
                      label: 'All',
                      isSelected: _typeFilter == null,
                      onTap: () => setState(() => _typeFilter = null),
                    ),
                    const SizedBox(width: 8),
                    _QuickFilterChip(
                      label: 'Expenses',
                      isSelected: _typeFilter == TransactionType.expense,
                      onTap: () => setState(() => _typeFilter = TransactionType.expense),
                    ),
                    const SizedBox(width: 8),
                    _QuickFilterChip(
                      label: 'Income',
                      isSelected: _typeFilter == TransactionType.income,
                      onTap: () => setState(() => _typeFilter = TransactionType.income),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Filter info row if any filters active
              if (_categoryFilter != 'All' || _paymentMethodFilter != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                  child: Row(
                    children: [
                      const Text(
                        'Active Filters: ',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      if (_categoryFilter != 'All')
                        _MiniChip(
                          label: _categoryFilter,
                          onClear: () => setState(() => _categoryFilter = 'All'),
                        ),
                      if (_paymentMethodFilter != null) ...[
                        const SizedBox(width: 6),
                        _MiniChip(
                          label: _paymentMethodFilter!.displayName,
                          onClear: () => setState(() => _paymentMethodFilter = null),
                        ),
                      ]
                    ],
                  ),
                ),

              // Transaction List
              Expanded(
                child: listState.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (transactions) {
                    // Apply filters
                    var filtered = transactions.where((tx) {
                      // Type filter
                      if (_typeFilter != null && tx.type != _typeFilter) return false;
                      
                      // Category filter
                      if (_categoryFilter != 'All' && tx.category != _categoryFilter) return false;

                      // Payment Method filter
                      if (_paymentMethodFilter != null && tx.paymentMethod != _paymentMethodFilter) return false;

                      // Search Query
                      if (_searchQuery.isNotEmpty) {
                        final query = _searchQuery.toLowerCase();
                        final merchant = tx.merchantName?.toLowerCase() ?? '';
                        final notes = tx.notes.toLowerCase();
                        final tagsMatch = tx.tags.any((t) => t.toLowerCase().contains(query));
                        if (!merchant.contains(query) && !notes.contains(query) && !tagsMatch) return false;
                      }

                      return true;
                    }).toList();

                    // Apply Sorting
                    if (_sortBy == 'Date (Newest)') {
                      filtered.sort((a, b) => b.date.compareTo(a.date));
                    } else if (_sortBy == 'Date (Oldest)') {
                      filtered.sort((a, b) => a.date.compareTo(b.date));
                    } else if (_sortBy == 'Amount (Highest)') {
                      filtered.sort((a, b) => b.amount.compareTo(a.amount));
                    } else if (_sortBy == 'Amount (Lowest)') {
                      filtered.sort((a, b) => a.amount.compareTo(b.amount));
                    }

                    if (filtered.isEmpty) {
                      return const Center(child: Text('No transactions found matching filters.'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final tx = filtered[index];
                        return _TransactionListItem(transaction: tx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Filter & Sort History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  
                  // Category Filter Dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Category', style: TextStyle(fontSize: 14)),
                      DropdownButton<String>(
                        value: _categoryFilter,
                        items: ['All', 'Food', 'Grocery', 'Shopping', 'Salary', 'Freelancing', 'Rent', 'Fuel', 'Entertainment', 'Others']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => _categoryFilter = val);
                            setState(() => _categoryFilter = val);
                          }
                        },
                      )
                    ],
                  ),
                  const Divider(),

                  // Payment Method Dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Method', style: TextStyle(fontSize: 14)),
                      DropdownButton<PaymentMethod?>(
                        value: _paymentMethodFilter,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Mode', style: TextStyle(fontSize: 14))),
                          ...PaymentMethod.values.map((e) => DropdownMenuItem(value: e, child: Text(e.displayName, style: const TextStyle(fontSize: 14)))),
                        ],
                        onChanged: (val) {
                          setModalState(() => _paymentMethodFilter = val);
                          setState(() => _paymentMethodFilter = val);
                        },
                      )
                    ],
                  ),
                  const Divider(),

                  // Sort By Dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sort By', style: TextStyle(fontSize: 14)),
                      DropdownButton<String>(
                        value: _sortBy,
                        items: ['Date (Newest)', 'Date (Oldest)', 'Amount (Highest)', 'Amount (Lowest)']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => _sortBy = val);
                            setState(() => _sortBy = val);
                          }
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 30),
                  
                  // Reset Button
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _categoryFilter = 'All';
                        _paymentMethodFilter = null;
                        _sortBy = 'Date (Newest)';
                      });
                      context.pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.expense.withOpacity(0.1),
                      foregroundColor: AppColors.expense,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Reset All Filters'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickFilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _MiniChip({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 2, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close, size: 12, color: AppColors.primary),
          )
        ],
      ),
    );
  }
}

class _TransactionListItem extends ConsumerWidget {
  final TransactionModel transaction;

  const _TransactionListItem({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpense = transaction.type == TransactionType.expense;

    IconData catIcon;
    Color catColor;
    switch (transaction.category) {
      case 'Food':
        catIcon = Icons.fastfood_outlined;
        catColor = Colors.orange;
        break;
      case 'Grocery':
        catIcon = Icons.shopping_basket_outlined;
        catColor = Colors.green;
        break;
      case 'Shopping':
        catIcon = Icons.shopping_bag_outlined;
        catColor = Colors.purple;
        break;
      case 'Fuel':
        catIcon = Icons.local_gas_station_outlined;
        catColor = Colors.blue;
        break;
      case 'Rent':
        catIcon = Icons.home_outlined;
        catColor = Colors.deepOrange;
        break;
      case 'Salary':
        catIcon = Icons.monetization_on_outlined;
        catColor = Colors.teal;
        break;
      case 'Freelancing':
        catIcon = Icons.laptop_mac_outlined;
        catColor = Colors.indigo;
        break;
      default:
        catIcon = Icons.account_balance_wallet_outlined;
        catColor = Colors.grey;
    }

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.expense.withOpacity(0.8),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (_) {
        ref.read(transactionListProvider.notifier).deleteTransaction(transaction.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted')),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => context.push('/add-transaction?id=${transaction.id}'),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(catIcon, color: catColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.merchantName ?? transaction.notes.split('\n').first,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy').format(transaction.date),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black12,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                transaction.paymentMethod.displayName,
                                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isExpense ? "-" : "+"}₹${transaction.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isExpense ? AppColors.expense : AppColors.income,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      transaction.isSynced ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                      size: 12,
                      color: transaction.isSynced ? AppColors.income : AppColors.warning,
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
