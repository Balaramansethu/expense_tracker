import 'package:flutter/material.dart';
import '../../controllers/expense_controller.dart';

class InsightsCard extends StatefulWidget {
  final ExpenseController controller;

  const InsightsCard({super.key, required this.controller});

  @override
  State<InsightsCard> createState() => _InsightsCardState();
}

class _InsightsCardState extends State<InsightsCard> {
  List<String> _insights = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    final insights = await widget.controller.generateInsights();
    if (mounted) {
      setState(() {
        _insights = insights;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _insights.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
            theme.colorScheme.tertiaryContainer.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                'Insights',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < _insights.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u2022 ',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                Expanded(
                  child: Text(
                    _insights[i],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
