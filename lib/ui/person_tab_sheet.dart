import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/expense_controller.dart';
import '../models/person.dart';
import '../models/split.dart';

class PersonTabSheet extends StatefulWidget {
  final ExpenseController controller;
  final Person person;

  const PersonTabSheet({
    super.key,
    required this.controller,
    required this.person,
  });

  @override
  State<PersonTabSheet> createState() => _PersonTabSheetState();
}

class _PersonTabSheetState extends State<PersonTabSheet> {
  List<SplitEntry> _splits = [];
  double _balance = 0;
  bool _loading = true;

  ExpenseController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final splits = await ctrl.getSplitsForPerson(widget.person.id!);
    final balance = await ctrl.getPersonBalance(widget.person.id!);
    if (mounted) {
      setState(() {
        _splits = splits;
        _balance = balance;
        _loading = false;
      });
    }
  }

  void _exportReport() {
    final report = ctrl.generateReport(widget.person, _splits, _balance);
    Share.share(report, subject: 'Split Report: ${widget.person.name}');
  }

  Future<void> _clearTab() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Tab'),
        content: Text(
          'Settle up with ${widget.person.name}? This will clear all split records.\n\nThis action cannot be undone.',
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
            child: const Text('Clear Tab'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ctrl.clearPersonTab(widget.person.id!);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.person.name}'s Tab"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                // Balance summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _balance > 0
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _balance > 0
                            ? '${widget.person.name} owes you'
                            : 'All settled up',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${_balance.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _balance > 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Splits list
                if (_splits.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No splits with ${widget.person.name} yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  )
                else
                  ...List.generate(_splits.length, (index) {
                    final split = _splits[index];
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      split.description,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateFormat.format(split.createdAt),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${split.totalAmount.toStringAsFixed(2)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  Text(
                                    '\$${split.splitAmount.toStringAsFixed(2)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (index < _splits.length - 1)
                          Divider(
                            height: 1,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                          ),
                      ],
                    );
                  }),

                const SizedBox(height: 24),

                // Action buttons
                if (_splits.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _clearTab,
                          icon: Icon(Icons.clear_all, size: 18, color: theme.colorScheme.error),
                          label: Text(
                            'Clear Tab',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _exportReport,
                          icon: const Icon(Icons.ios_share, size: 18),
                          label: const Text('Export'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
