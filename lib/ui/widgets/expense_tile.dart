import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final void Function(Expense) onDelete;
  final void Function(Expense) onTap;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(expense),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
      ),
      child: ListTile(
        onTap: () => onTap(expense),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: expense.category.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            expense.category.icon,
            color: expense.category.color,
            size: 20,
          ),
        ),
        title: Text(
          expense.description,
          style: theme.textTheme.bodyLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              DateFormat.jm().format(expense.createdAt),
              style: theme.textTheme.bodySmall,
            ),
            if (expense.imagePath != null && expense.imagePath!.isNotEmpty) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.receipt,
                size: 13,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ],
          ],
        ),
        trailing: Text(
          NumberFormat.currency(symbol: '\$').format(expense.amount),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
