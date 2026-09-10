import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/productivity/domain/models/aether_task.dart';
import '../../features/wallet/domain/models/aether_subscription.dart';
import '../../features/wallet/domain/models/aether_budget.dart';
import '../../features/wallet/domain/models/aether_transaction.dart';
import '../../features/wallet/domain/utils/aether_currency.dart';

// Unified Global Notification Engine
class GlobalNotificationEngine {
  static final GlobalNotificationEngine _instance = GlobalNotificationEngine._internal();
  factory GlobalNotificationEngine() => _instance;
  GlobalNotificationEngine._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(settings: initSettings);

    // 🌟 Explicit Android Channel Setup & Permission Check
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();

      // High-importance notification channels for Android
      const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
        'immediate_alerts',
        'Critical Alerts & Budget Warnings',
        description: 'Instant alerts for budget limits, system reminders, and high priority notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      const AndroidNotificationChannel walletChannel = AndroidNotificationChannel(
        'wallet_channel',
        'Smart Assistant',
        description: 'Daily and weekly financial assistant insights',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      const AndroidNotificationChannel taskChannel = AndroidNotificationChannel(
        'task_channel',
        'Tasks & Reminders',
        description: 'Scheduled reminders for your tasks',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      const AndroidNotificationChannel habitChannel = AndroidNotificationChannel(
        'habit_channel',
        'Habit Routines',
        description: 'Scheduled reminders for your habits and routines',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await androidImplementation.createNotificationChannel(alertChannel);
      await androidImplementation.createNotificationChannel(walletChannel);
      await androidImplementation.createNotificationChannel(taskChannel);
      await androidImplementation.createNotificationChannel(habitChannel);
    }

    _isInitialized = true;
  }

  int _createUniqueId(String identifier) {
    return (identifier.hashCode ^ math.Random().nextInt(10000)).abs() % 2147483647;
  }

  // 🌟 APP-OPEN GREETING & TEST NOTIFICATION 🌟
  Future<void> showAppOpenGreeting() async {
    await init();
    String username = "Buddy";
    try {
      final box = Hive.box('aether_settings');
      username = box.get('username', defaultValue: 'Buddy') as String;
    } catch (e) {
      // fallback
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'immediate_alerts',
      'Critical Alerts & Budget Warnings',
      channelDescription: 'Instant alerts for budget limits, system reminders, and high priority notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id: 777,
      title: '✨ Welcome to Aether OS, $username!',
      body: '🔔 Daily Reminder: Capture your thoughts, complete habits, or log today\'s expenses.',
      notificationDetails: platformDetails,
    );
  }

  // 🌟 1. PRODUCTIVITY ALERTS 🌟
  Future<void> scheduleTaskReminder(AetherTask task) async {
    if (task.dueDate == null || task.isCompleted) return;
    DateTime scheduledDate = task.dueDate!;
    if (task.reminderOffsetMinutes > 0) {
      scheduledDate = scheduledDate.subtract(Duration(minutes: task.reminderOffsetMinutes));
    }
    if (scheduledDate.isBefore(DateTime.now())) return;

    final id = task.id.hashCode.abs() % 2147483647;
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_channel',
      'Tasks & Reminders',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      color: Color(0xFF38BDF8),
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: 'Task Reminder: ${task.title}',
      body: task.description.isNotEmpty ? task.description : 'Your scheduled task is due.',
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> scheduleTaskNotification({required int id, required String title, required String body, required DateTime scheduledDate}) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_channel',
      'Tasks & Reminders',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      color: Color(0xFF38BDF8),
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelReminder(String taskId) async {
    int baseId = taskId.hashCode.abs() % 2147483647;
    await _notificationsPlugin.cancel(id: baseId);
    await _notificationsPlugin.cancel(id: (baseId + 1) % 2147483647);
  }

  Future<void> cancelTaskNotification(String taskId) async {
    int baseId = taskId.hashCode.abs() % 2147483647;
    await _notificationsPlugin.cancel(id: baseId);
    await _notificationsPlugin.cancel(id: (baseId + 1) % 2147483647);
  }

  Future<void> scheduleDailyHabitReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String soundFile = 'default.wav',
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'habit_channel',
      'Habit Routines',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      color: Color(0xFFFBBF60),
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) scheduledDate = scheduledDate.add(const Duration(days: 1));

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleHabitRemindersFromStringList(String habitId, String title, List<String> reminders) async {
    await cancelHabitReminders(habitId, reminders.length);
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'habit_channel',
      'Habit Routines',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      color: Color(0xFFFBBF60),
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    final now = tz.TZDateTime.now(tz.local);

    for (int i = 0; i < reminders.length; i++) {
      final reminderStr = reminders[i];
      final parts = reminderStr.split(':');
      if (parts.length < 2) continue;
      int hour = int.tryParse(parts[0].trim()) ?? 9;
      int minute = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '').trim()) ?? 0;
      if (reminderStr.toUpperCase().contains('PM') && hour < 12) hour += 12;
      if (reminderStr.toUpperCase().contains('AM') && hour == 12) hour = 0;

