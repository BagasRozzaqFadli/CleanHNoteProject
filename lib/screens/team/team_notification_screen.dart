import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/team_service.dart';
import '../../models/team_notification.dart';
import 'team_task_detail_screen.dart';

class TeamNotificationScreen extends StatefulWidget {
  const TeamNotificationScreen({Key? key}) : super(key: key);

  @override
  State<TeamNotificationScreen> createState() => _TeamNotificationScreenState();
}

class _TeamNotificationScreenState extends State<TeamNotificationScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      await teamService.loadUserNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      await teamService.markNotificationAsRead(notificationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamService = Provider.of<TeamService>(context);
    final notifications = teamService.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationList(notifications),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.notifications_off,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Tidak Ada Notifikasi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Anda belum memiliki notifikasi apapun.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(List<TeamNotification> notifications) {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            color: notification.isRead ? null : Colors.blue.shade50,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16.0),
              leading: _getNotificationIcon(notification.notificationType),
              title: Text(
                notification.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(notification.message),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM yyyy, HH:mm').format(notification.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              onTap: () {
                _markAsRead(notification.id);
                _handleNotificationTap(notification);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _getNotificationIcon(String notificationType) {
    switch (notificationType) {
      case 'task_assigned':
        return CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: const Icon(Icons.assignment, color: Colors.blue),
        );
      case 'task_completed':
        return CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: const Icon(Icons.check_circle, color: Colors.green),
        );
      case 'team_invitation':
        return CircleAvatar(
          backgroundColor: Colors.purple.shade100,
          child: const Icon(Icons.group_add, color: Colors.purple),
        );
      case 'team_joined':
        return CircleAvatar(
          backgroundColor: Colors.orange.shade100,
          child: const Icon(Icons.person_add, color: Colors.orange),
        );
      default:
        return CircleAvatar(
          backgroundColor: Colors.grey.shade200,
          child: const Icon(Icons.notifications, color: Colors.grey),
        );
    }
  }

  void _handleNotificationTap(TeamNotification notification) async {
    if (notification.notificationType == 'task_assigned' || notification.notificationType == 'task_completed') {
      if (notification.taskId != null && notification.teamId != null) {
        try {
          setState(() {
            _isLoading = true;
          });
          
          // Mendapatkan detail tugas dari service
          final teamService = Provider.of<TeamService>(context, listen: false);
          final task = await teamService.getTaskById(notification.taskId!);
          
          setState(() {
            _isLoading = false;
          });
          
          if (task != null && mounted) {
            // Navigasi ke halaman detail tugas
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TeamTaskDetailScreen(
                  taskId: notification.taskId!,
                  teamId: notification.teamId!,
                  isLeader: false, // Akan diupdate di TeamTaskDetailScreen berdasarkan currentUserId
                ),
              ),
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tugas tidak ditemukan atau telah dihapus'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (e) {
          setState(() {
            _isLoading = false;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gagal memuat detail tugas: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Informasi tugas tidak lengkap'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  // Metode showTaskDetailsDialog tidak lagi digunakan karena navigasi langsung ke TeamTaskDetailScreen
}