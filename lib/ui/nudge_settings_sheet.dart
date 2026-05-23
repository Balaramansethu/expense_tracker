import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NudgeSettingsSheet extends StatefulWidget {
  const NudgeSettingsSheet({super.key});

  @override
  State<NudgeSettingsSheet> createState() => _NudgeSettingsSheetState();
}

class _NudgeSettingsSheetState extends State<NudgeSettingsSheet> {
  final _notif = NotificationService();
  bool _enabled = false;
  int _hour = 21;
  int _minute = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _notif.isEnabled();
    final hour = await _notif.getNudgeHour();
    final minute = await _notif.getNudgeMinute();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _hour = hour;
        _minute = minute;
        _loading = false;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      final granted = await _notif.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permission denied')),
          );
        }
        return;
      }
      await _notif.enableNudge(_hour, _minute);
    } else {
      await _notif.disableNudge();
    }
    setState(() => _enabled = value);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked == null) return;

    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
    });

    if (_enabled) {
      await _notif.enableNudge(_hour, _minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = TimeOfDay(hour: _hour, minute: _minute).format(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Reminders'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                Text(
                  'Get a gentle daily reminder to log your expenses.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Enable toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: const Text('Daily reminder'),
                    subtitle: Text(
                      _enabled ? 'Enabled — $timeStr' : 'Disabled',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: _enabled,
                    contentPadding: EdgeInsets.zero,
                    onChanged: _toggle,
                  ),
                ),
                const SizedBox(height: 16),

                // Time picker (only when enabled)
                if (_enabled)
                  InkWell(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Reminder time', style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                )),
                                Text(
                                  timeStr,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'You\'ll get one notification per day — never spammy. '
                    'Just a gentle nudge to keep your tracking consistent.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }
}
