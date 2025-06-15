import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/task_model.dart';

enum NotificationType {
  taskReminder,
  taskDue,
  teamUpdate,
  system
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final String status; // read, unread
  final DateTime createdAt;
  final String? taskId;
  final String? teamId;
  final DateTime? scheduledFor;
  final bool isDelivered;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.status = 'unread',
    required this.createdAt,
    this.taskId,
    this.teamId,
    this.scheduledFor,
    this.isDelivered = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'notification_type': type.index,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'task_id': taskId,
      'team_id': teamId,
      'scheduled_for': scheduledFor?.toIso8601String(),
      'is_delivered': isDelivered,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          print('Error parsing date: $e');
          return null;
        }
      }
      return null;
    }

    return NotificationModel(
      id: map['id'] ?? map['\$id'] ?? '',
      userId: map['user_id'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: NotificationType.values[map['notification_type'] ?? 0],
      status: map['status'] ?? 'unread',
      createdAt: parseDateTime(map['created_at']) ?? DateTime.now(),
      taskId: map['task_id'],
      teamId: map['team_id'],
      scheduledFor: parseDateTime(map['scheduled_for']),
      isDelivered: map['is_delivered'] ?? false,
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService._() {
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      onDidReceiveLocalNotification: (int id, String? title, String? body, String? payload) async {
        // Handle iOS notification
      },
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );
  }

  // Menjadwalkan notifikasi untuk tugas
  Future<void> scheduleTaskNotification(TaskModel task) async {
    // Jadwalkan notifikasi 1 hari sebelum tenggat waktu
    final notificationTime = task.dueDate.subtract(const Duration(days: 1));
    
    // Jika waktu notifikasi sudah lewat, jangan jadwalkan
    if (notificationTime.isBefore(DateTime.now())) {
      return;
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      task.id.hashCode, // ID unik berdasarkan ID tugas
      'Pengingat Tugas',
      '${task.title} jatuh tempo besok',
      tz.TZDateTime.from(notificationTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminder_channel',
          'Pengingat Tugas',
          channelDescription: 'Notifikasi untuk mengingatkan tenggat waktu tugas',
          importance: Importance.high,
          priority: Priority.high,
          color: Colors.blue,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: task.id,
    );

    // Jadwalkan notifikasi pada hari tenggat waktu
    final dueTimeStr = task.executionTime ?? "09:00";
    final dueTimeParts = dueTimeStr.split(":");
    final dueHour = int.tryParse(dueTimeParts[0]) ?? 9;
    final dueMinute = dueTimeParts.length > 1 ? int.tryParse(dueTimeParts[1]) ?? 0 : 0;
    
    final dueDateTime = DateTime(
      task.dueDate.year,
      task.dueDate.month,
      task.dueDate.day,
      dueHour,
      dueMinute,
    );
    
    // Jadwalkan notifikasi 1 jam sebelum waktu pelaksanaan
    final executionReminderTime = dueDateTime.subtract(const Duration(hours: 1));
    
    if (executionReminderTime.isAfter(DateTime.now())) {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        (task.id + 'execution').hashCode, // ID unik berbeda
        'Tugas Akan Segera Dimulai',
        '${task.title} akan dimulai dalam 1 jam (${dueTimeStr})',
        tz.TZDateTime.from(executionReminderTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_execution_channel',
            'Waktu Pelaksanaan Tugas',
            channelDescription: 'Notifikasi untuk tugas yang akan segera dimulai',
            importance: Importance.high,
            priority: Priority.high,
            color: Colors.orange,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: task.id,
      );
    }

    // Jadwalkan notifikasi pada waktu pelaksanaan
    if (dueDateTime.isAfter(DateTime.now())) {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        (task.id + 'due').hashCode, // ID unik berbeda
        'Waktu Melaksanakan Tugas',
        'Saatnya mengerjakan tugas: ${task.title}',
        tz.TZDateTime.from(dueDateTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_due_channel',
            'Tenggat Tugas',
            channelDescription: 'Notifikasi untuk tugas yang jatuh tempo hari ini',
            importance: Importance.high,
            priority: Priority.high,
            color: Colors.red,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: task.id,
      );
    }
  }

  // Membatalkan notifikasi untuk tugas
  Future<void> cancelTaskNotifications(TaskModel task) async {
    await _flutterLocalNotificationsPlugin.cancel(task.id.hashCode);
    await _flutterLocalNotificationsPlugin.cancel((task.id + 'due').hashCode);
    await _flutterLocalNotificationsPlugin.cancel((task.id + 'execution').hashCode);
  }

  // Membatalkan semua notifikasi
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  // Menampilkan notifikasi langsung
  Future<void> showInstantNotification(String title, String body) async {
    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_channel',
          'Notifikasi Langsung',
          channelDescription: 'Notifikasi yang ditampilkan langsung',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
} 