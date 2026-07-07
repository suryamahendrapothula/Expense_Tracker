import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/config/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction_model.dart';
import '../services/report_generator.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _timeRangeIndex = 1; // 0 = Week, 1 = Month, 2 = Year
  bool _isExporting = false;

  Future<void> _exportReport(String type) async {
    setState(() => _isExporting = true);
    
    final txsState = ref.read(transactionListProvider);
    final transactions = txsState.maybeWhen(
      data: (list) => list,
      orElse: () => <TransactionModel>[],
    );

    double totalIncome = 0;
    double totalExpense = 0;
    for (var tx in transactions) {
      if (tx.type == TransactionType.income) {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }
    }

    try {
      File file;
      String mime;
      
      switch (type) {
        case 'pdf':
          file = await ReportGenerator.generatePDF(
            transactions: transactions,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
          );
          mime = 'application/pdf';
          break;
        case 'excel':
          file = await ReportGenerator.generateExcel(transactions: transactions);
          mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          break;
        case 'csv':
        default:
          file = await ReportGenerator.generateCSV(transactions: transactions);
          mime = 'text/csv';
      }

      await Share.shareXFiles(
        [XFile(file.path, mimeType: mime)],
        text: 'Antigravity Financial Statement Export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.expense),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txsState = ref.watch(transactionListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
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
        child: txsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (transactions) {
            // Spend categorisation math
            double totalIncome = 0;
            double totalExpense = 0;
            Map<String, double> categorySums = {};

            for (var tx in transactions) {
              if (tx.type == TransactionType.income) {
                totalIncome += tx.amount;
              } else {
                totalExpense += tx.amount;
                categorySums[tx.category] = (categorySums[tx.category] ?? 0.0) + tx.amount;
              }
            }

            final double balance = totalIncome - totalExpense;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Range Selector Toggle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _RangeOption(
                          label: 'WEEK',
                          isSelected: _timeRangeIndex == 0,
                          onTap: () => setState(() => _timeRangeIndex = 0),
                        ),
                        _RangeOption(
                          label: 'MONTH',
                          isSelected: _timeRangeIndex == 1,
                          onTap: () => setState(() => _timeRangeIndex = 1),
                        ),
                        _RangeOption(
                          label: 'YEAR',
                          isSelected: _timeRangeIndex == 2,
                          onTap: () => setState(() => _timeRangeIndex = 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Income vs Expense Bar Chart Box
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'INCOME VS EXPENSES',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 180,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceEvenly,
                              maxY: totalIncome > totalExpense ? totalIncome * 1.1 : totalExpense * 1.1,
                              barTouchData: BarTouchData(enabled: true),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      switch (value.toInt()) {
                                        case 0:
                                          return const Text('Income', style: TextStyle(fontSize: 11));
                                        case 1:
                                          return const Text('Expenses', style: TextStyle(fontSize: 11));
                                        default:
                                          return const Text('');
                                      }
                                    },
                                  ),
                                ),
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              gridData: const FlGridData(show: false),
                              barGroups: [
                                BarChartGroupData(
                                  x: 0,
                                  barRods: [
                                    BarChartRodData(
                                      toY: totalIncome,
                                      color: AppColors.income,
                                      width: 28,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                    )
                                  ],
                                ),
                                BarChartGroupData(
                                  x: 1,
                                  barRods: [
                                    BarChartRodData(
                                      toY: totalExpense,
                                      color: AppColors.expense,
                                      width: 28,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Distribution Pie Chart
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SPENDING CATEGORY BREAKDOWN',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 160,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 4,
                              centerSpaceRadius: 40,
                              sections: categorySums.entries.map((entry) {
                                final isSignificant = entry.value > (totalExpense * 0.05);
                                return PieChartSectionData(
                                  color: _getCategoryColor(entry.key),
                                  value: entry.value,
                                  title: isSignificant ? entry.key : '',
                                  radius: 44,
                                  titleStyle: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Legend List
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: categorySums.keys.map((cat) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 8,
                                  width: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getCategoryColor(cat),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$cat (₹${categorySums[cat]!.toStringAsFixed(0)})',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                )
                              ],
                            );
                          }).toList(),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Export Options Card
                  GlassCard(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.08),
                        AppColors.secondary.withOpacity(0.04),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EXPORT STATEMENTS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Download your full records with AI financial analysis and projections attached.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _ExportButton(
                                label: 'PDF Report',
                                icon: Icons.picture_as_pdf_outlined,
                                color: Colors.redAccent,
                                onTap: () => _exportReport('pdf'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ExportButton(
                                label: 'Excel Sheet',
                                icon: Icons.table_chart_outlined,
                                color: Colors.green,
                                onTap: () => _exportReport('excel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ExportButton(
                                label: 'CSV File',
                                icon: Icons.description_outlined,
                                color: Colors.blueAccent,
                                onTap: () => _exportReport('csv'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Food': return Colors.orange;
      case 'Grocery': return Colors.green;
      case 'Shopping': return Colors.purple;
      case 'Medical': return Colors.red;
      case 'Fuel': return Colors.blue;
      case 'Entertainment': return Colors.pink;
      case 'Rent': return Colors.deepOrange;
      default: return Colors.blueGrey;
    }
  }
}

class _RangeOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RangeOption({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ExportButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.01),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            )
          ],
        ),
      ),
    );
  }
}
