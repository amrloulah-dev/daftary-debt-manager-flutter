import 'package:fatora/custom_widgets/custom_widgets.dart';
import 'package:fatora/models/debts_model.dart' as debts_model;
import 'package:fatora/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

class DebtDetailsScreen extends StatelessWidget {
  final debts_model.DebtTransaction debt;

  const DebtDetailsScreen({super.key, required this.debt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.debtDetails),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppThemes.spacing16),
        child: Card(
          elevation: AppThemes.elevation2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemes.radiusMedium),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppThemes.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: FinancialAmount(
                    amount: debt.total.toDouble(),
                    isDebt: true,
                    fontSize: 48,
                  ),
                ),
                const SizedBox(height: AppThemes.spacing24),
                if (debt.notes.isNotEmpty)
                  _buildDetailRow(
                    theme,
                    icon: Icons.description_outlined,
                    label: l10n.description,
                    value: debt.notes,
                  ),
                const SizedBox(height: AppThemes.spacing16),
                _buildDetailRow(
                  theme,
                  icon: Icons.calendar_today_outlined,
                  label: l10n.date,
                  value: DateFormat.yMMMd().format(debt.createdAt),
                ),
                const SizedBox(height: AppThemes.spacing16),
                _buildDetailRow(
                  theme,
                  icon: debt.isPaid
                      ? Icons.check_circle_outline
                      : Icons.hourglass_empty_outlined,
                  label: l10n.paid,
                  value: debt.isPaid ? l10n.paid : l10n.unpaid,
                  valueColor: AppThemes.getFinancialColor(context, !debt.isPaid),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(ThemeData theme,
      {required IconData icon,
      required String label,
      required String value,
      Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.secondary, size: 20),
        const SizedBox(width: AppThemes.spacing16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: AppThemes.spacing4),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
