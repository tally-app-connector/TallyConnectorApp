// ─────────────────────────────────────────────────────────────────────────────
// Local Notification Service
// ─────────────────────────────────────────────────────────────────────────────
//
// This service handles all local push notifications for the Tally Connector app.
// It supports:
//   - Immediate notifications (show right now)
//   - Scheduled notifications (show at a specific date/time)
//   - Daily repeating notifications (e.g., every day at 9:00 AM)
//   - Weekly repeating notifications (e.g., every Monday at 10:00 AM)
//   - Cancel individual or all notifications
//
// Platform support:
//   - Android / iOS / macOS / Linux → flutter_local_notifications
//   - Windows                       → local_notifier (Windows toast notifications)
//
// No Firebase or internet connection required — everything runs locally.
//
// Usage:
//   await LocalNotificationService.init();       // Call once in main()
//   await LocalNotificationService.showNow(...); // Show immediately
//   await LocalNotificationService.scheduleDaily(...); // Repeat daily
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class LocalNotificationService {
  // ── Mobile/macOS/Linux plugin instance ────────────────────────────────────
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── Notification channel details (Android) ────────────────────────────────
  // Android requires a "channel" for grouping notifications.
  // Users can control each channel independently in system settings.
  static const String _channelId = 'tally_connector_channel';
  static const String _channelName = 'Tally Connector Notifications';
  static const String _channelDescription =
      'Notifications for sync reminders, reports, and alerts';

  // ── Platform flags ────────────────────────────────────────────────────────
  // flutter_local_notifications supports Android, iOS, macOS, Linux
  static bool get _isMobileSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isLinux;

  // local_notifier supports Windows desktop toast notifications
  static bool get _isWindows => Platform.isWindows;

  // ── Windows scheduled timers ──────────────────────────────────────────────
  // On Windows, scheduled notifications use in-memory timers.
  // NOTE: These only fire while the app is running. For persistent scheduling
  // on Windows, a background service or native task scheduler would be needed.
  static final Map<int, Timer> _windowsTimers = {};

  // ── Callback when user taps on a notification ─────────────────────────────
  // You can customize this to navigate to a specific screen.
  static void Function(String? payload)? onNotificationTap;

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALIZE — must be called once before using any other method
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    // ── Windows initialization ────────────────────────────────────────────
    if (_isWindows) {
      // Initialize local_notifier for Windows toast notifications
      await localNotifier.setup(
        appName: 'Tally Connector',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      debugPrint('[Notification] Windows notification service initialized');
      return;
    }

    // ── Mobile / macOS / Linux initialization ─────────────────────────────
    if (!_isMobileSupported) {
      debugPrint('[Notification] Skipped — platform not supported');
      return;
    }

    // Initialize timezone database so we can schedule at exact local times
    tz_data.initializeTimeZones();

    // ── Android settings ──────────────────────────────────────────────────
    // '@mipmap/ic_launcher' uses the app icon as the notification icon.
    // You can replace this with a custom drawable if needed.
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // ── iOS / macOS settings ──────────────────────────────────────────────
    // requestAlertPermission: show alert banners
    // requestBadgePermission: update app badge count
    // requestSoundPermission: play notification sound
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // ── Combine platform settings ─────────────────────────────────────────
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    // ── Initialize the plugin with a tap handler ──────────────────────────
    await _plugin.initialize(
      initSettings,
      // Called when user taps on a notification
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[Notification] Tapped — payload: ${response.payload}');
        // Invoke the callback if set (useful for navigation)
        onNotificationTap?.call(response.payload);
      },
    );

    // ── Request permission on Android 13+ (API 33+) ──────────────────────
    // On older Android versions this is a no-op.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    debugPrint('[Notification] Service initialized successfully');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHOW NOW — display a notification immediately
  // ─────────────────────────────────────────────────────────────────────────
  //
  // Parameters:
  //   id      — unique integer ID (use different IDs for different notifications)
  //   title   — notification title (e.g., "Sync Complete")
  //   body    — notification body text
  //   payload — optional string data passed to tap handler
  //
  // Example:
  //   await LocalNotificationService.showNow(
  //     id: 1,
  //     title: 'Data Synced',
  //     body: 'Your Tally data has been synced successfully!',
  //   );
  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // ── Windows: use local_notifier toast ──────────────────────────────────
    if (_isWindows) {
      _showWindowsNotification(title, body);
      return;
    }

    if (!_isMobileSupported) return;

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high, // Shows as heads-up notification
        priority: Priority.high,
        showWhen: true, // Show timestamp
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(id, title, body, details, payload: payload);
    debugPrint('[Notification] Shown immediately — id: $id, title: $title');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCHEDULE AT — show a notification at a specific date and time (one-time)
  // ─────────────────────────────────────────────────────────────────────────
  //
  // The notification fires once at the given [dateTime] and does not repeat.
  //
  // Parameters:
  //   id       — unique integer ID
  //   title    — notification title
  //   body     — notification body text
  //   dateTime — when to show the notification (must be in the future)
  //   payload  — optional string data passed to tap handler
  //
  // Example:
  //   await LocalNotificationService.scheduleAt(
  //     id: 2,
  //     title: 'Report Due',
  //     body: 'Your monthly Tally report is due today',
  //     dateTime: DateTime(2026, 4, 10, 17, 0), // Apr 10, 5:00 PM
  //   );
  static Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    String? payload,
  }) async {
    // ── Windows: schedule via in-memory timer ─────────────────────────────
    if (_isWindows) {
      final delay = dateTime.difference(DateTime.now());
      if (delay.isNegative) return; // Time already passed
      _windowsTimers[id]?.cancel(); // Cancel existing timer with same ID
      _windowsTimers[id] = Timer(delay, () {
        _showWindowsNotification(title, body);
        _windowsTimers.remove(id);
      });
      debugPrint('[Notification][Windows] Scheduled at $dateTime — id: $id');
      return;
    }

    if (!_isMobileSupported) return;

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    // Convert DateTime to timezone-aware TZDateTime (required by the plugin)
    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(dateTime, tz.local);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      payload: payload,
      // exactAllowWhileIdle ensures the notification fires even in Doze mode
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // Required for iOS — tells the plugin to interpret the time as absolute
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('[Notification] Scheduled at $dateTime — id: $id, title: $title');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCHEDULE DAILY — repeat a notification every day at a fixed time
  // ─────────────────────────────────────────────────────────────────────────
  //
  // The notification fires every day at the specified [hour]:[minute].
  //
  // On Android/iOS: Uses system alarm manager — works even if app is closed.
  // On Windows: Uses in-memory timer — only works while app is running.
  //
  // Parameters:
  //   id     — unique integer ID
  //   title  — notification title
  //   body   — notification body text
  //   hour   — hour in 24-hour format (0-23)
  //   minute — minute (0-59)
  //
  // Example:
  //   await LocalNotificationService.scheduleDaily(
  //     id: 100,
  //     title: 'Tally Sync Reminder',
  //     body: 'Time to sync your Tally data!',
  //     hour: 9,
  //     minute: 0, // Every day at 9:00 AM
  //   );
  static Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    // ── Windows: schedule via repeating timer ──────────────────────────────
    if (_isWindows) {
      _windowsTimers[id]?.cancel();
      // Calculate delay until next occurrence of this time
      final delay = _durationUntilNextTime(hour, minute);
      _windowsTimers[id] = Timer(delay, () {
        _showWindowsNotification(title, body);
        // Reschedule for the next day (repeating)
        _windowsTimers[id] = Timer.periodic(
          const Duration(days: 1),
          (_) => _showWindowsNotification(title, body),
        );
      });
      debugPrint(
          '[Notification][Windows] Daily scheduled at $hour:$minute — id: $id');
      return;
    }

    if (!_isMobileSupported) return;

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // Required for iOS — interpret the time as absolute
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // matchDateTimeComponents.time = repeat every day at same time
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint(
        '[Notification] Daily scheduled at $hour:$minute — id: $id, title: $title');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCHEDULE WEEKLY — repeat a notification on a specific day of the week
  // ─────────────────────────────────────────────────────────────────────────
  //
  // The notification fires once every week on the given [weekday] at
  // [hour]:[minute].
  //
  // On Android/iOS: Uses system alarm manager — works even if app is closed.
  // On Windows: Uses in-memory timer — only works while app is running.
  //
  // Parameters:
  //   id      — unique integer ID
  //   title   — notification title
  //   body    — notification body text
  //   weekday — day of week (1 = Monday, 7 = Sunday, same as DateTime.monday)
  //   hour    — hour in 24-hour format (0-23)
  //   minute  — minute (0-59)
  //
  // Example:
  //   await LocalNotificationService.scheduleWeekly(
  //     id: 200,
  //     title: 'Weekly Review',
  //     body: 'Check your weekly Tally analytics',
  //     weekday: DateTime.monday, // Every Monday
  //     hour: 10,
  //     minute: 0,  // at 10:00 AM
  //   );
  static Future<void> scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int weekday,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    // ── Windows: schedule via repeating timer ──────────────────────────────
    if (_isWindows) {
      _windowsTimers[id]?.cancel();
      final delay = _durationUntilNextWeekday(weekday, hour, minute);
      _windowsTimers[id] = Timer(delay, () {
        _showWindowsNotification(title, body);
        // Reschedule every 7 days (repeating weekly)
        _windowsTimers[id] = Timer.periodic(
          const Duration(days: 7),
          (_) => _showWindowsNotification(title, body),
        );
      });
      debugPrint(
          '[Notification][Windows] Weekly scheduled — weekday: $weekday, $hour:$minute — id: $id');
      return;
    }

    if (!_isMobileSupported) return;

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfWeekday(weekday, hour, minute),
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // Required for iOS — interpret the time as absolute
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // matchDateTimeComponents.dayOfWeekAndTime = repeat every week on same day
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    debugPrint(
        '[Notification] Weekly scheduled — weekday: $weekday, $hour:$minute — id: $id');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CANCEL — remove a scheduled or pending notification by ID
  // ─────────────────────────────────────────────────────────────────────────
  //
  // Example:
  //   await LocalNotificationService.cancel(100); // Cancel daily reminder
  static Future<void> cancel(int id) async {
    if (_isWindows) {
      _windowsTimers[id]?.cancel();
      _windowsTimers.remove(id);
      debugPrint('[Notification][Windows] Cancelled — id: $id');
      return;
    }
    if (!_isMobileSupported) return;
    await _plugin.cancel(id);
    debugPrint('[Notification] Cancelled — id: $id');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CANCEL ALL — remove all scheduled and pending notifications
  // ─────────────────────────────────────────────────────────────────────────
  //
  // Example:
  //   await LocalNotificationService.cancelAll();
  static Future<void> cancelAll() async {
    if (_isWindows) {
      for (final timer in _windowsTimers.values) {
        timer.cancel();
      }
      _windowsTimers.clear();
      debugPrint('[Notification][Windows] All cancelled');
      return;
    }
    if (!_isMobileSupported) return;
    await _plugin.cancelAll();
    debugPrint('[Notification] All notifications cancelled');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET PENDING — list all currently scheduled notifications
  // ─────────────────────────────────────────────────────────────────────────
  //
  // Useful for debugging or showing the user their active reminders.
  // On Windows, returns an empty list (timers are not queryable).
  //
  // Example:
  //   final pending = await LocalNotificationService.getPendingNotifications();
  //   for (final n in pending) {
  //     print('${n.id}: ${n.title}');
  //   }
  static Future<List<PendingNotificationRequest>>
      getPendingNotifications() async {
    if (_isWindows || !_isMobileSupported) return [];
    return await _plugin.pendingNotificationRequests();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS — Windows
  // ═════════════════════════════════════════════════════════════════════════

  // Show a Windows toast notification using local_notifier package.
  // This appears as a native Windows 10/11 toast in the notification center.
  static void _showWindowsNotification(String title, String body) {
    final notification = LocalNotification(
      title: title,
      body: body,
    );
    // Called when user clicks on the Windows toast notification
    notification.onClick = () {
      debugPrint('[Notification][Windows] Clicked — $title');
      onNotificationTap?.call(null);
    };
    notification.show();
    debugPrint('[Notification][Windows] Shown — $title: $body');
  }

  // Calculate Duration from now until the next [hour]:[minute] today or tomorrow.
  static Duration _durationUntilNextTime(int hour, int minute) {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    // If the time already passed today, schedule for tomorrow
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target.difference(now);
  }

  // Calculate Duration from now until the next [weekday] at [hour]:[minute].
  static Duration _durationUntilNextWeekday(
      int weekday, int hour, int minute) {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    // Advance day-by-day until we hit the target weekday
    while (target.weekday != weekday || target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target.difference(now);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS — Mobile (timezone-based scheduling)
  // ═════════════════════════════════════════════════════════════════════════

  // Returns the next occurrence of [hour]:[minute] in local timezone.
  // If that time has already passed today, it returns tomorrow's occurrence.
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time already passed today, move to tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  // Returns the next occurrence of a specific [weekday] at [hour]:[minute].
  // Keeps adding days until we land on the correct weekday.
  static tz.TZDateTime _nextInstanceOfWeekday(
      int weekday, int hour, int minute) {
    tz.TZDateTime scheduled = _nextInstanceOfTime(hour, minute);

    // Advance day-by-day until we hit the target weekday
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }
}
