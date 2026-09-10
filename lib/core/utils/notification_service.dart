import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings: settings);
    
    _isInitialized = true;
  }

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      final bool? granted = await androidImplementation?.requestNotificationsPermission();
      return granted ?? true; 
    }
    return true; 
  }

  Future<void> scheduleDailyReminder() async {
    await init();
    
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('Notification permission denied by Android.');
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_journal_channel',
      'Daily Reminders',
      channelDescription: 'Reminds you to write your daily reflection',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.zonedSchedule(
      id: 0, 
      title: 'How are you feeling?', 
      body: 'Take a moment to secure your thoughts in the vault.', 
      scheduledDate: _nextInstanceOfTime(20, 0), 
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, 
    );
  }

  Future<void> cancelAllReminders() async {
    await _localNotifications.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}