import 'package:fatora/custom_widgets/custom_widgets.dart';
import 'package:fatora/custom_widgets/transaction_tile.dart';
import 'package:fatora/models/debtor_model.dart';
import 'package:fatora/models/debts_model.dart';
import 'package:fatora/models/payment_model.dart';
import 'package:fatora/providers/debtor_provider.dart';
import 'package:fatora/providers/debts_provider.dart';
import 'package:fatora/providers/payment_provider.dart';
import 'package:fatora/screens/add_edit_debt_screen.dart';
import 'package:fatora/screens/add_edit_debtor_screen.dart';
import 'package:fatora/screens/add_edit_payment_screen.dart';
import 'package:fatora/screens/debt_details_screen.dart';
import 'package:fatora/themes/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

class DebtorDetailsScreen extends StatefulWidget {
  final Debtor debtor;

  const DebtorDetailsScreen({super.key, required this.debtor});

  @override
  State<DebtorDetailsScreen> createState() => _DebtorDetailsScreenState();
}

class _DebtorDetailsScreenState extends State<DebtorDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Load data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final debtorId = widget.debtor.id;
      context.read<DebtsProvider>().loadDebts(debtorId);
      context.read<PaymentProvider>().loadPayments(debtorId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Helper to refresh stats after returning from Add/Edit screens
  void _refreshData() {
    // Reload main debtor list to update the header stats
    context.read<DebtorProvider>().loadDebtors();
    // Reload transactions
    context.read<DebtsProvider>().loadDebts(widget.debtor.id);
    context.read<PaymentProvider>().loadPayments(widget.debtor.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // We watch the DebtorProvider to get the *latest* version of this debtor
    // This ensures header stats update immediately when we add a debt/payment
    return Consumer<DebtorProvider>(
      builder: (context, debtorProvider, child) {
        // Find the updated debtor object from the provider's list
        Debtor currentDebtor;
        try {
          currentDebtor = debtorProvider.debtors.firstWhere(
            (d) => d.id == widget.debtor.id,
            orElse: () => widget.debtor, // Fallback if not found (e.g. deleted)
          );
        } catch (e) {
          currentDebtor = widget.debtor;
        }

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverAppBar(
                  title: Text(currentDebtor.name),
                  pinned: true,
                  floating: true,
                  forceElevated: innerBoxIsScrolled,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddEditDebtorScreen(debtor: currentDebtor),
                          ),
                        ).then((_) => _refreshData());
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
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _DebtsTab(debtorId: currentDebtor.id),
                _PaymentsTab(debtorId: currentDebtor.id),
                _SummaryTab(debtor: currentDebtor),
              ],
            ),
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(left: 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'add_debt',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddEditDebtScreen(debtorId: currentDebtor.id),
                      ),
                    ).then((_) => _refreshData());
                  },
                  label: Text(l10n.addDebt),
                  icon: const Icon(Icons.add),
                  backgroundColor: AppThemes.debtColor,
                ),
                const SizedBox(width: 16),
                FloatingActionButton.extended(
                  heroTag: 'add_payment',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddEditPaymentScreen(debtorId: currentDebtor.id),
                      ),
                    ).then((_) => _refreshData());
                  },
                  label: Text(l10n.addPayment),
                  icon: const Icon(Icons.payment),
                  backgroundColor: AppThemes.successColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DebtsTab extends StatelessWidget {
  final int debtorId;

  const _DebtsTab({required this.debtorId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Consumer<DebtsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.debts.isEmpty) {
          return EmptyState(
            message: l10n.debts,
            description: l10n.noRecentTransactions,
            icon: Icons.receipt_long,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: provider.debts.length,
          itemBuilder: (context, index) {
            final debt = provider.debts[index];
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DebtDetailsScreen(debt: debt),
                  ),
                );
              },
              child: TransactionTile(
                debtor: debt.notes?.isNotEmpty == true ? debt.notes! : l10n.debts,
                amount: debt.total.toString(),
                date: DateFormat.yMMMd().format(debt.createdAt),
                icon: Icons.arrow_upward,
                color: AppThemes.debtColor,
              ),
            );
          },
        );
      },
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  final int debtorId;

  const _PaymentsTab({required this.debtorId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<PaymentProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.payments.isEmpty) {
          return EmptyState(
            message: l10n.payments,
            description: l10n.noPaymentsFound,
            icon: Icons.payment,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: provider.payments.length,
          itemBuilder: (context, index) {
            final payment = provider.payments[index];
            return TransactionTile(
              debtor: payment.notes?.isNotEmpty == true ? payment.notes! : l10n.payments,
              amount: payment.amount.toString(),
              date: DateFormat.yMMMd().format(payment.createdAt),
              icon: Icons.arrow_downward,
              color: AppThemes.successColor,
            );
          },
        );
      },
    );
  }
}

class _SummaryTab extends StatelessWidget {
  final Debtor debtor;

  const _SummaryTab({required this.debtor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final double paymentPercentage = debtor.totalBorrowed > 0
        ? debtor.totalPaid / debtor.totalBorrowed
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
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
                      _buildMetric(context, l10n.borrowed, debtor.totalBorrowed.toString()),
                      _buildMetric(context, l10n.paid, debtor.totalPaid.toString(),
                          color: AppThemes.successColor),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetric(context, l10n.outstanding, debtor.currentDebt.toString(),
                          color: AppThemes.debtColor, isProminent: true),
                      _buildMetric(context, l10n.transactions, debtor.totalTransactions.toString()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: paymentPercentage.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(AppThemes.successColor),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(paymentPercentage * 100).toStringAsFixed(0)}${l10n.percentPaid}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Chart placeholder
          SizedBox(
             height: 200,
             child: Center(
               child: Text(
                 l10n.chartPlaceholder, 
                 style: TextStyle(color: theme.colorScheme.secondary)
               ),
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value,
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
}
