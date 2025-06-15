import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/task_service.dart';
import '../services/team_service.dart';
import '../models/task_model.dart';
import '../models/team_model.dart';
import 'task/task_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  final String userId;
  final bool isPremium;

  const NotificationScreen({
    Key? key,
    required this.userId,
    required this.isPremium,
  }) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<TaskModel> _upcomingTasks = [];
  List<TaskModel> _overdueTasks = [];
  List<TaskModel> _teamTasks = [];
  List<TeamModel> _teams = [];
  bool _isLoading = true;
  bool _loadingTeamTasks = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final taskService = Provider.of<TaskService>(context, listen: false);
      final tasks = await taskService.getPersonalTasks(widget.userId);
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final nextWeek = today.add(const Duration(days: 7));
      
      // Filter tugas yang belum selesai
      final activeTasks = tasks.where((task) => 
        task.status != TaskStatus.completed && 
        task.status != TaskStatus.cancelled
      ).toList();
      
      // Tugas yang mendekati tenggat waktu (dalam 7 hari)
      _upcomingTasks = activeTasks.where((task) {
        final dueDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
        return dueDate.isAfter(today) && dueDate.isBefore(nextWeek) || dueDate.isAtSameMomentAs(tomorrow);
      }).toList();
      
      // Tugas yang sudah lewat tenggat waktu
      _overdueTasks = activeTasks.where((task) {
        final dueDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
        return dueDate.isBefore(today) || dueDate.isAtSameMomentAs(today);
      }).toList();

      // Jika pengguna premium, muat juga tugas tim
      if (widget.isPremium) {
        await _loadTeamTasks();
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat notifikasi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadTeamTasks() async {
    if (!widget.isPremium) return;

    setState(() {
      _loadingTeamTasks = true;
    });

    try {
      // Muat tim pengguna
      final teamService = Provider.of<TeamService>(context, listen: false);
      _teams = await teamService.getUserTeams(widget.userId);

      // Muat tugas yang ditugaskan ke pengguna
      final taskService = Provider.of<TaskService>(context, listen: false);
      _teamTasks = await taskService.getAssignedTasks(widget.userId);

      setState(() {
        _loadingTeamTasks = false;
      });
    } catch (e) {
      setState(() {
        _loadingTeamTasks = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat tugas tim: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: widget.isPremium ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifikasi'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadTasks,
            ),
          ],
          bottom: widget.isPremium
              ? const TabBar(
                  tabs: [
                    Tab(text: 'Pribadi'),
                    Tab(text: 'Tim'),
                  ],
                )
              : null,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : widget.isPremium
                ? TabBarView(
                    children: [
                      _buildPersonalNotificationList(),
                      _buildTeamNotificationList(),
                    ],
                  )
                : _buildPersonalNotificationList(),
      ),
    );
  }

  Widget _buildPersonalNotificationList() {
    if (_overdueTasks.isEmpty && _upcomingTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada notifikasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anda tidak memiliki tugas yang mendekati tenggat waktu',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_overdueTasks.isNotEmpty) ...[
          const _NotificationHeader(
            title: 'Tugas Terlambat',
            icon: Icons.warning,
            color: Colors.red,
          ),
          const SizedBox(height: 8),
          ..._overdueTasks.map((task) => _NotificationItem(
            task: task,
            isOverdue: true,
            onTap: () => _openTaskDetail(task.id),
          )),
          const SizedBox(height: 24),
        ],
        if (_upcomingTasks.isNotEmpty) ...[
          const _NotificationHeader(
            title: 'Tugas Mendatang',
            icon: Icons.schedule,
            color: Colors.orange,
          ),
          const SizedBox(height: 8),
          ..._upcomingTasks.map((task) => _NotificationItem(
            task: task,
            isOverdue: false,
            onTap: () => _openTaskDetail(task.id),
          )),
        ],
        if (!widget.isPremium) ...[
          const SizedBox(height: 32),
          _buildPremiumPrompt(),
        ],
      ],
    );
  }

  Widget _buildTeamNotificationList() {
    if (_loadingTeamTasks) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_teamTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada tugas tim',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anda tidak memiliki tugas tim yang ditugaskan',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // Filter tugas tim berdasarkan status
    final pendingTeamTasks = _teamTasks.where((task) => task.status == TaskStatus.pending).toList();
    final inProgressTeamTasks = _teamTasks.where((task) => task.status == TaskStatus.inProgress).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _NotificationHeader(
          title: 'Tugas Tim',
          icon: Icons.group,
          color: Colors.green,
        ),
        const SizedBox(height: 16),
        if (pendingTeamTasks.isNotEmpty) ...[
          Text(
            'Menunggu (${pendingTeamTasks.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          ...pendingTeamTasks.map((task) => _TeamTaskItem(
            task: task,
            onTap: () => _openTaskDetail(task.id),
          )),
          const SizedBox(height: 16),
        ],
        if (inProgressTeamTasks.isNotEmpty) ...[
          Text(
            'Dalam Proses (${inProgressTeamTasks.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          ...inProgressTeamTasks.map((task) => _TeamTaskItem(
            task: task,
            onTap: () => _openTaskDetail(task.id),
          )),
        ],
      ],
    );
  }

  Widget _buildPremiumPrompt() {
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Upgrade ke Premium',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Dapatkan notifikasi lanjutan seperti:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const _BulletPoint(text: 'Pengingat untuk tugas tim'),
            const _BulletPoint(text: 'Notifikasi saat tugas didelegasikan'),
            const _BulletPoint(text: 'Notifikasi perubahan status tugas tim'),
            const _BulletPoint(text: 'Laporan mingguan & bulanan'),
            const SizedBox(height: 8),
            const Text(
              'Fitur notifikasi dasar tersedia di Free Plan.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTaskDetail(String taskId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(
          taskId: taskId,
          isPremium: widget.isPremium,
        ),
      ),
    );
    
    if (result == true) {
      _loadTasks();
    }
  }
}

