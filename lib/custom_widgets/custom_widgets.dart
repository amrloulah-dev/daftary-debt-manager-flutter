import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../l10n/app_localizations.dart';
import '../themes/theme.dart';


/// ------------------------------
/// Financial Amount Widget
/// ------------------------------
class FinancialAmount extends StatelessWidget {
  final double amount;
  final bool isDebt;
  final String? prefix;
  final String? suffix;
  final double fontSize;

  const FinancialAmount({
    super.key,
    required this.amount,
    this.isDebt = false,
    this.prefix,
    this.suffix,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppThemes.getFinancialColor(context, isDebt);
    final formatted = NumberFormat.currency(symbol: "").format(amount);

    return Text(
      "${prefix ?? ''}$formatted${suffix ?? ''}",
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        fontSize: fontSize,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// ------------------------------
/// Custom Card Widget
/// ------------------------------
class CustomCard extends StatelessWidget {
  final Widget child;
  final double elevation;
  final EdgeInsetsGeometry padding;
  final String? title;
  final Widget? action;

  const CustomCard({
    super.key,
    required this.child,
    this.elevation = AppThemes.elevation2,
    this.padding = const EdgeInsets.all(AppThemes.spacing16),
    this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppThemes.radiusMedium),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title!, style: Theme.of(context).textTheme.titleMedium),
                  if (action != null) action!,
                ],
              ),
            if (title != null) const SizedBox(height: AppThemes.spacing12),
            child,
          ],
        ),
      ),
    );
  }
}

/// ------------------------------
/// Statistic Card Widget
/// ------------------------------
class StatisticCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;  final Color color;
  final String? subtitle;

  const StatisticCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: AppThemes.spacing12),
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppThemes.spacing4),
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          if (subtitle != null)
            Text(subtitle!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey)),
        ],
      ),
    );
  }
}

/// ------------------------------
/// Custom Button Widget
/// ------------------------------
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool loading;
  final ButtonType type;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.type = ButtonType.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;

    switch (type) {
      case ButtonType.primary:
        background = Theme.of(context).colorScheme.primary;
        foreground = Theme.of(context).colorScheme.onPrimary;
        break;
      case ButtonType.secondary:
        background = Colors.transparent;
        foreground = Theme.of(context).colorScheme.primary;
        break;
      case ButtonType.danger:
        background = AppThemes.debtColor;
        foreground = Colors.white;
        break;
      case ButtonType.success:
        background = AppThemes.successColor;
        foreground = Colors.white;
        break;
      case ButtonType.text:
        background = Colors.transparent;
        foreground = Theme.of(context).colorScheme.primary;
        break;
    }

    final btn = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
        type == ButtonType.secondary || type == ButtonType.text
            ? null
            : background,
        foregroundColor: foreground,
        side: type == ButtonType.secondary
            ? BorderSide(color: Theme.of(context).colorScheme.primary)
            : null,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.radiusSmall),
        ),
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 18),
          if (icon != null) const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );

    return btn;
  }
}

enum ButtonType { primary, secondary, text, danger, success }

/// ------------------------------
/// Search Bar Widget
/// ------------------------------
class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onFilter;
  final String placeholder;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClear,
    this.onFilter,
    this.placeholder = "Search...",
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: placeholder,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: onClear,
              ),
            if (onFilter != null)
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: onFilter,
              ),
          ],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}

/// ------------------------------
/// Financial Summary Widget
/// ------------------------------
class FinancialSummary extends StatelessWidget {
  final double borrowed;
  final double paid;

  const FinancialSummary({
    super.key,
    required this.borrowed,
    required this.paid,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final outstanding = borrowed - paid;
    final percent =(borrowed > 0 ? paid / borrowed : 0).toDouble() ;

    return CustomCard(
      title: l10n.summary,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FinancialAmount(amount: borrowed, isDebt: true, prefix: "${l10n.borrowed}: "),
              FinancialAmount(amount: paid, isDebt: false, prefix: "${l10n.paid}: "),
              FinancialAmount(amount: outstanding, isDebt: true, prefix: "${l10n.outstanding}: "),
            ],
          ),
          const SizedBox(height: AppThemes.spacing16),
          LinearProgressIndicator(value: percent),
        ],
      ),
    );
  }
}

/// ------------------------------
/// Transaction List Item Widget
/// ------------------------------
class TransactionListItem extends StatelessWidget {
  final String description;
  final double amount;
  final DateTime date;
  final bool isDebt;

  const TransactionListItem({
    super.key,
    required this.description,
    required this.amount,
    required this.date,
    this.isDebt = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(isDebt ? Icons.arrow_upward : Icons.arrow_downward,
          color: AppThemes.getFinancialColor(context, isDebt)),
      title: Text(description),
      subtitle: Text(DateFormat.yMMMd().format(date)),
      trailing: FinancialAmount(amount: amount, isDebt: isDebt),
    );
  }
}

/// ------------------------------
/// Empty State Widget
/// ------------------------------
class EmptyState extends StatelessWidget {
  final String message;
  final String description;
  final IconData icon;
  final String? buttonText;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.message,
    required this.description,
    required this.icon,
    this.buttonText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: AppThemes.spacing16),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppThemes.spacing8),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          if (buttonText != null && onAction != null) ...[
            const SizedBox(height: AppThemes.spacing16),
            CustomButton(text: buttonText!, onPressed: onAction!),
          ]
        ],
      ),
    );
  }
}

/// ------------------------------
/// Loading Widget
/// ------------------------------
class LoadingWidget extends StatelessWidget {
  final String? message;

  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: AppThemes.spacing16),
            Text(message!),
          ]
        ],
      ),
    );
  }
}

/// ------------------------------
/// Status Badge Widget
/// ------------------------------
class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeType type;

  const StatusBadge({super.key, required this.text, required this.type});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (type) {
      case BadgeType.success:
        color = AppThemes.successColor;
        break;
      case BadgeType.warning:
        color = AppThemes.warningColor;
        break;
      case BadgeType.error:
        color = AppThemes.debtColor;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}

enum BadgeType { success, warning, error }

/// ------------------------------
/// Tab Navigation Widget
/// ------------------------------
class TabNavigationWidget extends StatelessWidget {
  final List<Tab> tabs;
  final List<Widget> views;

  const TabNavigationWidget({super.key, required this.tabs, required this.views});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(tabs: tabs),
          Expanded(child: TabBarView(children: views)),
        ],
      ),
    );
  }
}


class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GoogleSignInButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      icon:FaIcon(FontAwesomeIcons.google),
      label: Text(
        AppLocalizations.of(context)!.signInWithGoogle,
        style: const TextStyle(fontSize: 16),
      ),
      onPressed: onPressed,
    );
  }
}