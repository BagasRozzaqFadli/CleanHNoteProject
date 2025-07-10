import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  // final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  //     FlutterLocalNotificationsPlugin();

  NotificationService._() {
    // _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    tz_data.initializeTimeZones();

    // Kode inisialisasi notifikasi dikomentari
    // const AndroidInitializationSettings initializationSettingsAndroid =
    //     AndroidInitializationSettings('@mipmap/ic_launcher');

    // final DarwinInitializationSettings initializationSettingsIOS =
    //     DarwinInitializationSettings(
    //   requestSoundPermission: true,
    //   requestBadgePermission: true,
    //   requestAlertPermission: true,
    //   onDidReceiveLocalNotification: (int id, String? title, String? body, String? payload) async {
    //     // Handle iOS notification
    //   },
    // );

    // final InitializationSettings initializationSettings = InitializationSettings(
    //   android: initializationSettingsAndroid,
    //   iOS: initializationSettingsIOS,
    // );

    // await _flutterLocalNotificationsPlugin.initialize(
    //   initializationSettings,
    //   onDidReceiveNotificationResponse: (NotificationResponse response) {
    //     // Handle notification tap
    //   },
    // );
  }

  // Menjadwalkan notifikasi untuk tugas - dinonaktifkan sementara
  Future<void> scheduleTaskNotification(TaskModel task) async {
    // Implementasi dinonaktifkan sementara
    debugPrint('Notifikasi untuk tugas ${task.title} tidak dijadwalkan karena fitur dinonaktifkan');
  }

  // Membatalkan notifikasi untuk tugas - dinonaktifkan sementara
  Future<void> cancelTaskNotifications(TaskModel task) async {
    // Implementasi dinonaktifkan sementara
    debugPrint('Pembatalan notifikasi untuk tugas ${task.title} tidak diperlukan karena fitur dinonaktifkan');
  }

  // Membatalkan semua notifikasi - dinonaktifkan sementara
  Future<void> cancelAllNotifications() async {
    // Implementasi dinonaktifkan sementara
    debugPrint('Pembatalan semua notifikasi tidak diperlukan karena fitur dinonaktifkan');
  }

  // Menampilkan notifikasi langsung - dinonaktifkan sementara
  Future<void> showInstantNotification(String title, String body) async {
    // Implementasi dinonaktifkan sementara
    debugPrint('Notifikasi langsung "$title: $body" tidak ditampilkan karena fitur dinonaktifkan');
  }
}