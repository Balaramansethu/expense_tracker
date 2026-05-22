import 'package:flutter/material.dart';
import '../controllers/expense_controller.dart';
import '../models/expense.dart';

class QuickTapSheet extends StatefulWidget {
  final ExpenseController controller;

  const QuickTapSheet({super.key, required this.controller});

  @override
  State<QuickTapSheet> createState() => _QuickTapSheetState();
}

class _QuickTapSheetState extends State<QuickTapSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  Category _category = Category.other;
  bool _saving = false;

  ExpenseController get ctrl => widget.controller;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);

    final desc = _noteCtrl.text.trim().isEmpty
        ? _category.displayName
        : _noteCtrl.text.trim();

    await ctrl.saveExpense(
      amount: amount,
      description: desc,
      category: _category,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Amount field — big and centered
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                ),
                prefixText: '\$ ',
                prefixStyle: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 8),

            // Category chips — single row, scrollable
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: Category.values.map((cat) {
                  final isSelected = cat == _category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(cat.displayName),
                      avatar: Icon(cat.icon, size: 15, color: isSelected ? Colors.white : cat.color),
                      selected: isSelected,
                      selectedColor: cat.color,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) => setState(() => _category = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),

            // Quick note — optional, small
            TextField(
              controller: _noteCtrl,
              textCapitalization: TextCapitalization.sentences,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Quick note (optional)',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),

            // Save button — full width
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check, size: 20),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
