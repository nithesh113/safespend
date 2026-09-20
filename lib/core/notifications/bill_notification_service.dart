import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:safespend/core/utils/currency_formatter.dart';
import 'package:safespend/shared/models/category.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class BillNotificationService {
  BillNotificationService._();

  static final instance = BillNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  void Function(String? payload)? _onTap;

  Future<void> initialize({void Function(String? payload)? onTap}) async {
    if (_initialized) return;
    _onTap = onTap;
    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (error) {
      debugPrint('Could not resolve device timezone: $error');
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) =>
          _onTap?.call(response.payload),
    );
    const channel = AndroidNotificationChannel(
      'bill_reminders',
      'Bill reminders',
      description: 'Reminders for recurring bills',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? true;
  }

  Future<void> syncBills(List<Category> categories) async {
    if (!_initialized) return;
    for (final category in categories.where(
      (category) => category.isFixedBill,
    )) {
      await cancelBill(category.id!);
      if (category.archived ||
          !category.enabled ||
          !category.reminderEnabled ||
          (category.expectedMonthlyAmount ?? 0) <= 0) {
        continue;
      }
      await scheduleBill(category);
    }
  }

  Future<void> scheduleBill(Category bill) async {
    if (!_initialized || bill.id == null) return;
    final now = tz.TZDateTime.now(tz.local);
    for (var offset = 0; offset < 12; offset++) {
      final monthStart = DateTime(now.year, now.month + offset, 1);
      final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0).day;
      final dueDay = bill.dueDay.clamp(1, lastDay);
      final dueDate = tz.TZDateTime(
        tz.local,
        monthStart.year,
        monthStart.month,
        dueDay,
        9,
      );
      final reminderDate = dueDate.subtract(const Duration(days: 1));
      if (!reminderDate.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: notificationId(bill.id!, offset),
        title: '${bill.name} is due tomorrow',
        body: formatCurrency(bill.expectedMonthlyAmount ?? 0),
        scheduledDate: reminderDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'bill_reminders',
            'Bill reminders',
            channelDescription: 'Reminders for recurring bills',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '/bills',
      );
    }
  }

  Future<void> cancelBill(int categoryId) async {
    if (!_initialized) return;
    for (var offset = 0; offset < 12; offset++) {
      await _plugin.cancel(id: notificationId(categoryId, offset));
    }
  }

  static int notificationId(int categoryId, int monthOffset) =>
      categoryId * 100 + monthOffset + 1;

  static String reminderDateLabel(Category bill) {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final day = bill.dueDay.clamp(1, lastDay);
    final due = DateTime(now.year, now.month, day);
    return DateFormat('MMM d').format(due.subtract(const Duration(days: 1)));
  }
}
