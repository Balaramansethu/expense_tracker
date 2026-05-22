import 'package:flutter/material.dart';
import '../controllers/expense_controller.dart';
import '../models/person.dart';
import 'my_expenses_detail_sheet.dart';
import 'person_tab_sheet.dart';

class ProfileDrawer extends StatefulWidget {
  final ExpenseController controller;

  const ProfileDrawer({super.key, required this.controller});

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  double _totalExpenses = 0;
  double _myActualShare = 0;
  Map<int, double> _balances = {};
  bool _loading = true;

  ExpenseController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final total = await ctrl.getTotalExpenses();
    final myShare = await ctrl.getMyActualShare();
    final balances = await ctrl.getAllBalances();
    if (mounted) {
      setState(() {
        _totalExpenses = total;
        _myActualShare = myShare;
        _balances = balances;
        _loading = false;
      });
    }
  }

  Future<void> _clearTab(Person person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Tab'),
        content: Text(
          'Settle up with ${person.name}? This will clear all split records.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ctrl.clearPersonTab(person.id!);
      await _loadData();
    }
  }

  void _openPersonTab(Person person) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PersonTabSheet(controller: ctrl, person: person),
    ).whenComplete(() => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final people = ctrl.people;
    final othersOwe = _totalExpenses - _myActualShare;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
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
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primary,
                child: const Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('My Profile', style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 20),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else ...[
            // Summary cards
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    theme,
                    'Total Expenses',
                    '\$${_totalExpenses.toStringAsFixed(2)}',
                    theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    theme,
                    'My Actual Share',
                    '\$${_myActualShare.toStringAsFixed(2)}',
                    theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (othersOwe > 0) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '- \$${othersOwe.toStringAsFixed(2)} split to others',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: othersOwe > 0
                    ? Colors.green.withValues(alpha: 0.08)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                othersOwe > 0
                    ? 'Others owe you \$${othersOwe.toStringAsFixed(2)}'
                    : 'No outstanding splits',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: othersOwe > 0 ? Colors.green.shade700 : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),

            // My Expense Detail button
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => MyExpensesDetailSheet(controller: ctrl),
                  ).whenComplete(() => _loadData());
                },
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text('My Expense Detail'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Balances section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Balances',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),

            if (people.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No people added yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
                    final balance = _balances[person.id] ?? 0.0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: balance > 0
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : theme.colorScheme.surfaceContainerHighest,
                        child: Text(
                          person.name[0].toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: balance > 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      title: Text(person.name),
                      subtitle: Text(
                        balance > 0
                            ? 'Owes you \$${balance.toStringAsFixed(2)}'
                            : 'Settled',
                        style: TextStyle(
                          color: balance > 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                      trailing: balance > 0
                          ? TextButton(
                              onPressed: () => _clearTab(person),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text(
                                'Clear',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : null,
                      onTap: () => _openPersonTab(person),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _statCard(ThemeData theme, String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
