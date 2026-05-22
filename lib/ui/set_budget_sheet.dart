import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/expense_controller.dart';
import '../models/budget.dart';

class SetBudgetSheet extends StatefulWidget {
  final ExpenseController controller;
  final Budget? existing;

  const SetBudgetSheet({super.key, required this.controller, this.existing});

  @override
  State<SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends State<SetBudgetSheet> {
  late TextEditingController _amountCtrl;
  late DateTime _startDate;
  late DateTime _endDate;
  final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (widget.existing != null) {
      _amountCtrl = TextEditingController(
        text: widget.existing!.amount.toStringAsFixed(2),
      );
      _startDate = widget.existing!.startDate;
      _endDate = widget.existing!.endDate;
    } else {
      _amountCtrl = TextEditingController();
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0); // last day of month
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Auto-adjust end date if start is after end
        if (_startDate.isAfter(_endDate)) {
          _endDate = DateTime(_startDate.year, _startDate.month + 1, 0);
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    await widget.controller.setBudget(amount, _startDate, _endDate);
    if (mounted) Navigator.pop(context, true);
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
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            widget.existing != null ? 'Edit Budget' : 'Set Budget',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 20),

          // Amount
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Budget Amount',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
              hintText: 'e.g. 2000',
            ),
          ),
          const SizedBox(height: 16),

          // Date range
          Row(
            children: [
              Expanded(
                child: _dateField(
                  theme,
                  label: 'Start Date',
                  date: _startDate,
                  onTap: _pickStartDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dateField(
                  theme,
                  label: 'End Date',
                  date: _endDate,
                  onTap: _pickEndDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Duration info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_endDate.difference(_startDate).inDays + 1} days cycle',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),

          // Actions
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
                child: FilledButton(
                  onPressed: _save,
                  child: Text(widget.existing != null ? 'Update' : 'Set Budget'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateField(ThemeData theme, {
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _dateFormat.format(date),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
