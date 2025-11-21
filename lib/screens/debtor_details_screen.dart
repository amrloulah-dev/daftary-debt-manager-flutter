import 'package:fatora/custom_widgets/custom_widgets.dart';
import 'package:fatora/models/debtor_model.dart' as debtor_model;
import 'package:fatora/models/debts_model.dart' as debts_model;
import 'package:fatora/models/payment_model.dart' as payment_model;
import 'package:fatora/providers/debtor_provider.dart';
import 'package:fatora/providers/debts_provider.dart';
import 'package:fatora/providers/payment_provider.dart';
import 'package:fatora/screens/add_edit_debtor_screen.dart';
import 'package:fatora/screens/add_edit_debt_screen.dart';
import 'package:fatora/screens/add_edit_payment_screen.dart';
import 'package:fatora/screens/debt_details_screen.dart';
import 'package:fatora/themes/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';

class DebtorDetailsScreen extends StatefulWidget {
  final debtor_model.Debtor debtor;

  const DebtorDetailsScreen({super.key, required this.debtor});

  @override
  State<DebtorDetailsScreen> createState() => _DebtorDetailsScreenState();
}

class _DebtorDetailsScreenState extends State<DebtorDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DebtProvider _debtsProvider = DebtProvider();
  final PaymentProvider _paymentProvider = PaymentProvider();
  final DebtorProvider _debtorProvider = DebtorProvider(); // Add provider instance
  late debtor_model.Debtor _currentDebtor; // Add state variable

  @override
  void initState() {
    super.initState();
    _currentDebtor = widget.debtor; // Initialize
    _tabController = TabController(length: 3, vsync: this);
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateAndRefresh(Widget screen) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );

    if (result == true && mounted) {
      // Fetch the updated debtor object
      final updatedDebtor = await _debtorProvider.getDebtorById(_currentDebtor.id);
      if (updatedDebtor != null) {
        setState(() {
          _currentDebtor = updatedDebtor;
        });
      } else {
        // Fallback to just refreshing the lists if debtor fetch fails
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              title: Text(_currentDebtor.name,
                  style: const TextStyle(fontSize: 22)),
              pinned: true,
              floating: true,
              forceElevated: innerBoxIsScrolled,
              backgroundColor: theme.scaffoldBackgroundColor,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    _navigateAndRefresh(AddEditDebtorScreen(debtor: _currentDebtor));
                  },
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: l10n.debts),
                  Tab(text: l10n.payments),
                  Tab(text: l10n.summary),
                ],
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildDebtsList(),
            _buildPaymentsList(),
            _buildSummaryTab(),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButtons(context),
    );
  }

  Widget _buildFinancialSummaryCard() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final debtor = _currentDebtor; // Use the state variable
    final double paymentPercentage = debtor.totalBorrowed > 0
        ? debtor.totalPaid / debtor.totalBorrowed
        : 0.0;

    return Card(
      elevation: 2,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetric(l10n.borrowed,
                    NumberFormat.currency(symbol: '').format(debtor.totalBorrowed)),
                _buildMetric(l10n.paid,
                    NumberFormat.currency(symbol: '').format(debtor.totalPaid),
                    color: AppThemes.successColor),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetric(l10n.outstanding,
                    NumberFormat.currency(symbol: '').format(debtor.currentDebt),
                    color: AppThemes.debtColor, isProminent: true),
                _buildMetric(l10n.transactions, debtor.totalTransactions.toString()),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: paymentPercentage,
              backgroundColor: Colors.grey[300],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppThemes.successColor),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(paymentPercentage * 100).toStringAsFixed(0)}${l10n.percentPaid}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
            if (debtor.lastPaymentAt != null)
              Row(
                children: [
                  const Icon(Icons.history, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '${l10n.lastPayment}: ${DateFormat.yMMMd().format(debtor.lastPaymentAt!)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value,
      {Color? color, bool isProminent = false}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: (isProminent
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.titleMedium)
              ?.copyWith(
            color: color ?? theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDebtsList() {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<debts_model.DebtTransaction>>(
      future: _debtsProvider.fetchDebtorDebts(_currentDebtor.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(l10n.errorLoadingDebts));
        }
        final debts = snapshot.data ?? [];
        if (debts.isEmpty) {
          return EmptyState(
            message: l10n.debts,
            description: l10n.noRecentTransactions,
            icon: Icons.receipt_long,
          );
        }
        return ListView.builder(
          itemCount: debts.length,
          itemBuilder: (context, index) {
            final debt = debts[index];
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DebtDetailsScreen(debt: debt),
                  ),
                );
              },
              child: TransactionListItem(
                description: debt.notes.isNotEmpty ? debt.notes : l10n.debts,
                amount: debt.total.toDouble(),
                date: debt.createdAt,
                isDebt: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentsList() {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<payment_model.PaymentTransaction>>(
      future: _paymentProvider.fetchDebtorPayments(_currentDebtor.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(l10n.errorLoadingPayments));
        }
        final payments = snapshot.data ?? [];
        if (payments.isEmpty) {
          return EmptyState(
            message: l10n.payments,
            description: l10n.noPaymentsFound,
            icon: Icons.payment,
          );
        }
        return ListView.builder(
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index];
            return TransactionListItem(
              description:
                  payment.notes.isNotEmpty ? payment.notes : l10n.payments,
              amount: payment.amount.toDouble(),
              date: payment.createdAt,
              isDebt: false,
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryTab() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildFinancialSummaryCard(),
          const SizedBox(height: 16),
          CustomCard(
            title: l10n.paymentTrends,
            child: SizedBox(
              height: 200,
              child: _buildMonthlyPaymentsChart(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyPaymentsChart() {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _paymentProvider.getMonthlyPaymentSummary(
        debtorId: _currentDebtor.id,
        year: DateTime.now().year,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text(l10n.noPaymentsFound));
        }
        final monthlyData = snapshot.data!;

        final barGroups = monthlyData.map((data) {
          final month = data['month'] as int;
          final totalAmount = (data['totalAmount'] as int).toDouble();
          return BarChartGroupData(
            x: month,
            barRods: [
              BarChartRodData(
                toY: totalAmount,
                color: AppThemes.primaryColor,
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList();

        return BarChart(
          BarChartData(
            barGroups: barGroups,
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final month = value.toInt();
                    if (month >= 1 && month <= 12) {
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          DateFormat.MMM().format(DateTime(0, month)),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    }
                    return Container();
                  },
                  reservedSize: 28,
                ),
              ),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${group.x.toInt()}:\n${rod.toY.round()}',
                    const TextStyle(color: Colors.white),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionButtons(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(left: 32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add_debt',
            onPressed: () {
              _navigateAndRefresh(AddEditDebtScreen(debtor: _currentDebtor));
            },
            label: Text(l10n.addDebt),
            icon: const Icon(Icons.add),
            backgroundColor: AppThemes.debtColor,
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: 'add_payment',
            onPressed: () {
              _navigateAndRefresh(AddEditPaymentScreen(debtor: _currentDebtor));
            },
            label: Text(l10n.addPayment),
            icon: const Icon(Icons.payment),
            backgroundColor: AppThemes.successColor,
          ),
        ],
      ),
    );
  }
}