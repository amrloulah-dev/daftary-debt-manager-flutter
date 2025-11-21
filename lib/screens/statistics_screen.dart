
import 'package:fatora/custom_widgets/custom_widgets.dart';
import 'package:fatora/providers/debtor_provider.dart';
import 'package:fatora/themes/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/payment_model.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final DebtorProvider _debtorProvider = DebtorProvider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statistics),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKpiGrid(),
              const SizedBox(height: 24),
              _buildCharts(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiGrid() {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<GeneralStatistics>(
      stream: _debtorProvider.getGeneralStatisticsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = snapshot.data!;
        final formatCurrency =
            NumberFormat.currency(symbol: '', decimalDigits: 0);

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
          childAspectRatio: 1.3,
          children: [
            StatisticCard(
              title: l10n.avgDebtPerDebtor,
              value: formatCurrency.format(stats.averageDebt),
              icon: Icons.person_pin_circle_outlined,
              color: AppThemes.primaryColor,
            ),
            StatisticCard(
              title: l10n.paymentRate,
              value: '${stats.paymentRate}%',
              icon: Icons.task_alt,
              color: AppThemes.successColor,
            ),
            StatisticCard(
              title: l10n.totalOutstanding,
              value: formatCurrency.format(stats.totalCurrentDebt),
              icon: Icons.account_balance_wallet_outlined,
              color: AppThemes.debtColor,
            ),
            StatisticCard(
              title: l10n.totalDebtors,
              value: stats.totalDebtors.toString(),
              icon: Icons.people,
              color: AppThemes.warningColor,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCharts() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        CustomCard(
          title: l10n.debtDistribution,
          child: SizedBox(
            height: 200,
            child: _buildPieChart(),
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart() {
    return StreamBuilder<GeneralStatistics>(
      stream: _debtorProvider.getGeneralStatisticsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = snapshot.data!;
        final total = stats.totalPaid + stats.totalCurrentDebt;
        if (total == 0) {
          return Center(child: Text(AppLocalizations.of(context)!.noDebtorsFound));
        }

        final sections = [
          PieChartSectionData(
            value: stats.totalCurrentDebt.toDouble(),
            title: '${(stats.totalCurrentDebt / total * 100).toStringAsFixed(0)}%',
            color: AppThemes.debtColor,
            radius: 50,
          ),
          PieChartSectionData(
            value: stats.totalPaid.toDouble(),
            title: '${(stats.totalPaid / total * 100).toStringAsFixed(0)}%',
            color: AppThemes.successColor,
            radius: 50,
          ),
        ];

        return PieChart(
          PieChartData(
            sections: sections,
            borderData: FlBorderData(show: false),
            sectionsSpace: 2,
            centerSpaceRadius: 40,
          ),
        );
      },
    );
  }
}
