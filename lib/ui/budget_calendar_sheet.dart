import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/expense_controller.dart';
import '../models/budget.dart';
import 'set_budget_sheet.dart';

class BudgetCalendarSheet extends StatefulWidget {
  final ExpenseController controller;

  const BudgetCalendarSheet({super.key, required this.controller});

  @override
  State<BudgetCalendarSheet> createState() => _BudgetCalendarSheetState();
}

class _BudgetCalendarSheetState extends State<BudgetCalendarSheet> {
  Budget? _budget;
  Map<DateTime, double> _dailySpending = {};
  double _totalSpent = 0;
  bool _loading = true;

  ExpenseController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final budget = await ctrl.getActiveBudget();
    Map<DateTime, double> daily = {};
    double totalSpent = 0;

    if (budget != null) {
      // End date is inclusive, so add 1 day for the query range
      final queryEnd = budget.endDate.add(const Duration(days: 1));
      daily = await ctrl.getDailySpending(budget.startDate, queryEnd);
      totalSpent = daily.values.fold(0.0, (a, b) => a + b);
    }

    if (mounted) {
      setState(() {
        _budget = budget;
        _dailySpending = daily;
        _totalSpent = totalSpent;
        _loading = false;
      });
    }
  }

  void _openSetBudget() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SetBudgetSheet(controller: ctrl, existing: _budget),
    ).then((result) {
      if (result == true) _loadData();
    });
  }

  Future<void> _deleteBudget() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Budget'),
        content: const Text('Remove the current budget limit?'),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ctrl.deleteBudget();
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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
          Text('Budget & Spending', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else if (_budget == null)
            _buildNoBudget(theme)
          else
            Flexible(child: _buildBudgetView(theme)),
        ],
      ),
    );
  }

  Widget _buildNoBudget(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Icon(
          Icons.savings_outlined,
          size: 56,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
        ),
        const SizedBox(height: 16),
        Text(
          'No budget set',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set a monthly budget to track your spending\nand see a daily breakdown on the calendar.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _openSetBudget,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Set Budget'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetView(ThemeData theme) {
    final budget = _budget!;
    final remaining = budget.amount - _totalSpent;
    final progress = budget.amount > 0
        ? (_totalSpent / budget.amount).clamp(0.0, 1.0)
        : 0.0;
    final isOverBudget = _totalSpent > budget.amount;
    final dateFormat = DateFormat('dd MMM');

    // Progress bar color
    Color progressColor;
    if (progress < 0.6) {
      progressColor = Colors.green;
    } else if (progress < 0.85) {
      progressColor = Colors.amber.shade700;
    } else {
      progressColor = theme.colorScheme.error;
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Budget summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Budget',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      '\$${budget.amount.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(progressColor),
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spent',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '\$${_totalSpent.toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isOverBudget ? 'Over by' : 'Remaining',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          isOverBudget
                              ? '\$${(-remaining).toStringAsFixed(2)}'
                              : '\$${remaining.toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isOverBudget
                                ? theme.colorScheme.error
                                : Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${dateFormat.format(budget.startDate)} – ${dateFormat.format(budget.endDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Calendar
          _buildCalendar(theme, budget),
          const SizedBox(height: 16),

          // Legend
          _buildLegend(theme),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _deleteBudget,
                  icon: Icon(Icons.delete_outline, size: 16, color: theme.colorScheme.error),
                  label: Text(
                    'Remove',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _openSetBudget,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Budget'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(ThemeData theme, Budget budget) {
    final start = budget.startDate;
    final end = budget.endDate;
    final totalDays = end.difference(start).inDays + 1;
    final dailyBudget = budget.amount / totalDays;

    // Calendar starts from the Monday of the week containing start date
    // weekday: 1=Mon, 7=Sun
    final calStart = start.subtract(Duration(days: (start.weekday - 1)));
    // Calendar ends at the Sunday of the week containing end date
    final calEnd = end.add(Duration(days: (7 - end.weekday)));
    final totalCalDays = calEnd.difference(calStart).inDays + 1;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        // Header label
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Daily Spending',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Day labels
        Row(
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),

        // Calendar grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.85,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: totalCalDays,
          itemBuilder: (context, index) {
            final date = calStart.add(Duration(days: index));
            final day = DateTime(date.year, date.month, date.day);
            final isInRange = !day.isBefore(start) && !day.isAfter(end);
            final isToday = day == today;
            final spent = _dailySpending[day] ?? 0;
            final hasSpending = spent > 0;

            // Color based on spending relative to daily budget
            Color cellColor;
            Color textColor;
            if (!isInRange) {
              cellColor = Colors.transparent;
              textColor = theme.colorScheme.onSurface.withValues(alpha: 0.15);
            } else if (!hasSpending) {
              cellColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
              textColor = theme.colorScheme.onSurface.withValues(alpha: 0.4);
            } else if (spent <= dailyBudget * 0.8) {
              cellColor = Colors.green.withValues(alpha: 0.15);
              textColor = Colors.green.shade800;
            } else if (spent <= dailyBudget * 1.2) {
              cellColor = Colors.amber.withValues(alpha: 0.2);
              textColor = Colors.amber.shade900;
            } else {
              cellColor = theme.colorScheme.error.withValues(alpha: 0.15);
              textColor = theme.colorScheme.error;
            }

            return Container(
              decoration: BoxDecoration(
                color: cellColor,
                borderRadius: BorderRadius.circular(8),
                border: isToday
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isInRange
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  if (isInRange && hasSpending) ...[
                    const SizedBox(height: 1),
                    Text(
                      '\$${_formatCompact(spent)}',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLegend(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(Colors.green.withValues(alpha: 0.3), 'Under', theme),
        const SizedBox(width: 16),
        _legendDot(Colors.amber.withValues(alpha: 0.4), 'Near limit', theme),
        const SizedBox(width: 16),
        _legendDot(theme.colorScheme.error.withValues(alpha: 0.3), 'Over', theme),
      ],
    );
  }

  Widget _legendDot(Color color, String label, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatCompact(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(0);
  }
}
