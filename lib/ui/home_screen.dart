import 'dart:io';
import 'package:flutter/material.dart';
import '../controllers/expense_controller.dart';
import '../models/expense.dart';
import 'voice_sheet.dart';
import 'quick_tap_sheet.dart';
import 'people_sheet.dart';
import 'profile_drawer.dart';
import 'widgets/summary_header.dart';
import 'widgets/expense_tile.dart';
import 'widgets/insights_card.dart';

class HomeScreen extends StatefulWidget {
  final ExpenseController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ExpenseController get ctrl => widget.controller;

  void _openVoiceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => VoiceSheet(controller: ctrl),
    ).whenComplete(() {
      ctrl.stopAndCleanup();
    });
  }

  void _openQuickTap() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => QuickTapSheet(controller: ctrl),
    );
  }

  void _openProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ProfileDrawer(controller: ctrl),
    );
  }

  void _openPeopleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PeopleSheet(controller: ctrl),
    );
  }

  void _showEditDialog(Expense expense) {
    final amountCtrl = TextEditingController(
      text: expense.amount.toStringAsFixed(2),
    );
    final descCtrl = TextEditingController(text: expense.description);
    var category = expense.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text('Edit Expense',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 20),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: Category.values.map((cat) {
                      final isSelected = cat == category;
                      return ChoiceChip(
                        label: Text(cat.displayName),
                        avatar: Icon(cat.icon,
                            size: 16,
                            color: isSelected ? Colors.white : cat.color),
                        selected: isSelected,
                        selectedColor: cat.color,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontSize: 12,
                        ),
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) =>
                            setSheetState(() => category = cat),
                      );
                    }).toList(),
                  ),
                  // Receipt image
                  if (expense.imagePath != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(expense.imagePath!),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
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
                        child: FilledButton(
                          onPressed: () {
                            final amount =
                                double.tryParse(amountCtrl.text);
                            final desc = descCtrl.text.trim();
                            if (amount == null ||
                                amount <= 0 ||
                                desc.isEmpty) return;

                            ctrl.updateExpense(expense.copyWith(
                              amount: amount,
                              description: desc,
                              category: category,
                            ));
                            Navigator.pop(context);
                          },
                          child: const Text('Update'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _onDeleteExpense(Expense expense) {
    ctrl.deleteExpense(expense);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${expense.description}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: ctrl.undoDelete,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final grouped = ctrl.groupedExpenses;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Top bar with Profile + People buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _openProfile,
                        icon: CircleAvatar(
                          radius: 16,
                          backgroundColor: theme.colorScheme.primary,
                          child: const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        onPressed: _openPeopleSheet,
                        icon: const Icon(Icons.people_outline, size: 18),
                        label: Text(
                          ctrl.people.isEmpty
                              ? 'Add People'
                              : 'People (${ctrl.people.length})',
                        ),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: grouped.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildExpenseList(theme, grouped),
                ),
              ],
            ),
          ),
          floatingActionButton: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quick-tap button
              FloatingActionButton.small(
                heroTag: 'quick',
                onPressed: _openQuickTap,
                child: const Icon(Icons.add, size: 22),
              ),
              const SizedBox(width: 12),
              // Voice button (primary)
              FloatingActionButton(
                heroTag: 'voice',
                onPressed: _openVoiceSheet,
                child: const Icon(Icons.mic),
              ),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Column(
      children: [
        SummaryHeader(
          year: ctrl.currentYear,
          month: ctrl.currentMonth,
          total: ctrl.monthlyTotal,
          summary: ctrl.monthlySummary,
          onPrevious: ctrl.previousMonth,
          onNext: ctrl.nextMonth,
          canGoNext: ctrl.canGoNext,
        ),
        const Spacer(),
        Icon(
          Icons.mic_none,
          size: 64,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
        ),
        const SizedBox(height: 16),
        Text(
          'No expenses yet',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap the mic to add your first expense',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildExpenseList(
      ThemeData theme, Map<String, List<Expense>> grouped) {
    final sections = grouped.entries.toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SummaryHeader(
            year: ctrl.currentYear,
            month: ctrl.currentMonth,
            total: ctrl.monthlyTotal,
            summary: ctrl.monthlySummary,
            onPrevious: ctrl.previousMonth,
            onNext: ctrl.nextMonth,
            canGoNext: ctrl.canGoNext,
          ),
        ),
        SliverToBoxAdapter(
          child: InsightsCard(controller: ctrl),
        ),
        for (final section in sections) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Text(
                section.key,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => ExpenseTile(
                expense: section.value[index],
                onDelete: _onDeleteExpense,
                onTap: _showEditDialog,
              ),
              childCount: section.value.length,
            ),
          ),
        ],
        // Bottom padding for FAB
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }
}
