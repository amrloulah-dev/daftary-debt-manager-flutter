import 'dart:async';
import 'package:fatora/custom_widgets/custom_widgets.dart';
import 'package:fatora/models/debtor_model.dart' as DebtorModel;
import 'package:fatora/providers/debtor_provider.dart';
import 'package:fatora/screens/add_edit_debtor_screen.dart';
import 'package:fatora/screens/debtor_details_screen.dart';
import 'package:fatora/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

class DebtorsListScreen extends StatefulWidget {
  const DebtorsListScreen({super.key});

  @override
  State<DebtorsListScreen> createState() => _DebtorsListScreenState();
}

class _DebtorsListScreenState extends State<DebtorsListScreen> {
  final DebtorProvider _debtorProvider = DebtorProvider();
  late Stream<List<DebtorModel.Debtor>> _debtorsStream;
  String _searchQuery = '';
  DebtorModel.SortBy _sortBy = DebtorModel.SortBy.debt;
  DebtorModel.SortOrder _sortOrder = DebtorModel.SortOrder.descending;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _updateDebtorsStream();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _updateDebtorsStream() {
    _debtorsStream = _debtorProvider.getDebtorsStream(
      searchQuery: _searchQuery,
      sortBy: _sortBy,
      sortOrder: _sortOrder,
    );
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != query) {
        setState(() {
          _searchQuery = query;
          _updateDebtorsStream();
        });
      }
    });
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.debtors),
        centerTitle: false,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: _buildSearchAndFilter(context),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateTo(const AddEditDebtorScreen()),
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchAndFilter(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? [Colors.grey.shade900, Colors.grey.shade800]
                    : [Colors.grey.shade200, Colors.white],
                stops: const [0.1, 0.9],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(1.5),
              child: TextField(
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: l10n.searchDebtorsHint,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14.5),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildFilterMenu(context),
      ],
    );
  }

  Widget _buildFilterMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<DebtorModel.SortBy>(
      onSelected: (sortBy) {
        setState(() {
          if (_sortBy == sortBy) {
            _sortOrder = _sortOrder == DebtorModel.SortOrder.ascending
                ? DebtorModel.SortOrder.descending
                : DebtorModel.SortOrder.ascending;
          } else {
            _sortBy = sortBy;
            _sortOrder = DebtorModel.SortOrder.descending;
          }
          _updateDebtorsStream();
        });
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<DebtorModel.SortBy>>[
        PopupMenuItem<DebtorModel.SortBy>(
          value: DebtorModel.SortBy.name,
          child: Text(l10n.byName),
        ),
        PopupMenuItem<DebtorModel.SortBy>(
          value: DebtorModel.SortBy.debt,
          child: Text(l10n.byDebtAmount),
        ),
        PopupMenuItem<DebtorModel.SortBy>(
          value: DebtorModel.SortBy.lastPayment,
          child: Text(l10n.byLastPayment),
        ),
      ],
      icon: Icon(Icons.filter_list, color: Theme.of(context).colorScheme.onSurface),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<List<DebtorModel.Debtor>>(
      stream: _debtorsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeletonLoader();
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(l10n.errorOccurred(snapshot.error.toString())),
          );
        }
        final debtors = snapshot.data ?? [];
        if (debtors.isEmpty) {
          return _buildEmptyState();
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16.0),
          itemCount: debtors.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final debtor = debtors[index];
            return _buildDebtorCard(debtor);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            l10n.noDebtorsFound,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isNotEmpty)
            Text(
              l10n.tryAdjustingSearch,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            )
          else
            Text(
              l10n.noDebtorsFoundHint,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _navigateTo(const AddEditDebtorScreen()),
            icon: const Icon(Icons.add),
            label: Text(l10n.addDebtor),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: 10,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => const DebtorCardSkeleton(),
    );
  }

  Widget _buildDebtorCard(DebtorModel.Debtor debtor) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bool hasDebt = debtor.currentDebt > 0;
    final statusText = hasDebt ? l10n.active : l10n.paidOff;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppThemes.radiusMedium)),
      child: InkWell(
        onTap: () => _navigateTo(DebtorDetailsScreen(debtor: debtor)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debtor.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    FinancialAmount(
                      amount: debtor.currentDebt.toDouble(),
                      isDebt: hasDebt,
                      fontSize: 16,
                    ),
                    const SizedBox(height: 8),
                    if (debtor.lastPaymentAt != null)
                      Text(
                        '${l10n.lastPayment}: ${DateFormat.yMd().format(debtor.lastPaymentAt!)}',
                        style: theme.textTheme.bodySmall,
                      )
                    else
                      Text(
                        l10n.noPaymentsYet,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(text: statusText, type: hasDebt ? BadgeType.error : BadgeType.success),
                  const SizedBox(height: 24),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class DebtorCardSkeleton extends StatelessWidget {
  const DebtorCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppThemes.radiusMedium)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSkeletonLine(width: 150, height: 18),
                  const SizedBox(height: 8),
                  _buildSkeletonLine(width: 100, height: 16),
                  const SizedBox(height: 8),
                  _buildSkeletonLine(width: 120, height: 12),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildSkeletonLine(width: 60, height: 20),
                const SizedBox(height: 24),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[300]),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLine({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
