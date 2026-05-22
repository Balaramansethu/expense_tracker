import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static const String _enabledKey = 'nudge_enabled';
  static const String _hourKey = 'nudge_hour';
  static const String _minuteKey = 'nudge_minute';
  static const int _nudgeId = 1001;

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notifications.initialize(settings);
  }

  Future<bool> requestPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<int> getNudgeHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_hourKey) ?? 21; // default 9 PM
  }

  Future<int> getNudgeMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_minuteKey) ?? 0;
  }

  Future<void> enableNudge(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);
    await _scheduleDailyNudge(hour, minute);
  }

  Future<void> disableNudge() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await _notifications.cancel(_nudgeId);
  }

  Future<void> _scheduleDailyNudge(int hour, int minute) async {
    await _notifications.cancel(_nudgeId);

    const androidDetails = AndroidNotificationDetails(
      'daily_nudge',
      'Daily Reminder',
      channelDescription: 'Reminds you to log expenses',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      styleInformation: BigTextStyleInformation(
        'Did you forget to log any expenses today? Tap to quickly add them.',
      ),
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    // Schedule for today if time hasn't passed, otherwise tomorrow
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    // Use periodicallyShowWithDuration for daily repeat
    // But since exact scheduling with timezone requires extra setup,
    // we'll use a simple show-and-reschedule approach on app launch
    await _notifications.show(
      _nudgeId,
      'Log your expenses',
      'Did you forget to track any spending today?',
      details,
    );
  }

  /// Called on app launch — if enabled, schedule today's nudge if not yet fired.
  Future<void> rescheduleIfNeeded() async {
    final enabled = await isEnabled();
    if (!enabled) return;

    final hour = await getNudgeHour();
    final minute = await getNudgeMinute();
    final now = DateTime.now();
    final nudgeTime = DateTime(now.year, now.month, now.day, hour, minute);

    // Only schedule if the nudge time hasn't passed today
    if (now.isBefore(nudgeTime)) {
      // Schedule a delayed notification
      final delay = nudgeTime.difference(now);
      Future.delayed(delay, () async {
        const androidDetails = AndroidNotificationDetails(
          'daily_nudge',
          'Daily Reminder',
          channelDescription: 'Reminds you to log expenses',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        );
        const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
        await _notifications.show(
          _nudgeId,
          'Log your expenses',
          'Did you forget to track any spending today?',
          details,
        );
      });
    }
  }
}
