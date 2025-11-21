import 'package:flutter/material.dart';

class TransactionTile extends StatelessWidget {
  final String debtor;
  final String amount;
  final String date;
  final IconData icon;
  final Color color;

  const TransactionTile({
    super.key,
    required this.debtor,
    required this.amount,
    required this.date,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(debtor, style: theme.textTheme.bodyLarge),
      subtitle: Text(date, style: theme.textTheme.bodySmall),
      trailing: Text(
        amount,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
