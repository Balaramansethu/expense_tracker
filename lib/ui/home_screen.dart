import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../controllers/expense_controller.dart';
import '../models/expense.dart';
import 'voice_sheet.dart';
import 'quick_tap_sheet.dart';
import 'split_sheet.dart';
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
    // Normalize empty string to null for consistent checking
    String? imagePath = (expense.imagePath != null && expense.imagePath!.isNotEmpty)
        ? expense.imagePath
        : null;
    final imagePicker = ImagePicker();

    Future<void> pickReceiptInSheet(StateSetter setSheetState) async {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;

      final picked = await imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final receiptDir = Directory(p.join(appDir.path, 'receipts'));
      if (!receiptDir.existsSync()) receiptDir.createSync();
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = p.join(receiptDir.path, fileName);
      await File(picked.path).copy(savedPath);

      setSheetState(() => imagePath = savedPath);
    }

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
            final theme = Theme.of(context);
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
              child: SingleChildScrollView(
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
                    Text('Edit Expense', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 20),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    const SizedBox(height: 12),

                    // Receipt section
                    if (imagePath != null)
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _showReceiptFullscreen(imagePath!),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(imagePath!),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Receipt attached',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => pickReceiptInSheet(setSheetState),
                            icon: Icon(Icons.swap_horiz, size: 18, color: theme.colorScheme.primary),
                            tooltip: 'Change',
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            onPressed: () => setSheetState(() => imagePath = null),
                            icon: Icon(Icons.close, size: 18, color: theme.colorScheme.error),
                            tooltip: 'Remove',
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => pickReceiptInSheet(setSheetState),
                          icon: Icon(Icons.camera_alt, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                          label: Text(
                            'Attach receipt',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Action buttons: Split + Cancel + Update
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final amount = double.tryParse(amountCtrl.text);
                              final desc = descCtrl.text.trim();
                              if (amount == null || amount <= 0 || desc.isEmpty) return;
                              // Update the expense first, then split
                              ctrl.updateExpense(expense.copyWith(
                                amount: amount,
                                description: desc,
                                category: category,
                                imagePath: imagePath ?? '',
                              ));
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: theme.colorScheme.surface,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                builder: (_) => SplitSheet(
                                  controller: ctrl,
                                  amount: amount,
                                  description: desc,
                                  category: category,
                                  existingExpenseId: expense.id,
                                ),
                              );
                            },
                            icon: const Icon(Icons.call_split, size: 18),
                            label: const Text('Split'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () {
                              final amount = double.tryParse(amountCtrl.text);
                              final desc = descCtrl.text.trim();
                              if (amount == null || amount <= 0 || desc.isEmpty) return;

                              ctrl.updateExpense(expense.copyWith(
                                amount: amount,
                                description: desc,
                                category: category,
                                imagePath: imagePath ?? '',
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

  void _showReceiptFullscreen(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('Could not load image', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
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
