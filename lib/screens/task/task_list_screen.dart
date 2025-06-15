import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../services/task_service.dart';
import '../../services/auth_services.dart';
import 'task_detail_screen.dart';
import 'create_task_screen.dart';

class TaskListScreen extends StatefulWidget {
  final String userId;
  final bool isPremium;

  const TaskListScreen({
    Key? key,
    required this.userId,
    required this.isPremium,
  }) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  bool _isLoading = true;
  List<TaskModel> _tasks = [];
  String? _error;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('=== MEMUAT TUGAS DI TASK LIST SCREEN ===');
      debugPrint('User ID: ${widget.userId}');
      
      final taskService = Provider.of<TaskService>(context, listen: false);
      final tasks = await taskService.getPersonalTasks(widget.userId);
      
      debugPrint('Jumlah tugas yang diterima: ${tasks.length}');
      if (tasks.isNotEmpty) {
        for (var task in tasks) {
          debugPrint('Task: ${task.title}, ID: ${task.id}, Type: ${task.taskType.name}');
        }
      }
      
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('=== ERROR SAAT MEMUAT TUGAS ===');
      debugPrint('Error: $e');
      
      setState(() {
        _error = 'Gagal memuat tugas: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tugas Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTasks,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : _tasks.isEmpty
                  ? _buildEmptyState()
                  : _buildTaskList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateTaskScreen(userId: widget.userId),
            ),
          );
          
          if (result == true) {
            _loadTasks();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada tugas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan tugas baru dengan menekan tombol + di bawah',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    // Kelompokkan tugas berdasarkan status
    final pendingTasks = _tasks.where((task) => task.status == TaskStatus.pending).toList();
    final inProgressTasks = _tasks.where((task) => task.status == TaskStatus.inProgress).toList();
    final completedTasks = _tasks.where((task) => task.status == TaskStatus.completed).toList();
    final cancelledTasks = _tasks.where((task) => task.status == TaskStatus.cancelled).toList();
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendingTasks.isNotEmpty) ...[
              _buildTaskSection('Menunggu', pendingTasks, Colors.orange),
              const SizedBox(height: 16),
            ],
            if (inProgressTasks.isNotEmpty) ...[
              _buildTaskSection('Dalam Proses', inProgressTasks, Colors.blue),
              const SizedBox(height: 16),
            ],
            if (completedTasks.isNotEmpty) ...[
              _buildTaskSection('Selesai', completedTasks, Colors.green),
              const SizedBox(height: 16),
            ],
            if (cancelledTasks.isNotEmpty) ...[
              _buildTaskSection('Dibatalkan', cancelledTasks, Colors.red),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskSection(String title, List<TaskModel> tasks, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$title (${tasks.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...tasks.map((task) => _buildTaskItem(task)).toList(),
      ],
    );
  }

  Widget _buildTaskItem(TaskModel task) {
    Color statusColor;
    switch (task.status) {
      case TaskStatus.pending:
        statusColor = Colors.orange;
        break;
      case TaskStatus.inProgress:
        statusColor = Colors.blue;
        break;
      case TaskStatus.completed:
        statusColor = Colors.green;
        break;
      case TaskStatus.cancelled:
        statusColor = Colors.red;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
          child: task.status == TaskStatus.completed
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : null,
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: task.status == TaskStatus.completed
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.description.length > 50
                  ? '${task.description.substring(0, 50)}...'
                  : task.description,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 12),
                const SizedBox(width: 4),
                Text(
                  '${task.dueDate.day}/${task.dueDate.month}/${task.dueDate.year}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showTaskOptions(task),
        ),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailScreen(
                task: task,
                isPremium: widget.isPremium,
              ),
            ),
          );
          
          if (result == true) {
            _loadTasks();
          }
        },
      ),
    );
  }

  void _showTaskOptions(TaskModel task) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('Lihat Detail'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskDetailScreen(
                        task: task,
                        isPremium: widget.isPremium,
                      ),
                    ),
                  ).then((result) {
                    if (result == true) {
                      _loadTasks();
                    }
                  });
                },
              ),
              if (task.status != TaskStatus.completed)
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Tandai Selesai'),
                  onTap: () async {
                    Navigator.pop(context);
                    final taskService = Provider.of<TaskService>(context, listen: false);
                    await taskService.updateTaskStatus(task.id, TaskStatus.completed);
                    _loadTasks();
                  },
                ),
              if (task.status != TaskStatus.inProgress && task.status != TaskStatus.completed)
                ListTile(
                  leading: const Icon(Icons.play_circle, color: Colors.blue),
                  title: const Text('Tandai Dalam Proses'),
                  onTap: () async {
                    Navigator.pop(context);
                    final taskService = Provider.of<TaskService>(context, listen: false);
                    await taskService.updateTaskStatus(task.id, TaskStatus.inProgress);
                    _loadTasks();
                  },
                ),
              if (task.status != TaskStatus.cancelled)
                ListTile(
                  leading: const Icon(Icons.cancel, color: Colors.red),
                  title: const Text('Batalkan Tugas'),
                  onTap: () async {
                    Navigator.pop(context);
                    final taskService = Provider.of<TaskService>(context, listen: false);
                    await taskService.updateTaskStatus(task.id, TaskStatus.cancelled);
                    _loadTasks();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Hapus Tugas'),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Konfirmasi'),
                      content: const Text('Apakah Anda yakin ingin menghapus tugas ini?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Hapus'),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirm == true) {
                    final taskService = Provider.of<TaskService>(context, listen: false);
                    await taskService.deleteTask(task.id);
                    _loadTasks();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}