      var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) scheduledDate = scheduledDate.add(const Duration(days: 1));

      await _notificationsPlugin.zonedSchedule(
        id: _createUniqueId('$habitId#$i'),
        title: "Time for your habit!",
        body: title,
        scheduledDate: scheduledDate,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> scheduleHabitReminders(String habitId, String title, List<int> reminderDays, TimeOfDay reminderTime) async {
    await cancelHabitReminders(habitId, reminderDays.length);
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'habit_channel',
      'Habit Routines',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      color: Color(0xFFFBBF60),
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    final now = tz.TZDateTime.now(tz.local);

    for (int i = 0; i < reminderDays.length; i++) {
      int targetDay = reminderDays[i];
      var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, reminderTime.hour, reminderTime.minute);
      while (scheduledDate.weekday != targetDay) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
      if (scheduledDate.isBefore(now)) scheduledDate = scheduledDate.add(const Duration(days: 7));

      await _notificationsPlugin.zonedSchedule(
        id: _createUniqueId('$habitId#$i'),
        title: "Time for your habit!",
        body: title,
        scheduledDate: scheduledDate,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancelHabitReminders(String habitId, [int? count]) async {
    int limit = count != null ? math.max(count, 7) : 7;
    for (int i = 0; i < limit; i++) {
      await _notificationsPlugin.cancel(id: _createUniqueId('$habitId#$i'));
    }
  }

  Future<void> triggerImmediateAlert(String title, String body, {int? id}) async {
    await init();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'immediate_alerts',
      'Critical Alerts & Budget Warnings',
      channelDescription: 'Instant alerts for budget limits, system reminders, and high priority notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      color: Color(0xFFFB7185),
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    
    int notifId = id ?? (title.hashCode ^ math.Random().nextInt(1000)).abs() % 2147483647;
    await _notificationsPlugin.show(
      id: notifId,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }

  // 🌟 2. SUBSCRIPTION REMINDERS 🌟
  Future<void> scheduleSubscriptionAlerts(AetherSubscription sub) async {
    if (sub.nextDueDate.isBefore(DateTime.now())) return;
    int notifId = sub.id.hashCode.abs() % 2147483647;
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'subscription_channel',
      'Subscriptions',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      color: Color(0xFF34F5C5),
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    DateTime alertDate = sub.nextDueDate.subtract(const Duration(days: 1));
    if (alertDate.isBefore(DateTime.now())) alertDate = sub.nextDueDate;
    if (alertDate.isBefore(DateTime.now())) return;

    await _notificationsPlugin.zonedSchedule(
      id: notifId,
      title: 'Upcoming Subscription: ${sub.name}',
      body: 'Your subscription of ${AetherCurrency.format(sub.amount)} is due soon.',
      scheduledDate: tz.TZDateTime.from(alertDate, tz.local),
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // 🌟 3. BUDGET LIMIT AUDIT & OVERBUDGET ALERTS 🌟
  Future<void> checkAndAlertOverbudgets(List<AetherBudget> budgets, List<AetherTransaction> transactions) async {
    final now = DateTime.now();

    for (var b in budgets) {
      if (!b.isActive) continue;

      double spent = 0.0;
      for (var t in transactions) {
        if (t.type != 'expense') continue;
        bool matchesCategory = (b.category == 'Global') || (b.category == t.category);
        if (!matchesCategory) continue;

        DateTime cDate = DateTime(b.createdAt.year, b.createdAt.month, b.createdAt.day);
        DateTime nDate = DateTime(now.year, now.month, now.day);
        DateTime cycleStart = cDate;
        DateTime cycleEnd = cDate;

        if (!nDate.isBefore(cDate)) {
          if (b.period == 'Weekly') {
            int days = nDate.difference(cDate).inDays;
            int cycles = days ~/ 7;
            cycleStart = cDate.add(Duration(days: cycles * 7));
            cycleEnd = cycleStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
          } else if (b.period == 'Yearly') {
            int cycles = nDate.year - cDate.year;
            DateTime testDate = DateTime(cDate.year + cycles, cDate.month, cDate.day);
            if (nDate.isBefore(testDate)) cycles--;
            cycleStart = DateTime(cDate.year + cycles, cDate.month, cDate.day);
            cycleEnd = DateTime(cycleStart.year + 1, cycleStart.month, cycleStart.day).subtract(const Duration(seconds: 1));
          } else {
            int cycles = (nDate.year - cDate.year) * 12 + (nDate.month - cDate.month);
            DateTime testDate = DateTime(cDate.year, cDate.month + cycles, cDate.day);
            if (nDate.isBefore(testDate)) cycles--;
            cycleStart = DateTime(cDate.year, cDate.month + cycles, cDate.day);
            cycleEnd = DateTime(cycleStart.year, cycleStart.month + 1, cycleStart.day).subtract(const Duration(seconds: 1));
          }
        }

        bool inPeriod = !t.date.isBefore(cycleStart) && !t.date.isAfter(cycleEnd);
        if (inPeriod && (b.includePastTransactions || !t.date.isBefore(b.createdAt))) {
          spent += (t.amount * t.exchangeRate);
        }
      }

      final budgetName = (b.name != null && b.name!.trim().isNotEmpty) ? b.name! : b.category;
      if (spent > b.limitAmount) {
        final overAmount = spent - b.limitAmount;
        await triggerImmediateAlert(
          "🚨 Overbudget Alert: $budgetName",
          "You exceeded your $budgetName budget by ${AetherCurrency.format(overAmount)}! Total spent: ${AetherCurrency.format(spent)} of ${AetherCurrency.format(b.limitAmount)} limit.",
          id: b.id.hashCode.abs() % 2147483647,
        );
      } else if (b.limitAmount > 0 && spent >= b.limitAmount * 0.8) {
        final remaining = b.limitAmount - spent;
        await triggerImmediateAlert(
          "⚠️ Budget Warning: $budgetName",
          "You reached ${(spent / b.limitAmount * 100).toStringAsFixed(0)}% of your $budgetName budget! Only ${AetherCurrency.format(remaining)} left.",
          id: b.id.hashCode.abs() % 2147483647,
        );
      }
    }
  }

  // 🌟 4. THE 10 SMART WALLET BACKGROUND SCENARIOS 🌟
  Future<void> scheduleAllSmartWalletAlerts() async {
    String username = "Buddy"; 
    try {
      final box = Hive.box('aether_settings');
      username = box.get('username', defaultValue: 'Buddy') as String;
    } catch (e) { /* fallback */ }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'wallet_channel',
      'Smart Assistant',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      color: Color(0xFF34F5C5),
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    final now = tz.TZDateTime.now(tz.local);

    Future<void> scheduleDaily(int id, String title, String body, int hour, int minute) async {
      var date = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (date.isBefore(now)) date = date.add(const Duration(days: 1));
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: date,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    Future<void> scheduleWeekly(int id, String title, String body, int weekday, int hour, int minute) async {
      var date = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      while (date.weekday != weekday) { date = date.add(const Duration(days: 1)); }
      if (date.isBefore(now)) date = date.add(const Duration(days: 7));
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: date,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }

    Future<void> scheduleMonthly(int id, String title, String body, int dayOfMonth, int hour, int minute) async {
      var date = tz.TZDateTime(tz.local, now.year, now.month, dayOfMonth, hour, minute);
      if (date.isBefore(now)) date = tz.TZDateTime(tz.local, now.year, now.month + 1, dayOfMonth, hour, minute);
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: date,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }

    await scheduleDaily(101, "Evening Check-in 🌙", "Hi $username, it's 11 PM! Take a minute to log today's spending.", 23, 0);
    await scheduleDaily(102, "Morning Overview ☀️", "Good morning $username! Plan your day and review your budget limits.", 9, 0);
    await scheduleDaily(103, "Keep the Streak Alive 🔥", "Hey $username, did you complete your daily habits today? Update them now!", 19, 0);
    await scheduleWeekly(104, "Weekly Report Ready 📊", "Your financial & productivity summary for last week is ready, $username.", DateTime.monday, 10, 0);
    await scheduleWeekly(105, "Weekend Mode 🎉", "The weekend is here $username! Keep an eye on your fun & dining budget.", DateTime.friday, 18, 0);
    await scheduleWeekly(106, "Savings Check 💰", "Hey $username, take a moment to look at your saving goals. You're doing great!", DateTime.sunday, 11, 0);
    await scheduleMonthly(107, "Mid-Month Check-in ⚖️", "We're halfway through the month! Are you on track with your budget?", 15, 12, 0);
    await scheduleMonthly(108, "Month-End Review 📅", "The month is ending soon. Review your remaining budget to finish strong!", 28, 10, 0);
    await scheduleMonthly(109, "Upcoming Bills 🧾", "A new month has started $username. Make sure your subscriptions and bills are sorted.", 1, 8, 0);
    await scheduleWeekly(110, "Mid-Week Motivation 🚀", "You're doing amazing $username! Keep pushing towards your goals.", DateTime.wednesday, 14, 0);
  }
}