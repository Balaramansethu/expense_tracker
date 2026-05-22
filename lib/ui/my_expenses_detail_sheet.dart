import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/expense_controller.dart';
import '../models/expense.dart';

class MyExpensesDetailSheet extends StatefulWidget {
  final ExpenseController controller;

  const MyExpensesDetailSheet({super.key, required this.controller});

  @override
  State<MyExpensesDetailSheet> createState() => _MyExpensesDetailSheetState();
}

class _MyExpensesDetailSheetState extends State<MyExpensesDetailSheet> {
  List<Expense> _allExpenses = [];
  double _total = 0;
  double _splitDeducted = 0;
  Map<Category, double> _categoryBreakdown = {};
  bool _loading = true;

  ExpenseController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final expenses = await ctrl.getAllExpenses();
    final totalExpenses = await ctrl.getTotalExpenses();
    final myShare = await ctrl.getMyActualShare();
    final breakdown = <Category, double>{};
    double total = 0;

    for (final e in expenses) {
      total += e.amount;
      breakdown[e.category] = (breakdown[e.category] ?? 0) + e.amount;
    }

    if (mounted) {
      setState(() {
        _allExpenses = expenses;
        _total = total;
        _splitDeducted = totalExpenses - myShare;
        _categoryBreakdown = breakdown;
        _loading = false;
      });
    }
  }

  Future<void> _clearAllExpenses() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Expenses'),
        content: const Text(
          'This will permanently delete ALL your expenses and split records.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ctrl.clearAllExpenses();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('My Expense Detail', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else if (_allExpenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 48,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No expenses recorded yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Total banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Total Spent',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${_total.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (_splitDeducted > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '- \$${_splitDeducted.toStringAsFixed(2)} split to others',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
                      child: Divider(
                        height: 1,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                      ),
                    ),
                    Text(
                      'Your Net Expense',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${(_total - _splitDeducted).toStringAsFixed(2)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${_allExpenses.length} transactions',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Category breakdown
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: _categoryBreakdown.entries.map((entry) {
                  final cat = entry.key;
                  final amount = entry.value;
                  final percent = (_total > 0) ? (amount / _total * 100) : 0;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat.icon, size: 14, color: cat.color),
                      const SizedBox(width: 4),
                      Text(
                        '${cat.displayName} \$${amount.toStringAsFixed(0)} (${percent.toStringAsFixed(0)}%)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Expense list header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'All Transactions',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Expense list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _allExpenses.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                ),
                itemBuilder: (context, index) {
                  final expense = _allExpenses[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        // Category icon
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: expense.category.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            expense.category.icon,
                            size: 18,
                            color: expense.category.color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Description + date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense.description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateFormat.format(expense.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Amount
                        Text(
                          '\$${expense.amount.toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Clear all button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clearAllExpenses,
                icon: Icon(Icons.delete_sweep, size: 18, color: theme.colorScheme.error),
                label: Text(
                  'Clear All Expenses',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
