import 'package:fatora/custom_widgets/custom_widgets.dart';
import 'package:fatora/models/payment_model.dart';
import 'package:fatora/providers/debtor_provider.dart';
import 'package:fatora/providers/theme_provider.dart';
import 'package:fatora/screens/add_edit_debtor_screen.dart';
import 'package:fatora/screens/debtors_list_screen.dart';
import 'package:fatora/screens/settings_screen.dart';
import 'package:fatora/screens/statistics_screen.dart';
import 'package:fatora/services/transaction_service.dart';
import 'package:fatora/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart'; // Import Isar for query extensions
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  int selectedIndex = 0;
  late AnimationController animationController;
  late Animation<double> fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animation setup
    animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    ));
    animationController.forward();

    // Initial Data Fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DebtorProvider>().loadDebtors();
    });
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    final pages = [
      const DashboardContent(),
      const DebtorsListScreen(),
      const StatisticsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: FadeTransition(
        opacity: fadeAnimation,
        child: SafeArea(
          child: IndexedStack(
            index: selectedIndex,
            children: pages,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: l10n.dashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outlined),
            selectedIcon: const Icon(Icons.people),
            label: l10n.debtors,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: l10n.statistics,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await context.read<DebtorProvider>().loadDebtors();
        // Since recent transactions are in a FutureBuilder, triggering setState via a parent or key would be needed to refresh them.
        // For now, re-fetching debtors is the primary action.
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DashboardHeader(),
            const SizedBox(height: 24),
            const DashboardStatsGrid(),
            const SizedBox(height: 24),
            const DashboardQuickActions(),
            const SizedBox(height: 24),
            const RecentTransactionsList(),
          ],
        ),
      ),
    );
  }
}

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary,
          ),
          child: Icon(
            Icons.person,
            color: theme.colorScheme.onPrimary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.welcomeBack,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            themeProvider.setThemeMode(
                isDarkMode ? ThemeMode.light : ThemeMode.dark);
          },
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(isDarkMode),
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class DashboardStatsGrid extends StatelessWidget {
  const DashboardStatsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Selector<DebtorProvider, GeneralStatistics>(
      selector: (_, provider) => provider.statistics,
      builder: (context, stats, child) {
        final statsData = [
          {
            'title': l10n.totalDebtors,
            'value': stats.totalDebtors.toString(),
            'icon': Icons.people,
            'color': AppThemes.primaryColor,
          },
          {
            'title': l10n.activeDebtors,
            'value': stats.activeDebtors.toString(),
            'icon': Icons.people_outline,
            'color': AppThemes.successColor,
          },
          {
            'title': l10n.totalDebt,
            'value': NumberFormat.currency(symbol: '').format(stats.totalCurrentDebt),
            'icon': Icons.account_balance_wallet,
            'color': AppThemes.warningColor,
          },
          {
            'title': l10n.totalPaid,
            'value': NumberFormat.currency(symbol: '').format(stats.totalPaid),
            'icon': Icons.payment,
            'color': AppThemes.debtColor,
          },
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: statsData.length,
          itemBuilder: (context, index) {
            final stat = statsData[index];
            return StatCard(
              title: stat['title'] as String,
              value: stat['value'] as String,
              icon: stat['icon'] as IconData,
              color: stat['color'] as Color,
            );
          },
        );
      },
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.trending_up, color: color, size: 16),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18, 
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.quickActions,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                context,
                l10n.addDebtor,
                Icons.person_add,
                AppThemes.primaryColor,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddEditDebtorScreen()),
                  ).then((_) {
                    context.read<DebtorProvider>().loadDebtors();
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecentTransactionsList extends StatelessWidget {
  const RecentTransactionsList({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.recentTransactions,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                l10n.viewAll,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: FutureBuilder<List<PaymentTransaction>>(
            future: _fetchRecentPayments(), 
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(child: Text(l10n.couldNotLoadTransactions)),
                );
              }
              
              final transactions = snapshot.data ?? [];

              if (transactions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      l10n.noRecentTransactions,
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                separatorBuilder: (context, index) => Divider(
                  color: theme.colorScheme.secondary.withOpacity(0.2),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final payment = transactions[index];
                  return _TransactionItem(payment: payment);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<PaymentTransaction>> _fetchRecentPayments() async {
    final service = TransactionService();
    final isar = await service.db;
    
    // Correct Isar 3.x syntax: where -> sort -> limit -> findAll
    final payments = await isar.paymentTransactions
        .where()
        .sortByCreatedAtDesc()
        .limit(5)
        .findAll();
        
    for (var p in payments) {
      await p.debtor.load();
    }
    
    return payments;
  }
}

class _TransactionItem extends StatelessWidget {
  final PaymentTransaction payment;

  const _TransactionItem({required this.payment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const color = AppThemes.paymentColor;
    const icon = Icons.arrow_downward;
    final debtorName = payment.debtor.value?.name ?? 'Unknown';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(icon, color: color, size: 20),
      ),
      title: Text(
        debtorName,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        DateFormat.yMMMd().format(payment.createdAt),
        style: TextStyle(
          color: theme.colorScheme.secondary,
          fontSize: 12,
        ),
      ),
      trailing: Text(
        NumberFormat.currency(symbol: '').format(payment.amount),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: color,
          fontSize: 14,
        ),
      ),
    );
  }
}
