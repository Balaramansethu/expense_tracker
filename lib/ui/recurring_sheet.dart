import 'package:flutter/material.dart';
import '../controllers/expense_controller.dart';
import '../models/expense.dart';
import '../models/recurring_expense.dart';

class RecurringSheet extends StatefulWidget {
  final ExpenseController controller;

  const RecurringSheet({super.key, required this.controller});

  @override
  State<RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends State<RecurringSheet> {
  ExpenseController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    ctrl.loadRecurring();
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddRecurringSheet(controller: ctrl),
    ).then((_) => setState(() {}));
  }

  Future<void> _deleteRecurring(RecurringExpense r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recurring'),
        content: Text('Remove "${r.description}" from recurring expenses?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ctrl.deleteRecurring(r.id!);
      setState(() {});
    }
  }

  Future<void> _toggleActive(RecurringExpense r) async {
    await ctrl.updateRecurring(r.copyWith(isActive: !r.isActive));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recurring = ctrl.recurringExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Expenses'),
        actions: [
          FilledButton.tonalIcon(
            onPressed: _openAddSheet,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: recurring.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
                  const SizedBox(height: 12),
                  Text(
                    'No recurring expenses yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add rent, subscriptions, bills — they\'ll be\nautomatically logged every month.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'Auto-logged on the specified day each month',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ...List.generate(recurring.length, (index) {
                  final r = recurring[index];
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: r.isActive
                                ? r.category.color.withValues(alpha: 0.12)
                                : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            r.category.icon,
                            size: 20,
                            color: r.isActive
                                ? r.category.color
                                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                        title: Text(
                          r.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: r.isActive ? null : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            decoration: r.isActive ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text(
                          'Every month on the ${_ordinal(r.dayOfMonth)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\$${r.amount.toStringAsFixed(2)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: r.isActive ? null : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              iconSize: 20,
                              onSelected: (value) {
                                if (value == 'toggle') _toggleActive(r);
                                if (value == 'delete') _deleteRecurring(r);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(r.isActive ? 'Pause' : 'Resume'),
                                ),
                                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (index < recurring.length - 1)
                        Divider(
                          height: 1,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                        ),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Monthly auto-total: \$${recurring.where((r) => r.isActive).fold(0.0, (sum, r) => sum + r.amount).toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1: return '${day}st';
      case 2: return '${day}nd';
      case 3: return '${day}rd';
      default: return '${day}th';
    }
  }
}

class _AddRecurringSheet extends StatefulWidget {
  final ExpenseController controller;
  const _AddRecurringSheet({required this.controller});

  @override
  State<_AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends State<_AddRecurringSheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  Category _category = Category.bills;
  int _dayOfMonth = 1;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    final desc = _descCtrl.text.trim();
    if (amount == null || amount <= 0 || desc.isEmpty) return;

    await widget.controller.addRecurring(
      amount: amount,
      description: desc,
      category: _category,
      dayOfMonth: _dayOfMonth,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('Add Recurring Expense', style: theme.textTheme.titleMedium),
          const SizedBox(height: 20),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description (e.g. Rent, Netflix)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Day of month:', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _dayOfMonth,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: List.generate(28, (i) => i + 1)
                      .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                      .toList(),
                  onChanged: (v) => setState(() => _dayOfMonth = v ?? 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: Category.values.map((cat) {
              final isSelected = cat == _category;
              return ChoiceChip(
                label: Text(cat.displayName),
                avatar: Icon(cat.icon, size: 16, color: isSelected ? Colors.white : cat.color),
                selected: isSelected,
                selectedColor: cat.color,
                labelStyle: TextStyle(color: isSelected ? Colors.white : null, fontSize: 12),
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _category = cat),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.repeat, size: 18),
                  label: const Text('Add Recurring'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
