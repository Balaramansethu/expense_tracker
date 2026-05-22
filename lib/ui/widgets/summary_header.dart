import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';

class SummaryHeader extends StatelessWidget {
  final int year;
  final int month;
  final double total;
  final Map<Category, double> summary;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canGoNext;

  const SummaryHeader({
    super.key,
    required this.year,
    required this.month,
    required this.total,
    required this.summary,
    required this.onPrevious,
    required this.onNext,
    required this.canGoNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthName = DateFormat.MMMM().format(DateTime(year, month));
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
              ),
              Text(
                isCurrentMonth ? monthName : '$monthName $year',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: canGoNext ? onNext : null,
                icon: const Icon(Icons.chevron_right),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Total
          Text(
            NumberFormat.currency(symbol: '\$').format(total),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Stacked bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: summary.entries.map((entry) {
                    final fraction = total > 0 ? entry.value / total : 0.0;
                    return Expanded(
                      flex: (fraction * 1000).round().clamp(1, 1000),
                      child: Container(color: entry.key.color),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: summary.entries.map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: entry.key.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.key.displayName} ${NumberFormat.compactCurrency(symbol: '\$').format(entry.value)}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
