import 'package:flutter/material.dart';
import '../controllers/expense_controller.dart';
import '../models/expense.dart';
import '../models/person.dart';

class SplitSheet extends StatefulWidget {
  final ExpenseController controller;
  final double amount;
  final String description;
  final Category category;
  final int? existingExpenseId;

  const SplitSheet({
    super.key,
    required this.controller,
    required this.amount,
    required this.description,
    required this.category,
    this.existingExpenseId,
  });

  @override
  State<SplitSheet> createState() => _SplitSheetState();
}

class _SplitSheetState extends State<SplitSheet> {
  // Tracks which people are selected and their custom amounts
  final Map<int, TextEditingController> _amountControllers = {};
  final Set<int> _selectedIds = {};

  ExpenseController get ctrl => widget.controller;

  double get _othersTotal {
    double sum = 0;
    for (final id in _selectedIds) {
      final text = _amountControllers[id]?.text ?? '';
      sum += double.tryParse(text) ?? 0;
    }
    return sum;
  }

  double get _yourPart => widget.amount - _othersTotal;

  bool get _isValid {
    if (_selectedIds.isEmpty) return false;
    if (_othersTotal <= 0) return false;
    if (_othersTotal > widget.amount) return false;
    return true;
  }

  @override
  void dispose() {
    for (final c in _amountControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _togglePerson(Person person) {
    setState(() {
      if (_selectedIds.contains(person.id!)) {
        _selectedIds.remove(person.id!);
        _amountControllers[person.id!]?.clear();
      } else {
        _selectedIds.add(person.id!);
        _amountControllers.putIfAbsent(
          person.id!,
          () => TextEditingController(),
        );
      }
    });
  }

  Future<void> _splitAndSave() async {
    if (!_isValid) return;

    final splits = <Person, double>{};
    final people = ctrl.people;

    for (final id in _selectedIds) {
      final amount = double.tryParse(_amountControllers[id]?.text ?? '') ?? 0;
      if (amount > 0) {
        final person = people.firstWhere((p) => p.id == id);
        splits[person] = amount;
      }
    }

    if (splits.isEmpty) return;

    if (widget.existingExpenseId != null) {
      // Adding splits to an existing expense (from edit dialog)
      await ctrl.addSplitsToExpense(
        expenseId: widget.existingExpenseId!,
        totalAmount: widget.amount,
        description: widget.description,
        category: widget.category,
        splits: splits,
      );
    } else {
      // Creating a new expense with splits (from voice/quick-tap)
      await ctrl.saveSplitExpense(
        amount: widget.amount,
        description: widget.description,
        category: widget.category,
        splits: splits,
      );
    }

    if (mounted) {
      Navigator.pop(context); // close split sheet
      Navigator.pop(context); // close parent sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final people = ctrl.people;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
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
            Text('Split Expense', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            // Expense info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.category.icon, size: 18, color: widget.category.color),
                  const SizedBox(width: 8),
                  Text(
                    widget.description,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '\$${widget.amount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // People list with amount inputs
            if (people.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No people added yet.\nGo back and add people first.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: people.length,
                  itemBuilder: (context, index) {
                    final person = people[index];
                    final isSelected = _selectedIds.contains(person.id!);
                    _amountControllers.putIfAbsent(
                      person.id!,
                      () => TextEditingController(),
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.12),
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(alpha: 0.05)
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Checkbox + name
                            GestureDetector(
                              onTap: () => _togglePerson(person),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (_) => _togglePerson(person),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.primaryContainer,
                                    child: Text(
                                      person.name[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : theme.colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    person.name,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // Amount input (only visible when selected)
                            if (isSelected)
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: _amountControllers[person.id!],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    prefixText: '\$ ',
                                    prefixStyle: theme.textTheme.bodyMedium,
                                    hintText: '0',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),

            // Summary card
            if (_selectedIds.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _yourPart >= 0
                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                      : theme.colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryItem(
                      theme,
                      'Others',
                      '\$${_othersTotal.toStringAsFixed(2)}',
                      theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                    _summaryItem(
                      theme,
                      'Your part',
                      '\$${_yourPart.toStringAsFixed(2)}',
                      _yourPart >= 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ],
                ),
              ),

            // Over-split warning
            if (_othersTotal > widget.amount) ...[
              const SizedBox(height: 8),
              Text(
                'Split amounts exceed the total!',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
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
                    onPressed: _isValid ? _splitAndSave : null,
                    icon: const Icon(Icons.call_split, size: 18),
                    label: const Text('Split & Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(ThemeData theme, String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
