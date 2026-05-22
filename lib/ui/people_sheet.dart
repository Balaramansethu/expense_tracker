import 'package:flutter/material.dart';
import '../controllers/expense_controller.dart';
import '../models/person.dart';
import 'person_tab_sheet.dart';

class PeopleSheet extends StatefulWidget {
  final ExpenseController controller;

  const PeopleSheet({super.key, required this.controller});

  @override
  State<PeopleSheet> createState() => _PeopleSheetState();
}

class _PeopleSheetState extends State<PeopleSheet> {
  final _nameController = TextEditingController();
  Map<int, double> _balances = {};

  ExpenseController get ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _loadBalances();
    ctrl.addListener(_onUpdate);
  }

  @override
  void dispose() {
    ctrl.removeListener(_onUpdate);
    _nameController.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (!mounted) return;
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    final balances = await ctrl.getAllBalances();
    if (mounted) {
      setState(() => _balances = balances);
    }
  }

  Future<void> _addPerson() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await ctrl.addPerson(name);
    _nameController.clear();
    await _loadBalances();
  }

  void _openPersonTab(Person person) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PersonTabSheet(controller: ctrl, person: person),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final people = ctrl.people;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
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
            Text('People', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),

            // Add person input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Person name',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _addPerson(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _addPerson,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // People list
            if (people.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No people added yet.\nAdd someone to start splitting expenses.',
                  textAlign: TextAlign.center,
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
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          person.name[0].toUpperCase(),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(person.name),
                      subtitle: balance > 0
                          ? Text(
                              'Owes you \$${balance.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : Text(
                              'No splits yet',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error.withValues(alpha: 0.7),
                        ),
                        onPressed: () => ctrl.removePerson(person.id!),
                      ),
                      onTap: () => _openPersonTab(person),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
