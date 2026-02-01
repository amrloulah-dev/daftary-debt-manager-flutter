import 'package:fatora/providers/debtor_provider.dart';
import 'package:fatora/themes/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // Use a flag to ensure we load data once
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      // Schedule the update after the current frame builds
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<DebtorProvider>().loadDebtors();
      });
      _isInit = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statistics),
      ),
      body: Consumer<DebtorProvider>(
        builder: (context, debtorProvider, child) {
          if (debtorProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = debtorProvider.statistics;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Debt vs Paid (Pie Chart)
                _buildDebtDistributionCard(context, stats, l10n),
                const SizedBox(height: 24),

                // 2. Key Metrics Grid
                _buildMetricsGrid(context, stats, l10n),
                const SizedBox(height: 24),
                
                // 3. Debtor Status
                _buildDebtorStatusCard(context, stats, l10n),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDebtDistributionCard(
      BuildContext context, GeneralStatistics stats, AppLocalizations l10n) {
    final theme = Theme.of(context);
    
    // Avoid division by zero or empty charts
    final totalVolume = stats.totalBorrowed > 0 ? stats.totalBorrowed.toDouble() : 1.0;
    final paidVal = stats.totalPaid.toDouble();
    final outstandingVal = stats.totalCurrentDebt.toDouble();
    
    // If no data
    if (stats.totalBorrowed == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(child: Text(l10n.noRecentTransactions)), // Reuse string
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              l10n.debtDistribution,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      color: AppThemes.successColor,
                      value: paidVal,
                      title: '${((paidVal / totalVolume) * 100).toStringAsFixed(1)}%',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: AppThemes.debtColor,
                      value: outstandingVal,
                      title: '${((outstandingVal / totalVolume) * 100).toStringAsFixed(1)}%',
                      radius: 60, // Slightly larger to emphasize debt
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(context, l10n.paid, AppThemes.successColor),
                const SizedBox(width: 24),
                _buildLegendItem(context, l10n.outstanding, AppThemes.debtColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String text, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildMetricsGrid(
      BuildContext context, GeneralStatistics stats, AppLocalizations l10n) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2, // Decreased from 1.5 to make cards taller
      children: [
        _buildStatCard(
          context,
          l10n.totalOutstanding,
          stats.totalCurrentDebt.toDouble(),
          AppThemes.debtColor,
          Icons.money_off,
        ),
        _buildStatCard(
          context,
          l10n.totalPaid,
          stats.totalPaid.toDouble(),
          AppThemes.successColor,
          Icons.attach_money,
        ),
        _buildStatCard(
          context,
          l10n.avgDebtPerDebtor,
          stats.averageDebt.toDouble(),
          Colors.orange,
          Icons.analytics,
        ),
        _buildStatCard(
          context,
          l10n.paymentRate,
          stats.paymentRate.toDouble(),
          Colors.blue,
          Icons.percent,
          isPercentage: true,
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, double value,
      Color color, IconData icon,
      {bool isPercentage = false}) {
    final theme = Theme.of(context);
    final formattedValue = isPercentage
        ? '${value.toStringAsFixed(1)}%'
        : NumberFormat.compactCurrency(symbol: '').format(value);

    return Container(
      padding: const EdgeInsets.all(12), // Reduced from 16 to save space
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24), // Reduced from 28
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formattedValue,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDebtorStatusCard(
      BuildContext context, GeneralStatistics stats, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.people),
        title: Text(l10n.activeDebtors),
        trailing: Text(
          '${stats.activeDebtors} / ${stats.totalDebtors}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}