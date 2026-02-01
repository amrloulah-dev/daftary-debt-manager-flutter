import 'package:fatora/custom_widgets/custom_widgets.dart';
import 'package:fatora/models/debtor_model.dart';
import 'package:fatora/providers/debtor_provider.dart';
import 'package:fatora/screens/add_edit_debtor_screen.dart';
import 'package:fatora/screens/debtor_details_screen.dart';
import 'package:fatora/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';

class DebtorsListScreen extends StatefulWidget {
  const DebtorsListScreen({super.key});

  @override
  State<DebtorsListScreen> createState() => _DebtorsListScreenState();
}

class _DebtorsListScreenState extends State<DebtorsListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<DebtorProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.debtors),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditDebtorScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBarWidget(
              controller: _searchController,
              onChanged: (value) {
                provider.searchDebtors(value);
              },
              placeholder: l10n.searchDebtorsHint,
            ),
          ),
          Expanded(
            child: Consumer<DebtorProvider>(
              builder: (context, debtorProvider, child) {
                if (debtorProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (debtorProvider.debtors.isEmpty) {
                  return EmptyState(
                    message: l10n.noDebtorsFound,
                    description: _searchController.text.isEmpty
                        ? l10n.noDebtorsFoundHint
                        : l10n.tryAdjustingSearch,
                    icon: Icons.people_outline,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80), // Fab space
                  itemCount: debtorProvider.debtors.length,
                  itemBuilder: (context, index) {
                    final debtor = debtorProvider.debtors[index];
                    return _DebtorCard(debtor: debtor);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditDebtorScreen()),
          );
        },
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DebtorCard extends StatelessWidget {
  final Debtor debtor;

  const _DebtorCard({required this.debtor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DebtorDetailsScreen(debtor: debtor),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: Text(
                  debtor.name.isNotEmpty ? debtor.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debtor.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      debtor.phone,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${debtor.currentDebt}', // Format currency properly in real app
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: debtor.currentDebt > 0 
                          ? AppThemes.debtColor 
                          : AppThemes.successColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    debtor.currentDebt > 0 ? l10n.outstanding : l10n.paidOff,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: debtor.currentDebt > 0
                          ? AppThemes.debtColor
                          : AppThemes.successColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.secondary.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}