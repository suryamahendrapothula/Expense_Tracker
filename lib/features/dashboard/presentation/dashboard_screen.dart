import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/config/app_theme.dart';
import '../../../app/config/theme_provider.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/health_gauge.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_model.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../budget/data/budget_repository.dart';
import '../../budget/data/budget_model.dart';
import '../../goals/data/goal_repository.dart';
import '../../goals/data/goal_model.dart';
import '../../reports/services/report_generator.dart';
import '../../ai_assistant/presentation/ai_chat_screen.dart';

// ── Dashboard Color Palette (matches reference image) ──
class _DC {
  static const Color bg = Color(0xFFE8EDDF);
  static const Color sidebarBg = Color(0xFF2D6A4F);
  static const Color sidebarBgDark = Color(0xFF1B4332);
  static const Color green = Color(0xFF2D6A4F);
  static const Color greenMid = Color(0xFF40916C);
  static const Color greenLight = Color(0xFF52B788);
  static const Color greenSoft = Color(0xFFD8F3DC);
  static const Color greenPale = Color(0xFFE8F5E9);
  static const Color gold = Color(0xFFD4A843);
  static const Color goldLight = Color(0xFFF0DCA0);
  static const Color goldBar = Color(0xFFE8C84A);
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF1B1B1B);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textFaint = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF0F0F0);
  static const Color redSoft = Color(0xFFFEE2E2);
  static const Color red = Color(0xFFEF4444);
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with TickerProviderStateMixin {
  int _selectedSidebarIndex = 0; // Default to Overview (index 0)
  bool _showBalance = true;
  final TextEditingController _searchController = TextEditingController();
  int _profitTabIndex = 0; // 0=Week, 1=Month, 2=Year

  final List<Map<String, dynamic>> _navigationItems = [
    {'name': 'Overview', 'icon': Icons.space_dashboard_rounded},
    {'name': 'Income', 'icon': Icons.trending_up_rounded},
    {'name': 'Expense', 'icon': Icons.trending_down_rounded},
    {'name': 'Budget', 'icon': Icons.pie_chart_outline_rounded},
    {'name': 'Goal', 'icon': Icons.track_changes_rounded},
    {'name': 'Reports', 'icon': Icons.analytics_outlined},
    {'name': 'AI Chatbot', 'icon': Icons.chat_bubble_outline_rounded},
    {'name': 'Insights', 'icon': Icons.lightbulb_outline_rounded},
    {'name': 'Others', 'icon': Icons.settings_outlined},
  ];

  late AnimationController _sparklineController;
  late Animation<double> _sparklineAnimation;

  @override
  void initState() {
    super.initState();
    _sparklineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _sparklineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sparklineController, curve: Curves.easeInOutSine),
    );
    _sparklineController.forward();
  }

  @override
  void dispose() {
    _sparklineController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════
  // DIALOGS (preserved)
  // ═══════════════════════════════════════════════════════════════════

  void _showAddBudgetDialog() {
    final amountController = TextEditingController();
    String category = 'Grocery';
    final categories = ['All', 'Food', 'Grocery', 'Shopping', 'Medical', 'Fuel', 'Entertainment', 'Rent', 'Others'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Set Category Budget', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: category,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => category = val);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Budget Amount (₹)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _DC.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final amt = double.tryParse(amountController.text) ?? 0.0;
                if (amt > 0) {
                  final budget = BudgetModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    amount: amt,
                    category: category,
                    period: 'monthly',
                    startDate: DateTime.now(),
                    endDate: DateTime.now().add(const Duration(days: 30)),
                    updatedAt: DateTime.now(),
                  );
                  ref.read(budgetListProvider.notifier).addBudget(budget);
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Budget of ₹$amt set for $category!'),
                      backgroundColor: _DC.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  );
                }
              },
              child: const Text('Set Budget'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGoalDialog() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('New Savings Goal', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Goal Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Target Amount (₹)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _DC.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final name = nameController.text.trim();
              final target = double.tryParse(targetController.text) ?? 0.0;
              if (name.isNotEmpty && target > 0) {
                final goal = GoalModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  targetAmount: target,
                  currentAmount: 0.0,
                  targetDate: DateTime.now().add(const Duration(days: 120)),
                  createdAt: DateTime.now(),
                );
                ref.read(goalListProvider.notifier).addGoal(goal);
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Goal "$name" created!'),
                    backgroundColor: _DC.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                );
              }
            },
            child: const Text('Create Goal'),
          ),
        ],
      ),
    );
  }

  void _showFundGoalDialog(GoalModel goal) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Fund "${goal.name}"', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Contribution Amount (₹)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _DC.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final amt = double.tryParse(controller.text) ?? 0.0;
              if (amt > 0) {
                ref.read(goalListProvider.notifier).addFunds(goal.id, amt);
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Contributed ₹$amt successfully!'),
                    backgroundColor: _DC.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                );
              }
            },
            child: const Text('Add Funds'),
          )
        ],
      ),
    );
  }

  void _openQuickActionBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: _DC.border, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    height: 5, width: 50,
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Quick Actions', textAlign: TextAlign.center, style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                _BottomSheetActionTile(
                  icon: Icons.add_rounded, title: 'Manual Entry',
                  subtitle: 'Add income or expense manually',
                  gradient: const [_DC.green, _DC.greenMid],
                  onTap: () { context.pop(); context.push('/add-transaction'); },
                ),
                const SizedBox(height: 14),
                _BottomSheetActionTile(
                  icon: Icons.document_scanner_rounded, title: 'OCR Receipt Scanner',
                  subtitle: 'AI scans physical receipts instantly',
                  gradient: const [Color(0xFF00C2FF), _DC.green],
                  onTap: () { context.pop(); context.push('/scanner'); },
                ),
                const SizedBox(height: 14),
                _BottomSheetActionTile(
                  icon: Icons.mic_rounded, title: 'Voice AI Co-pilot',
                  subtitle: 'Talk to record transactions naturally',
                  gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                  onTap: () { context.pop(); context.push('/ai-chat?voice=true'); },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final txsState = ref.watch(transactionListProvider);
    final budgetsState = ref.watch(budgetListProvider);
    final goalsState = ref.watch(goalListProvider);

    return Scaffold(
      backgroundColor: _DC.bg,
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 950;
          if (isDesktop) return const SizedBox.shrink();
          return _buildBottomNavigation();
        },
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 950;

          return Row(
            children: [
              if (isDesktop) _buildDesktopNavigation(),
              Expanded(
                child: txsState.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: _DC.green)),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data: (transactions) {
                    double totalIncome = 0;
                    double totalExpense = 0;
                    double todayExpense = 0;
                    final today = DateTime.now();

                    for (var tx in transactions) {
                      if (tx.type == TransactionType.income) {
                        totalIncome += tx.amount;
                      } else {
                        totalExpense += tx.amount;
                        if (tx.date.day == today.day && tx.date.month == today.month && tx.date.year == today.year) {
                          todayExpense += tx.amount;
                        }
                      }
                    }

                    double totalBalance = totalIncome - totalExpense;

                    final budgetsList = budgetsState.maybeWhen(
                      data: (list) => list,
                      orElse: () => <BudgetModel>[],
                    );
                    double budgetAmount = budgetsList.isNotEmpty
                        ? budgetsList.firstWhere((b) => b.category == 'All', orElse: () => budgetsList.first).amount
                        : 50000.0;
                    double remainingBudget = (budgetAmount - totalExpense).clamp(0.0, double.infinity);
                    double budgetProgress = budgetAmount > 0 ? (totalExpense / budgetAmount).clamp(0.0, 1.0) : 0.0;

                    double savingsRate = totalIncome > 0 ? ((totalIncome - totalExpense) / totalIncome) * 100 : 0.0;
                    double healthScoreVal = 50.0 + (savingsRate * 0.3) + ((1 - budgetProgress) * 20.0);
                    double healthScore = healthScoreVal.clamp(10.0, 99.0);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(user, isDesktop),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 32.0 : 20.0,
                              vertical: 16.0,
                            ),
                            child: _buildSelectedPanel(
                              transactions: transactions,
                              totalIncome: totalIncome,
                              totalExpense: totalExpense,
                              totalBalance: totalBalance,
                              todayExpense: todayExpense,
                              budgetAmount: budgetAmount,
                              remainingBudget: remainingBudget,
                              budgetProgress: budgetProgress,
                              healthScore: healthScore,
                              budgetsList: budgetsList,
                              goalsState: goalsState,
                              isDesktop: isDesktop,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: PulsingFAB(onPressed: _openQuickActionBottomSheet),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSelectedPanel({
    required List<TransactionModel> transactions,
    required double totalIncome,
    required double totalExpense,
    required double totalBalance,
    required double todayExpense,
    required double remainingBudget,
    required double budgetProgress,
    required double budgetAmount,
    required double healthScore,
    required List<BudgetModel> budgetsList,
    required AsyncValue<List<GoalModel>> goalsState,
    required bool isDesktop,
  }) {
    switch (_selectedSidebarIndex) {
      case 0:
        return _buildDashboardOverview(
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          totalBalance: totalBalance,
          todayExpense: todayExpense,
          remainingBudget: remainingBudget,
          budgetProgress: budgetProgress,
          budgetAmount: budgetAmount,
          healthScore: healthScore,
          goalsState: goalsState,
          isDesktop: isDesktop,
          transactions: transactions,
        );
      case 1:
        return _buildIncomePanel(transactions, false);
      case 2:
        return _buildExpensesPanel(transactions, false);
      case 3:
        return _buildBudgetsPanel(transactions, budgetsList);
      case 4:
        return _buildGoalsPanel(goalsState);
      case 5:
        return _buildReportsPanel(transactions, totalIncome, totalExpense);
      case 6:
        return SizedBox(
          height: 620,
          child: AiChatScreen(showAppBar: false),
        );
      case 7:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAIInsightsPanel(),
            const SizedBox(height: 24),
            _buildAISuggestionsPanel(),
          ],
        );
      case 8:
      default:
        return _buildSettingsPanel();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // COMPACT ICON SIDEBAR (reference image style)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDesktopNavigation() {
    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: _DC.sidebarBg,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 28),
          // Gold diamond logo
          Container(
            height: 44, width: 44,
            decoration: BoxDecoration(
              color: _DC.gold,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _DC.gold.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Center(
              child: Icon(Icons.diamond_outlined, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(height: 36),
          // Nav icons
          Expanded(
            child: Column(
              children: List.generate(_navigationItems.length, (index) {
                final item = _navigationItems[index];
                final isSelected = _selectedSidebarIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Tooltip(
                    message: item['name'],
                    child: InkWell(
                      onTap: () => setState(() => _selectedSidebarIndex = index),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 46, width: 46,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.18) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.45),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // MOBILE BOTTOM NAV (green palette)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildBottomNavigation() {
    final Map<int, Map<String, dynamic>> mobileTabs = {
      0: {'name': 'Overview', 'icon': Icons.space_dashboard_rounded},
      1: {'name': 'Income', 'icon': Icons.trending_up_rounded},
      2: {'name': 'Expense', 'icon': Icons.trending_down_rounded},
      6: {'name': 'Chatbot', 'icon': Icons.chat_bubble_outline_rounded},
      8: {'name': 'Others', 'icon': Icons.settings_outlined},
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        border: const Border(top: BorderSide(color: _DC.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: mobileTabs.entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = _selectedSidebarIndex == index;

            return InkWell(
              onTap: () => setState(() => _selectedSidebarIndex = index),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _DC.greenSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        item['icon'] as IconData,
                        color: isSelected ? _DC.green : _DC.textSecondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['name'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? _DC.green : _DC.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showNotificationsDialog() {
    final alerts = [
      {
        'title': 'Budget Alert',
        'msg': 'Your Food budget is at 78% of its monthly limit.',
        'time': '2 hours ago',
        'icon': Icons.pie_chart_outline_rounded,
        'color': Colors.orange
      },
      {
        'title': 'Transaction Success',
        'msg': 'Successfully recorded ₹1,200 payment to Amazon.',
        'time': '1 day ago',
        'icon': Icons.check_circle_outline_rounded,
        'color': _DC.green
      },
      {
        'title': 'Premium Available',
        'msg': 'Get lifetime access to AI Insights and unlimited budgets.',
        'time': '3 days ago',
        'icon': Icons.workspace_premium_rounded,
        'color': _DC.gold
      },
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active_outlined, color: _DC.green),
            const SizedBox(width: 10),
            Text('Alerts & Notifications',
                style: GoogleFonts.fraunces(
                    fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: alerts.map((alert) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _DC.bg.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _DC.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          (alert['color'] as Color).withOpacity(0.12),
                      child: Icon(alert['icon'] as IconData,
                          size: 16, color: alert['color'] as Color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(alert['title'] as String,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _DC.textPrimary)),
                              Text(alert['time'] as String,
                                  style: GoogleFonts.inter(
                                      fontSize: 9, color: _DC.textFaint)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(alert['msg'] as String,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: _DC.textSecondary,
                                  height: 1.35)),
                        ],
                      ),
                    )
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text('Close',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, color: _DC.textSecondary)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HEADER (reference image style)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHeader(UserModel? user, bool isDesktop) {
    final name = user?.displayName ?? 'Surya';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Container(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 20, isDesktop ? 20 : 12, isDesktop ? 32 : 20, 12,
      ),
      child: Row(
        children: [
          // Gold logo on mobile
          if (!isDesktop) ...[
            Container(
              height: 38, width: 38,
              decoration: BoxDecoration(
                color: _DC.gold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.diamond_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 16),
          ],
          // Search bar
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _DC.border, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 18, color: _DC.textFaint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(fontSize: 13, color: _DC.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search or type command',
                        border: InputBorder.none, isDense: true,
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: _DC.textFaint),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Action icons
          _headerIcon(Icons.settings_outlined, () {
            setState(() => _selectedSidebarIndex = 8);
          }),
          const SizedBox(width: 8),
          _headerIcon(
            Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            () {
              final current = ref.read(themeModeProvider);
              ref.read(themeModeProvider.notifier).setThemeMode(
                current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),
          const SizedBox(width: 8),
          // Notification bell with badge
          Stack(
            children: [
              _headerIcon(Icons.notifications_outlined, _showNotificationsDialog),
              Positioned(
                right: 4, top: 4,
                child: Container(
                  height: 8, width: 8,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: _DC.red),
                ),
              ),
            ],
          ),
          if (isDesktop) ...[
            const SizedBox(width: 16),
            // User name + avatar
            Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _DC.textPrimary)),
            const SizedBox(width: 10),
            Container(
              height: 36, width: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _DC.greenSoft,
                border: Border.all(color: _DC.green.withOpacity(0.3), width: 2),
              ),
              child: Center(
                child: Text(initial, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _DC.green)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 38, width: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _DC.border, width: 1),
        ),
        child: Icon(icon, size: 18, color: _DC.textSecondary),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DASHBOARD OVERVIEW (3-row grid — matches reference image)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDashboardOverview({
    required double totalIncome,
    required double totalExpense,
    required double totalBalance,
    required double todayExpense,
    required double remainingBudget,
    required double budgetProgress,
    required double budgetAmount,
    required double healthScore,
    required AsyncValue<List<GoalModel>> goalsState,
    required bool isDesktop,
    required List<TransactionModel> transactions,
  }) {
    if (isDesktop) {
      return _buildDesktopOverview(totalIncome, totalExpense, totalBalance, transactions, goalsState);
    } else {
      return _buildMobileOverview(totalIncome, totalExpense, totalBalance, transactions, goalsState);
    }
  }

  Widget _buildDesktopOverview(double income, double expense, double balance,
      List<TransactionModel> transactions, AsyncValue<List<GoalModel>> goalsState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ROW 1: My Cards + Profit
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: _buildMyCardsSection(balance, income, expense)),
            const SizedBox(width: 20),
            Expanded(flex: 4, child: _buildProfitChart(transactions)),
          ],
        ),
        const SizedBox(height: 20),
        // ROW 2: Income + Expenses + Spendings
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildIncomeCard(income)),
            const SizedBox(width: 20),
            Expanded(child: _buildExpenseCard(expense)),
            const SizedBox(width: 20),
            Expanded(flex: 2, child: _buildSpendingsBarChart(transactions)),
          ],
        ),
        const SizedBox(height: 20),
        // ROW 3: Planning + Transactions + Premium
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildPlanningSection(goalsState)),
            const SizedBox(width: 20),
            Expanded(child: _buildLatestTransactionsCard(transactions)),
            const SizedBox(width: 20),
            Expanded(child: _buildGoPremiumCard()),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildMobileOverview(double income, double expense, double balance,
      List<TransactionModel> transactions, AsyncValue<List<GoalModel>> goalsState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMyCardsSection(balance, income, expense),
        const SizedBox(height: 20),
        _buildProfitChart(transactions),
        const SizedBox(height: 20),
        _buildIncomeCard(income),
        const SizedBox(height: 16),
        _buildExpenseCard(expense),
        const SizedBox(height: 16),
        _buildSpendingsBarChart(transactions),
        const SizedBox(height: 20),
        _buildPlanningSection(goalsState),
        const SizedBox(height: 20),
        _buildLatestTransactionsCard(transactions),
        const SizedBox(height: 20),
        _buildGoPremiumCard(),
        const SizedBox(height: 30),
      ],
    );
  }

  // ─── My Cards Section ───────────────────────────────────────────

  Widget _buildMyCardsSection(double balance, double income, double expense) {
    final user = ref.watch(currentUserProvider);
    final name = user?.displayName ?? 'Surya';

    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Text('My cards', style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w700, color: _DC.textPrimary)),
              const SizedBox(width: 10),
              Text('Add new', style: GoogleFonts.inter(fontSize: 12, color: _DC.textSecondary)),
              const SizedBox(width: 4),
              Container(
                height: 20, width: 20,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _DC.greenSoft, border: Border.all(color: _DC.green, width: 1.5)),
                child: const Icon(Icons.add, size: 12, color: _DC.green),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Card + Balance + Actions
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCreditCardVisual(name),
                    const SizedBox(width: 24),
                    _buildBalanceAndActions(balance),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCreditCardVisual(name),
                  const SizedBox(height: 20),
                  _buildBalanceAndActions(balance),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCardVisual(String name) {
    return Container(
      width: 220, height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF2D6A4F), Color(0xFF40916C), Color(0xFF52B788)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: _DC.green.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Credit Card', style: GoogleFonts.inter(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600)),
              Text('VISA', style: GoogleFonts.inter(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _cardNumberGroup('1234'), const SizedBox(width: 5),
                _cardNumberGroup('5678'), const SizedBox(width: 5),
                _cardNumberGroup('9101'), const SizedBox(width: 5),
                _cardNumberGroup('1121'),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
              Text('06/23', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardNumberGroup(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: GoogleFonts.inter(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    );
  }

  Widget _buildBalanceAndActions(double balance) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Card balance', style: GoogleFonts.inter(fontSize: 12, color: _DC.textSecondary)),
          const SizedBox(height: 4),
          Text(
            '₹${balance.toStringAsFixed(2)}',
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: _DC.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('View details', style: GoogleFonts.inter(fontSize: 12, color: _DC.green, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Container(
                height: 18, width: 18,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _DC.greenSoft),
                child: const Icon(Icons.arrow_forward, size: 10, color: _DC.green),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('What would you like to do?', style: GoogleFonts.inter(fontSize: 12, color: _DC.textSecondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              _actionCircle(Icons.send_rounded, 'Send', () => context.push('/add-transaction')),
              const SizedBox(width: 20),
              _actionCircle(Icons.call_received_rounded, 'Receive', () => context.push('/add-transaction')),
              const SizedBox(width: 20),
              _actionCircle(Icons.account_balance_wallet_outlined, 'Withdraw', () => context.push('/scanner')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionCircle(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            height: 48, width: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _DC.greenSoft,
              border: Border.all(color: _DC.green.withOpacity(0.2), width: 1),
            ),
            child: Icon(icon, color: _DC.green, size: 20),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: _DC.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ─── Profit Chart ───────────────────────────────────────────────

  Widget _buildProfitChart(List<TransactionModel> transactions) {
    final tabs = ['Week', 'Month', 'Year'];
    // Build simple profit data points
    final Map<int, double> profitData = {};
    for (int i = 0; i < 7; i++) { profitData[i] = 0; }
    for (var tx in transactions) {
      final dayIndex = tx.date.weekday - 1;
      if (dayIndex >= 0 && dayIndex < 7) {
        if (tx.type == TransactionType.income) {
          profitData[dayIndex] = (profitData[dayIndex] ?? 0) + tx.amount;
        } else {
          profitData[dayIndex] = (profitData[dayIndex] ?? 0) - tx.amount;
        }
      }
    }
    // Cumulative profit
    double running = 0;
    final spots = <FlSpot>[];
    for (int i = 0; i < 7; i++) {
      running += (profitData[i] ?? 0);
      spots.add(FlSpot(i.toDouble(), running));
    }
    if (spots.every((s) => s.y == 0)) {
      spots.clear();
      spots.addAll([const FlSpot(0, 100), const FlSpot(1, 300), const FlSpot(2, 200), const FlSpot(3, 500), const FlSpot(4, 400), const FlSpot(5, 600), const FlSpot(6, 550)]);
    }

    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Profit', style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w700, color: _DC.textPrimary)),
                ],
              ),
              Row(
                children: [
                  Text('Show all', style: GoogleFonts.inter(fontSize: 12, color: _DC.green, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  Container(
                    height: 18, width: 18,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _DC.greenSoft),
                    child: const Icon(Icons.arrow_forward, size: 10, color: _DC.green),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Week / Month / Year tabs
          Row(
            children: List.generate(tabs.length, (i) {
              final isActive = _profitTabIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _profitTabIndex = i),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? _DC.textPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tabs[i],
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : _DC.textSecondary,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // Line chart
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true, drawVerticalLine: true, drawHorizontalLine: false,
                  getDrawingVerticalLine: (value) => FlLine(color: _DC.border, strokeWidth: 0.8),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 22, interval: 1,
                      getTitlesWidget: (value, meta) {
                        final labels = ['16', '17', '18', '19', '20', '21', '22'];
                        final idx = value.toInt();
                        if (idx >= 0 && idx < labels.length) {
                          return Text(labels[idx], style: GoogleFonts.inter(fontSize: 10, color: _DC.textFaint));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0, maxX: 6,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: _DC.green,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [_DC.green.withOpacity(0.08), Colors.transparent],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Income Card ────────────────────────────────────────────────

  Widget _buildIncomeCard(double income) {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    height: 28, width: 28,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _DC.greenSoft),
                    child: const Icon(Icons.trending_up_rounded, size: 14, color: _DC.green),
                  ),
                  const SizedBox(width: 10),
                  Text('Income', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _DC.textPrimary)),
                ],
              ),
              const Icon(Icons.more_horiz, size: 18, color: _DC.textFaint),
            ],
          ),
          const SizedBox(height: 16),
          // Sparkline
          SizedBox(
            height: 50,
            child: CustomPaint(
              size: const Size(double.infinity, 50),
              painter: _MiniSparklinePainter(color: _DC.green, data: [20, 35, 28, 45, 38, 55, 48, 60]),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+₹${income.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: _DC.textPrimary)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _DC.greenSoft, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Text('+12%', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _DC.green)),
                    const Icon(Icons.arrow_upward, size: 10, color: _DC.green),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Expense Card ───────────────────────────────────────────────

  Widget _buildExpenseCard(double expense) {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    height: 28, width: 28,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _DC.greenSoft),
                    child: const Icon(Icons.trending_down_rounded, size: 14, color: _DC.green),
                  ),
                  const SizedBox(width: 10),
                  Text('Expenses', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _DC.textPrimary)),
                ],
              ),
              const Icon(Icons.more_horiz, size: 18, color: _DC.textFaint),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: CustomPaint(
              size: const Size(double.infinity, 50),
              painter: _MiniSparklinePainter(color: _DC.green, data: [55, 48, 52, 40, 45, 35, 38, 30]),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('-₹${expense.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: _DC.textPrimary)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _DC.redSoft, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Text('-23%', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _DC.red)),
                    const Icon(Icons.arrow_downward, size: 10, color: _DC.red),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Spendings Bar Chart ────────────────────────────────────────

  Widget _buildSpendingsBarChart(List<TransactionModel> transactions) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'June', 'July', 'Aug', 'Sep', 'Oct', 'Nov'];
    final Map<int, double> monthlyExpense = {};
    for (int i = 1; i <= 11; i++) { monthlyExpense[i] = 0; }
    for (var tx in transactions) {
      if (tx.type == TransactionType.expense && tx.date.month <= 11) {
        monthlyExpense[tx.date.month] = (monthlyExpense[tx.date.month] ?? 0) + tx.amount;
      }
    }
    // Normalize for visual height
    final maxVal = monthlyExpense.values.fold(0.0, (a, b) => a > b ? a : b);
    final normalizer = maxVal > 0 ? maxVal : 1000.0;

    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Spendings statistic', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _DC.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _DC.border),
                ),
                child: Row(
                  children: [
                    Text('Year', style: GoogleFonts.inter(fontSize: 11, color: _DC.textSecondary)),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 14, color: _DC.textSecondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: normalizer * 1.2,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 20,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < months.length) {
                          return Text(months[idx], style: GoogleFonts.inter(fontSize: 9, color: _DC.textFaint));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: List.generate(11, (i) {
                  final val = monthlyExpense[i + 1] ?? 0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: val > 0 ? val : normalizer * 0.05,
                        color: _DC.goldBar,
                        width: 14,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Planning Section ───────────────────────────────────────────

  Widget _buildPlanningSection(AsyncValue<List<GoalModel>> goalsState) {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Planning', style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w700, color: _DC.textPrimary)),
              Row(
                children: [
                  Text('Add new', style: GoogleFonts.inter(fontSize: 12, color: _DC.textSecondary)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _showAddGoalDialog,
                    child: Container(
                      height: 20, width: 20,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _DC.greenSoft, border: Border.all(color: _DC.green, width: 1.5)),
                      child: const Icon(Icons.add, size: 12, color: _DC.green),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          goalsState.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _DC.green)),
            error: (e, _) => Text('Error: $e'),
            data: (goals) {
              if (goals.isEmpty) {
                return Column(
                  children: [
                    _goalItem('House in Paris', 265, 10000, 0.45),
                    const SizedBox(height: 14),
                    _goalItem('Trip to Brazil', 10456, 14000, 0.75),
                  ],
                );
              }
              return Column(
                children: goals.take(3).map((goal) {
                  final progress = goal.targetAmount > 0 ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _goalItem(goal.name, goal.currentAmount, goal.targetAmount, progress),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _goalItem(String name, double current, double target, double progress) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _DC.bg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _DC.textPrimary)),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: '₹${current.toStringAsFixed(0)}/', style: GoogleFonts.inter(fontSize: 11, color: _DC.textFaint, decoration: TextDecoration.lineThrough)),
                    TextSpan(text: '₹${target.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _DC.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: _DC.greenSoft,
              color: _DC.gold,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Latest Transactions Card ───────────────────────────────────

  Widget _buildLatestTransactionsCard(List<TransactionModel> transactions) {
    final recent = transactions.take(3).toList();

    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Latest transactions', style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w700, color: _DC.textPrimary)),
              Container(
                height: 28, width: 28,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: _DC.border)),
                child: const Icon(Icons.swap_vert, size: 16, color: _DC.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: Text('No transactions yet', style: GoogleFonts.inter(color: _DC.textFaint))),
            )
          else
            ...recent.map((tx) {
              final isExpense = tx.type == TransactionType.expense;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    // Date
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('MMMM dd, yyyy').format(tx.date), style: GoogleFonts.inter(fontSize: 10, color: _DC.textFaint)),
                        Text(DateFormat('hh:mm a').format(tx.date), style: GoogleFonts.inter(fontSize: 10, color: _DC.textFaint)),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Icon
                    Container(
                      height: 34, width: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isExpense ? _DC.redSoft : _DC.greenSoft,
                      ),
                      child: Icon(
                        isExpense ? Icons.arrow_outward_rounded : Icons.call_received_rounded,
                        size: 14, color: isExpense ? _DC.red : _DC.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx.merchantName ?? tx.category, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _DC.textPrimary)),
                          Text(tx.category, style: GoogleFonts.inter(fontSize: 10, color: _DC.textFaint)),
                        ],
                      ),
                    ),
                    // Amount + Status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isExpense ? "-" : "+"}₹${tx.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _DC.textPrimary),
                        ),
                        Text('Completed', style: GoogleFonts.inter(fontSize: 10, color: _DC.textFaint)),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── Go Premium Card ────────────────────────────────────────────

  Widget _buildGoPremiumCard() {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Go premium', style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w700, color: _DC.textPrimary)),
              const SizedBox(width: 8),
              Container(
                height: 22, width: 22,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _DC.greenSoft),
                child: const Icon(Icons.info_outline, size: 12, color: _DC.green),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Explore all banking functions with\nlifetime membership',
            style: GoogleFonts.inter(fontSize: 12, color: _DC.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          // Illustration placeholder
          Center(
            child: Container(
              height: 100, width: 140,
              decoration: BoxDecoration(
                color: _DC.bg.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.workspace_premium_rounded, size: 36, color: _DC.gold),
                  const SizedBox(height: 6),
                  Text('Premium', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _DC.gold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Card container helper ──────────────────────────────────────

  Widget _cardContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _DC.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _DC.border.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: child,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PRESERVED SUB-PANELS (cases 1-8)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildExpensesPanel(List<TransactionModel> list, bool isDark) {
    final expenses = list.where((t) => t.type == TransactionType.expense).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Expense Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => context.push('/add-transaction'),
              child: const Text('+ Add Expense', style: TextStyle(color: _DC.green, fontWeight: FontWeight.bold)),
            )
          ],
        ),
        const SizedBox(height: 14),
        if (expenses.isEmpty)
          const GlassCard(child: Center(child: Padding(padding: EdgeInsets.all(30.0), child: Text('No recorded expenses.'))))
        else
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 3.2),
            itemCount: expenses.length,
            itemBuilder: (context, index) => _TransactionRowItem(tx: expenses[index], isDark: isDark),
          ),
      ],
    );
  }

  Widget _buildIncomePanel(List<TransactionModel> list, bool isDark) {
    final incomes = list.where((t) => t.type == TransactionType.income).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Income Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => context.push('/add-transaction'),
              child: const Text('+ Add Income', style: TextStyle(color: _DC.green, fontWeight: FontWeight.bold)),
            )
          ],
        ),
        const SizedBox(height: 14),
        if (incomes.isEmpty)
          const GlassCard(child: Center(child: Padding(padding: EdgeInsets.all(30.0), child: Text('No recorded income.'))))
        else
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 3.2),
            itemCount: incomes.length,
            itemBuilder: (context, index) => _TransactionRowItem(tx: incomes[index], isDark: isDark),
          ),
      ],
    );
  }

  Widget _buildReportsPanel(List<TransactionModel> txs, double income, double expense) {
    Map<String, double> categorySums = {};
    for (var tx in txs) {
      if (tx.type == TransactionType.expense) {
        categorySums[tx.category] = (categorySums[tx.category] ?? 0.0) + tx.amount;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Analytics Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 700;
            return Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: isDesktop ? 5 : 0, child: _buildInteractivePieChart(txs, expense)),
                SizedBox(width: isDesktop ? 16 : 0, height: isDesktop ? 0 : 16),
                Expanded(
                  flex: isDesktop ? 5 : 0,
                  child: GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('EXPORT STATEMENTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                        const SizedBox(height: 20),
                        _ExportRowBtn(label: 'Export PDF Statement', icon: Icons.picture_as_pdf_outlined, color: Colors.redAccent, onTap: () => _triggerExport('pdf', txs, income, expense)),
                        const SizedBox(height: 12),
                        _ExportRowBtn(label: 'Export Excel Worksheet', icon: Icons.table_chart_outlined, color: Colors.green, onTap: () => _triggerExport('excel', txs, income, expense)),
                      ],
                    ),
                  ),
                )
              ],
            );
          },
        ),
      ],
    );
  }

  void _triggerExport(String type, List<TransactionModel> txs, double income, double expense) async {
    File file;
    String mime;
    if (type == 'pdf') {
      file = await ReportGenerator.generatePDF(transactions: txs, totalIncome: income, totalExpense: expense);
      mime = 'application/pdf';
    } else {
      file = await ReportGenerator.generateExcel(transactions: txs);
      mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    await Share.shareXFiles([XFile(file.path, mimeType: mime)], text: 'Antigravity Statement Export');
  }

  Widget _buildInteractivePieChart(List<TransactionModel> txs, double totalExpense) {
    Map<String, double> categorySums = {};
    for (var tx in txs) {
      if (tx.type == TransactionType.expense) {
        categorySums[tx.category] = (categorySums[tx.category] ?? 0.0) + tx.amount;
      }
    }
    if (categorySums.isEmpty) categorySums['Others'] = 1.0;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Category Breakdown', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4, centerSpaceRadius: 40,
                sections: categorySums.entries.map((e) => PieChartSectionData(color: _getCatColor(e.key), value: e.value, title: '', radius: 20)).toList(),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12, runSpacing: 6,
            children: categorySums.entries.map((entry) {
              final percent = totalExpense > 0 ? (entry.value / totalExpense) * 100 : 0.0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(height: 8, width: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _getCatColor(entry.key))),
                  const SizedBox(width: 6),
                  Text('${entry.key} (${percent.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _DC.textSecondary)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetsPanel(List<TransactionModel> txs, List<BudgetModel> budgets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Category Budgets Limit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton(onPressed: _showAddBudgetDialog, child: const Text('+ Set Budget', style: TextStyle(color: _DC.green, fontWeight: FontWeight.bold)))
          ],
        ),
        const SizedBox(height: 14),
        if (budgets.isEmpty)
          const GlassCard(child: Center(child: Padding(padding: EdgeInsets.all(30.0), child: Text('No budgets configured.'))))
        else
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 2.2),
            itemCount: budgets.length,
            itemBuilder: (context, index) {
              final budget = budgets[index];
              double spent = 0;
              for (var tx in txs) {
                if (tx.type == TransactionType.expense && (budget.category == 'All' || tx.category == budget.category)) spent += tx.amount;
              }
              final progress = budget.amount > 0 ? (spent / budget.amount).clamp(0.0, 1.0) : 0.0;
              return GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(budget.category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('₹${spent.toStringAsFixed(0)} / ₹${budget.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.white.withOpacity(0.08), color: progress > 0.85 ? _DC.red : _DC.green)),
                      const SizedBox(height: 6),
                      Text('${(progress * 100).toStringAsFixed(0)}% consumed', style: TextStyle(fontSize: 10, color: progress > 0.85 ? _DC.red : Colors.grey)),
                    ]),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildGoalsPanel(AsyncValue<List<GoalModel>> goalsState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Savings Goals Tracker', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton(onPressed: _showAddGoalDialog, child: const Text('+ Add Goal', style: TextStyle(color: _DC.green, fontWeight: FontWeight.bold)))
          ],
        ),
        const SizedBox(height: 14),
        goalsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (goals) {
            if (goals.isEmpty) return const GlassCard(child: Center(child: Padding(padding: EdgeInsets.all(30.0), child: Text('No active savings goals.'))));
            return GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 2.2),
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                final progress = goal.targetAmount > 0 ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0) : 0.0;
                return GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(goal.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        TextButton(style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)), onPressed: () => _showFundGoalDialog(goal), child: const Text('+ Fund', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('₹${goal.currentAmount.toStringAsFixed(0)} / ₹${goal.targetAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _DC.green)),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.white.withOpacity(0.08), color: _DC.green)),
                      ]),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAIInsightsPanel() {
    final insights = [
      {'title': 'Weekend Spending Surge', 'desc': 'Your expenses increase by 45% on weekends compared to weekdays, primarily driven by Shopping and Restaurants.', 'color': _DC.red, 'icon': Icons.trending_up_rounded},
      {'title': 'Unusual Transaction Detected', 'desc': 'A payment of ₹4,500 at Nike Store was 120% higher than your historical shopping average.', 'color': _DC.gold, 'icon': Icons.warning_amber_rounded},
      {'title': 'Subscription Leakage', 'desc': 'We found 3 active streaming memberships. Consolidating them could save you ₹7,800 annually.', 'color': _DC.green, 'icon': Icons.subscriptions_rounded},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(children: [Icon(Icons.auto_awesome, color: _DC.gold, size: 20), SizedBox(width: 8), Text('AI Pattern Insights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 2.2),
          itemCount: insights.length,
          itemBuilder: (context, index) {
            final ins = insights[index];
            return GlassCard(
              padding: const EdgeInsets.all(20),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(ins['icon'] as IconData, color: ins['color'] as Color, size: 22),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ins['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(ins['desc'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.35)),
                ])),
              ]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAISuggestionsPanel() {
    final suggestions = [
      {'title': 'Optimize Dining Expenses', 'action': 'Reduce dining out by 1 meal per week to save approx ₹3,400 monthly.', 'impact': '₹3,400 / month savings'},
      {'title': 'Automate Emergency Savings', 'action': 'Routing ₹2,500 automatically to your Emergency Fund will help complete your target 3 months early.', 'impact': 'Goal completion 3m early'},
      {'title': 'Month-End Balance Projection', 'action': 'Based on current burn velocity, your predicted month-end balance will be ₹68,540.', 'impact': '₹12,400 surplus'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(children: [Icon(Icons.lightbulb_outline_rounded, color: _DC.gold, size: 20), SizedBox(width: 8), Text('AI Actionable Suggestions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 2.2),
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final s = suggestions[index];
            return GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Flexible(child: Text(s['title']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _DC.greenSoft, borderRadius: BorderRadius.circular(6)),
                    child: Text(s['impact']!, style: const TextStyle(fontSize: 9, color: _DC.green, fontWeight: FontWeight.bold)),
                  ),
                ]),
                Text(s['action']!, style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.35)),
              ]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSettingsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('System Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(children: [
            ListTile(
              title: const Text('Dark Theme'),
              subtitle: const Text('Enable dark theme across the application'),
              trailing: Switch(
                value: ref.watch(themeModeProvider) == ThemeMode.dark,
                activeColor: _DC.green,
                onChanged: (v) => ref.read(themeModeProvider.notifier).setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
              ),
            ),
            const Divider(),
            ListTile(title: const Text('Biometrics Authentication'), subtitle: const Text('Enable fingerprint/face lock on startup'), trailing: Switch(value: false, activeColor: _DC.green, onChanged: (v) {})),
            const Divider(),
            ListTile(
              title: const Text('Clear Local Database', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              subtitle: const Text('Completely clear all transactions, budgets and goals'),
              onTap: () async {
                await HiveService.clearAllBoxes();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Database cleared successfully!'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))));
                }
              },
            ),
          ]),
        ),
      ],
    );
  }

  Color _getCatColor(String category) {
    switch (category) {
      case 'Food': return Colors.orange;
      case 'Grocery': return Colors.green;
      case 'Shopping': return Colors.purple;
      case 'Medical': return Colors.red;
      case 'Fuel': return Colors.blue;
      case 'Rent': return Colors.deepOrange;
      default: return Colors.blueGrey;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════

// Mini sparkline painter for income/expense cards
class _MiniSparklinePainter extends CustomPainter {
  final Color color;
  final List<double> data;

  _MiniSparklinePainter({required this.color, required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()..style = PaintingStyle.fill;

    final maxVal = data.reduce(max);
    final minVal = data.reduce(min);
    final range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    final path = Path();
    final fillPath = Path();
    final stepX = size.width / (data.length - 1);

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - minVal) / range) * size.height * 0.85 - size.height * 0.075;
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final cp1 = Offset(p0.dx + stepX / 2, p0.dy);
      final cp2 = Offset(p1.dx - stepX / 2, p1.dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    fillPaint.shader = LinearGradient(
      colors: [color.withOpacity(0.15), color.withOpacity(0.0)],
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter oldDelegate) => oldDelegate.data != data;
}

// Sparkline Custom Painter (preserved for compatibility)
class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final double progress;
  final List<Color> colors;

  _SparklinePainter({required this.data, required this.progress, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final path = Path();
    final fillPath = Path();
    final maxVal = data.reduce(max);
    final minVal = data.reduce(min);
    final range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;
    final stepX = size.width / (data.length - 1);
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedY = (data[i] - minVal) / range;
      final y = size.height - (normalizedY * size.height * 0.7 + size.height * 0.15);
      points.add(Offset(x, y));
    }
    final limit = (points.length * progress).floor();
    if (limit < 1) return;
    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);
    for (int i = 1; i < limit; i++) {
      final p0 = points[i - 1]; final p1 = points[i];
      final cp1 = Offset(p0.dx + stepX / 2, p0.dy);
      final cp2 = Offset(p1.dx - stepX / 2, p1.dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }
    if (limit < points.length && progress < 1.0) {
      final fraction = (points.length * progress) - limit;
      final p0 = points[limit - 1]; final p1 = points[limit];
      final targetX = p0.dx + (p1.dx - p0.dx) * fraction;
      final targetY = p0.dy + (p1.dy - p0.dy) * fraction;
      path.lineTo(targetX, targetY);
      fillPath.lineTo(targetX, targetY);
      fillPath.lineTo(targetX, size.height);
    } else {
      fillPath.lineTo(points.last.dx, size.height);
    }
    final shaderRect = Rect.fromLTWH(0, 0, size.width, size.height);
    paint.shader = LinearGradient(colors: colors).createShader(shaderRect);
    fillPaint.shader = LinearGradient(colors: [colors.first.withOpacity(0.2), colors.first.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(shaderRect);
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.data != data;
}

// Animated Counter Widget
class _AnimatedCounter extends StatefulWidget {
  final double value;
  final TextStyle style;
  final String prefix;
  const _AnimatedCounter({required this.value, required this.style, this.prefix = ''});
  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _animation = Tween<double>(begin: 0.0, end: widget.value).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad));
    _controller.forward();
  }
  @override
  void didUpdateWidget(_AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(begin: _animation.value, end: widget.value).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad));
      _controller.forward(from: 0.0);
    }
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _animation, builder: (context, child) => Text('${widget.prefix}${_animation.value.toStringAsFixed(2)}', style: widget.style));
  }
}

// Transaction list row item
class _TransactionRowItem extends StatelessWidget {
  final TransactionModel tx;
  final bool isDark;
  const _TransactionRowItem({required this.tx, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: (tx.type == TransactionType.expense ? _DC.red : _DC.green).withOpacity(0.12),
              child: Icon(tx.type == TransactionType.expense ? Icons.arrow_outward_rounded : Icons.call_received_rounded, size: 16, color: tx.type == TransactionType.expense ? _DC.red : _DC.green),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tx.merchantName ?? tx.category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(DateFormat('dd MMM, hh:mm a').format(tx.date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
          ]),
          Text(
            '${tx.type == TransactionType.expense ? "-" : "+"}₹${tx.amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tx.type == TransactionType.expense ? _DC.red : _DC.green),
          ),
        ],
      ),
    );
  }
}

// Action Tile inside Bottom Sheet
class _BottomSheetActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _BottomSheetActionTile({required this.icon, required this.title, required this.subtitle, required this.gradient, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.black.withOpacity(0.01), border: Border.all(color: _DC.border, width: 1.2)),
        child: Row(children: [
          Container(height: 48, width: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: gradient)), child: Icon(icon, color: Colors.white, size: 22)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
        ]),
      ),
    );
  }
}

