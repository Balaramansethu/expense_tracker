import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../controllers/expense_controller.dart';
import '../models/expense.dart';
import 'split_sheet.dart';


class VoiceSheet extends StatefulWidget {
  final ExpenseController controller;

  const VoiceSheet({super.key, required this.controller});

  @override
  State<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<VoiceSheet> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isManualMode = false;

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  Category _selectedCategory = Category.other;

  ExpenseController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    ctrl.addListener(_onControllerUpdate);

    // Start listening immediately when sheet opens
    if (!_isManualMode) {
      ctrl.startListening();
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    // Sync parsed preview to text fields
    final preview = ctrl.parsedPreview;
    if (preview != null && !_isManualMode) {
      _amountController.text = preview.amount.toStringAsFixed(2);
      _descriptionController.text = preview.description;
      _selectedCategory = preview.category;
    }
    setState(() {});
  }

  @override
  void dispose() {
    ctrl.removeListener(_onControllerUpdate);
    // Stop speech when sheet is dismissed
    ctrl.stopAndCleanup();
    _pulseController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _switchToManual() {
    ctrl.cancelVoiceInput();
    setState(() => _isManualMode = true);
  }

  void _retryVoice() {
    ctrl.clearError();
    setState(() => _isManualMode = false);
    ctrl.startListening();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text);
    final description = _descriptionController.text.trim();

    if (amount == null || amount <= 0 || description.isEmpty) return;

    await ctrl.saveExpense(
      amount: amount,
      description: description,
      category: _selectedCategory,
    );

    if (mounted) Navigator.of(context).pop();
  }

  void _openSplit() {
    final amount = double.tryParse(_amountController.text);
    final description = _descriptionController.text.trim();

    if (amount == null || amount <= 0 || description.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SplitSheet(
        controller: ctrl,
        amount: amount,
        description: description,
        category: _selectedCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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

            if (_isManualMode)
              _buildManualForm(theme)
            else
              _buildVoiceFlow(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceFlow(ThemeData theme) {
    final isListening = ctrl.isListening;
    final hasPreview = ctrl.parsedPreview != null && !isListening;
    final transcript = ctrl.liveTranscript;
    final hasError = ctrl.errorMessage != null;
    final isPermissionDenied = ctrl.permissionDenied;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mic animation — only pulse when actually listening
        if ((isListening || transcript.isEmpty) && !hasError) ...[
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = isListening ? 1.0 + _pulseController.value * 0.15 : 1.0;
              final opacity = isListening ? 0.3 + _pulseController.value * 0.3 : 0.15;
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: opacity),
                ),
                child: Transform.scale(
                  scale: scale,
                  child: Icon(
                    Icons.mic,
                    size: 36,
                    color: isListening
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            isListening ? 'Listening...' : 'Say something like "spent 50 on lunch"',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],

        // Error state
        if (hasError) ...[
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.error.withValues(alpha: 0.1),
            ),
            child: Icon(
              isPermissionDenied ? Icons.mic_off : Icons.error_outline,
              size: 36,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            ctrl.errorMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (isPermissionDenied)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Open Settings'),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: _retryVoice,
                  child: const Text('Retry'),
                ),
              ],
            )
          else
            FilledButton.tonalIcon(
              onPressed: _retryVoice,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
            ),
        ],

        // Live transcript
        if (transcript.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              transcript,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ],

        // Preview card (when parsing is done)
        if (hasPreview) ...[
          const SizedBox(height: 20),
          _buildPreviewCard(theme),
        ],

        const SizedBox(height: 20),

        // Action buttons
        if (hasPreview)
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _retryVoice,
                      child: const Text('Try Again'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openSplit,
                  icon: const Icon(Icons.call_split, size: 18),
                  label: const Text('Split'),
                ),
              ),
            ],
          )
        else if (isListening)
          FilledButton.tonalIcon(
            onPressed: ctrl.stopListening,
            icon: const Icon(Icons.stop, size: 18),
            label: const Text('Done'),
          ),

        // Show "no expense detected" when transcript exists but no preview and not listening
        if (!isListening && transcript.isNotEmpty && !hasPreview && !hasError) ...[
          const SizedBox(height: 8),
          Text(
            'Could not detect an expense. Try again or add manually.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _retryVoice,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try Again'),
          ),
        ],

        const SizedBox(height: 8),
        TextButton(
          onPressed: _switchToManual,
          child: Text(
            'Add manually',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Amount
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              prefixText: '\$ ',
              prefixStyle: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          // Description
          TextField(
            controller: _descriptionController,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Description',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          // Category chips
          _buildCategoryChips(theme),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(ThemeData theme) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: Category.values.map((cat) {
        final isSelected = cat == _selectedCategory;
        return ChoiceChip(
          label: Text(cat.displayName),
          avatar: Icon(cat.icon, size: 16, color: isSelected ? Colors.white : cat.color),
          selected: isSelected,
          selectedColor: cat.color,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : null,
            fontSize: 12,
          ),
          visualDensity: VisualDensity.compact,
          onSelected: (_) => setState(() => _selectedCategory = cat),
        );
      }).toList(),
    );
  }

  Widget _buildManualForm(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Add Expense', style: theme.textTheme.titleMedium),
        const SizedBox(height: 20),
        TextField(
          controller: _amountController,
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
          controller: _descriptionController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          onChanged: (text) {
            // Auto-detect category as user types
            setState(() {
              _selectedCategory = _categorizeFromInput(text);
            });
          },
        ),
        const SizedBox(height: 12),
        _buildCategoryChips(theme),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _retryVoice,
                icon: const Icon(Icons.mic, size: 18),
                label: const Text('Voice'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openSplit,
                icon: const Icon(Icons.call_split, size: 18),
                label: const Text('Split'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Category _categorizeFromInput(String text) {
    if (text.isEmpty) return _selectedCategory;
    final lower = text.toLowerCase();
    for (final cat in Category.values) {
      if (cat == Category.other) continue;
      for (final keyword in cat.keywords) {
        if (lower.contains(keyword)) return cat;
      }
    }
    return _selectedCategory;
  }
}
