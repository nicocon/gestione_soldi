import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    try {
      tz.setLocalLocation(tz.getLocation('Europe/Rome'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('NOTIFICA CLICCATA: ${response.payload}');
      },
    );

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await initialize();

    if (kIsWeb) return false;

    if (Platform.isIOS || Platform.isMacOS) {
      final iosPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      return granted ?? false;
    }

    if (Platform.isAndroid) {
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final granted = await androidPlugin?.requestNotificationsPermission();

      return granted ?? false;
    }

    return false;
  }

  Future<void> showTestNotification() async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'pocketplan_test_channel',
      'Test PocketPlan',
      channelDescription: 'Notifiche di test di PocketPlan',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id: 1,
      title: 'PocketPlan è pronto ✅',
      body: 'Le notifiche sono attive correttamente.',
      notificationDetails: details,
      payload: 'test_notification',
    );
  }

  Future<void> showAiInsightNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'pocketplan_ai_insights',
      'Consigli AI PocketPlan',
      channelDescription: 'Notifiche per consigli finanziari generati dall’AI',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final cleanedBody = body.length > 120 ? '${body.substring(0, 120)}...' : body;

    await _notifications.show(
      id: id,
      title: title,
      body: cleanedBody,
      notificationDetails: details,
      payload: 'ai_insight_$id',
    );
  }

  Future<void> scheduleExpenseReminder({
    required int id,
    required String title,
    required double amount,
    required DateTime scheduledDate,
  }) async {
    await initialize();

    final now = DateTime.now();

    if (scheduledDate.isBefore(now)) return;

    final notificationDate = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    const androidDetails = AndroidNotificationDetails(
      'pocketplan_expense_reminders',
      'Promemoria spese',
      channelDescription: 'Promemoria per le spese in scadenza',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id: id,
      title: 'Spesa in scadenza',
      body: '$title: ${amount.toStringAsFixed(2).replaceAll('.', ',')}€ da pagare.',
      scheduledDate: notificationDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'expense_reminder_$id',
    );
  }

  Future<void> cancelNotification(int id) async {
    await initialize();

    await _notifications.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    await initialize();

    await _notifications.cancelAll();
  }
}