class _NotificationHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _NotificationHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final TaskModel task;
  final bool isOverdue;
  final VoidCallback onTap;

  const _NotificationItem({
    required this.task,
    required this.isOverdue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = task.dueDate.difference(DateTime.now()).inDays;
    final String timeText;
    
    if (isOverdue) {
      final daysOverdue = -daysLeft;
      timeText = daysOverdue == 0
          ? 'Jatuh tempo hari ini'
          : 'Terlambat $daysOverdue hari';
    } else {
      timeText = daysLeft == 0
          ? 'Jatuh tempo besok'
          : 'Jatuh tempo dalam $daysLeft hari';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isOverdue ? Colors.red : Colors.orange,
          child: Icon(
            isOverdue ? Icons.warning : Icons.notifications_active,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          task.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              timeText,
              style: TextStyle(
                color: isOverdue ? Colors.red : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _getStatusIcon(task.status),
                  size: 12,
                  color: _getStatusColor(task.status),
                ),
                const SizedBox(width: 4),
                Text(
                  task.status.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getStatusColor(task.status),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Icons.hourglass_empty;
      case TaskStatus.inProgress:
        return Icons.play_circle;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Colors.orange;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.cancelled:
        return Colors.red;
    }
  }
}

class _TeamTaskItem extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;

  const _TeamTaskItem({
    required this.task,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(task.status).withOpacity(0.2),
          child: Icon(
            _getStatusIcon(task.status),
            color: _getStatusColor(task.status),
            size: 20,
          ),
        ),
        title: Text(
          task.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              task.description.length > 50
                  ? '${task.description.substring(0, 50)}...'
                  : task.description,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(task.dueDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Icons.hourglass_empty;
      case TaskStatus.inProgress:
        return Icons.play_circle;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Colors.orange;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.cancelled:
        return Colors.red;
    }
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;

  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}