// Legend indicator for charts
class _LegendIndicator extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendIndicator({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(height: 8, width: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey)),
    ]);
  }
}

// Pulsing FAB button
class PulsingFAB extends StatefulWidget {
  final VoidCallback onPressed;
  const PulsingFAB({super.key, required this.onPressed});
  @override
  State<PulsingFAB> createState() => _PulsingFABState();
}

class _PulsingFABState extends State<PulsingFAB> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
  }
  @override
  void dispose() { _pulseController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Container(
            height: 56 + _pulseAnimation.value * 28, width: 56 + _pulseAnimation.value * 28,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _DC.green.withOpacity(0.35 * (1.0 - _pulseAnimation.value))),
          ),
        ),
        FloatingActionButton(
          shape: const CircleBorder(), backgroundColor: _DC.green, elevation: 4, onPressed: widget.onPressed,
          child: Container(
            height: 56, width: 56,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [_DC.green, _DC.greenMid], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }
}

// Export Row Button inside reports panel
class _ExportRowBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ExportRowBtn({required this.label, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.black.withOpacity(0.01), border: Border.all(color: _DC.border, width: 1.2)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 12), Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold))]),
          const Icon(Icons.download_rounded, size: 16, color: Colors.grey),
        ]),
      ),
    );
  }
}
